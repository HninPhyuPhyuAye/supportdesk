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

		expect(actions).not.toContain("iam:CreateRole");
		expect(actions).not.toContain("iam:CreateServiceLinkedRole");
		expect(actions).not.toContain("secretsmanager:GetSecretValue");
		expect(actions).not.toContain("secretsmanager:PutSecretValue");
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
	});
});
