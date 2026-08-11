import { readFileSync } from "node:fs";

import { describe, expect, it } from "vitest";

type PolicyStatement = {
	Action: string | string[];
	Condition?: Record<string, Record<string, string>>;
	Effect: "Allow" | "Deny";
	Principal?: Record<string, string>;
	Resource?: string | string[];
	Sid: string;
};

type PolicyDocument = {
	Statement: PolicyStatement[];
	Version: string;
};

const loadPolicy = (filename: string) =>
	JSON.parse(
		readFileSync(new URL(filename, import.meta.url), "utf8"),
	) as PolicyDocument;

const actionsFor = (policy: PolicyDocument) =>
	policy.Statement.flatMap((statement) =>
		Array.isArray(statement.Action) ? statement.Action : [statement.Action],
	);

describe("ECS IAM policy guardrails", () => {
	it("trusts only the ECS tasks service", () => {
		const trustPolicy = loadPolicy("supportdesk-ecs-tasks-trust-policy.json");

		expect(trustPolicy.Statement).toHaveLength(1);
		expect(trustPolicy.Statement[0]?.Principal).toEqual({
			Service: "ecs-tasks.amazonaws.com",
		});
		expect(trustPolicy.Statement[0]?.Action).toBe("sts:AssumeRole");
	});

	it("keeps execution permissions scoped to image pulls, logs, and secret reads", () => {
		const executionPolicy = loadPolicy("supportdesk-ecs-execution-policy.json");
		const actions = actionsFor(executionPolicy);

		expect(actions).toContain("secretsmanager:GetSecretValue");
		expect(actions).not.toContain("secretsmanager:PutSecretValue");
		expect(actions).not.toContain("ecr:PutImage");
		expect(
			executionPolicy.Statement.filter(
				(statement) => statement.Resource === "*",
			),
		).toEqual([
			expect.objectContaining({ Action: "ecr:GetAuthorizationToken" }),
		]);
	});

	it("keeps the Terraform runtime plan policy read-only", () => {
		const planPolicy = loadPolicy("supportdesk-runtime-plan-policy.json");
		const actions = actionsFor(planPolicy);
		const describeTaskDefinition = planPolicy.Statement.find(
			(statement) => statement.Action === "ecs:DescribeTaskDefinition",
		);

		expect(actions).not.toContain("secretsmanager:GetSecretValue");
		expect(actions).toContain("secretsmanager:GetResourcePolicy");
		expect(
			actions.every((action) =>
				/:(Describe|List|Get)(?!SecretValue)/.test(action),
			),
		).toBe(true);
		expect(describeTaskDefinition?.Resource).toBe("*");
	});

	it("prevents the runtime deployer from administering IAM or secret values", () => {
		const applyPolicy = loadPolicy("supportdesk-runtime-apply-policy.json");
		const actions = actionsFor(applyPolicy);
		const passRoleStatement = applyPolicy.Statement.find(
			(statement) => statement.Sid === "PassOnlySupportDeskTaskRolesToEcs",
		);
		const deregisterTaskDefinition = applyPolicy.Statement.find(
			(statement) => statement.Action === "ecs:DeregisterTaskDefinition",
		);
		const manageService = applyPolicy.Statement.find(
			(statement) => statement.Sid === "ManageNamedSupportDeskEcsService",
		);
		const manageAlarms = applyPolicy.Statement.find(
			(statement) => statement.Sid === "ManageOnlyExistingSupportDeskAlarms",
		);

		expect(actions).not.toContain("iam:CreateRole");
		expect(actions).not.toContain("iam:CreateServiceLinkedRole");
		expect(actions).not.toContain("secretsmanager:GetSecretValue");
		expect(actions).not.toContain("secretsmanager:PutSecretValue");
		expect(actions).not.toContain("cloudwatch:PutMetricData");
		expect(passRoleStatement?.Resource).toEqual([
			"arn:aws:iam::*:role/supportdesk-ecs-execution",
			"arn:aws:iam::*:role/supportdesk-ecs-task",
		]);
		expect(passRoleStatement?.Condition).toEqual({
			StringEquals: {
				"iam:PassedToService": "ecs-tasks.amazonaws.com",
			},
		});
		expect(deregisterTaskDefinition?.Resource).toBe("*");
		expect(deregisterTaskDefinition?.Condition).toEqual({
			StringEquals: {
				"aws:RequestedRegion": "ap-southeast-1",
			},
		});
		expect(manageService?.Condition).toEqual({
			ArnLikeIfExists: {
				"ecs:cluster": "arn:aws:ecs:ap-southeast-1:*:cluster/supportdesk-demo",
			},
			StringEquals: {
				"aws:RequestedRegion": "ap-southeast-1",
			},
		});
		expect(manageAlarms?.Resource).toBe(
			"arn:aws:cloudwatch:ap-southeast-1:*:alarm:supportdesk-demo-*",
		);
	});

	it("limits temporary monitoring bootstrap access to alarm creation", () => {
		const policy = loadPolicy("supportdesk-monitoring-create-policy.json");
		const actions = actionsFor(policy);

		expect(actions).toEqual([
			"cloudwatch:PutMetricAlarm",
			"cloudwatch:TagResource",
		]);
		expect(actions).not.toContain("cloudwatch:DeleteAlarms");
		expect(actions).not.toContain("cloudwatch:PutMetricData");
		expect(policy.Statement[0]?.Resource).toBe("*");
		expect(policy.Statement[0]?.Condition).toEqual({
			StringEquals: {
				"aws:RequestedRegion": "ap-southeast-1",
			},
		});
	});

	it("limits temporary migration access to one task family and read-only secrets", () => {
		const secretPolicy = loadPolicy("supportdesk-migration-secret-policy.json");
		const runPolicy = loadPolicy("supportdesk-migration-run-policy.json");
		const secretActions = actionsFor(secretPolicy);
		const runActions = actionsFor(runPolicy);
		const runTask = runPolicy.Statement.find(
			(statement) => statement.Action === "ecs:RunTask",
		);

		expect(secretActions).toEqual(["secretsmanager:GetSecretValue"]);
		expect(secretActions).not.toContain("secretsmanager:PutSecretValue");
		expect(runActions).toContain("ecs:RunTask");
		expect(runActions).not.toContain("ecs:CreateService");
		expect(runTask?.Resource).toBe(
			"arn:aws:ecs:ap-southeast-1:*:task-definition/supportdesk-demo-migration:*",
		);
		expect(runTask?.Condition).toMatchObject({
			BoolIfExists: {
				"ecs:enable-execute-command": "false",
			},
			NumericEqualsIfExists: {
				"ecs:task-cpu": "256",
				"ecs:task-memory": "512",
			},
		});
	});
});
