import { describe, expect, it } from "vitest";

import {
	createTicketInputSchema,
	ticketStatusSchema,
	updateTicketStatusInputSchema,
} from "./ticket.schemas";

describe("createTicketInputSchema", () => {
	it("accepts valid input, trims text, and applies the default priority", () => {
		const result = createTicketInputSchema.parse({
			title: "  Printer offline  ",
			description: "  The printer cannot connect to the office network.  ",
		});

		expect(result).toEqual({
			title: "Printer offline",
			description: "The printer cannot connect to the office network.",
			priority: "MEDIUM",
		});
	});

	it("rejects a title shorter than three characters", () => {
		const result = createTicketInputSchema.safeParse({
			title: "IT",
			description: "The laptop cannot connect to the office network.",
			priority: "HIGH",
		});

		expect(result.success).toBe(false);
	});

	it("rejects a description shorter than ten characters", () => {
		const result = createTicketInputSchema.safeParse({
			title: "Email problem",
			description: "No email",
			priority: "HIGH",
		});

		expect(result.success).toBe(false);
	});

	it("rejects an unsupported priority", () => {
		const result = createTicketInputSchema.safeParse({
			title: "Email problem",
			description: "The mailbox cannot receive new messages.",
			priority: "CRITICAL",
		});

		expect(result.success).toBe(false);
	});
});

describe("ticketStatusSchema", () => {
	it.each(["OPEN", "IN_PROGRESS", "RESOLVED", "CLOSED"])(
		"accepts the %s status",
		(status) => {
			expect(ticketStatusSchema.parse(status)).toBe(status);
		},
	);

	it("rejects an unsupported status", () => {
		expect(ticketStatusSchema.safeParse("PENDING").success).toBe(false);
	});
});

describe("updateTicketStatusInputSchema", () => {
	it("requires a ticket ID", () => {
		const result = updateTicketStatusInputSchema.safeParse({
			id: "",
			status: "RESOLVED",
		});

		expect(result.success).toBe(false);
	});
});
