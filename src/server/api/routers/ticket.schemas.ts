import { z } from "zod";

export const ticketPrioritySchema = z.enum(["LOW", "MEDIUM", "HIGH", "URGENT"]);

export const ticketStatusSchema = z.enum([
	"OPEN",
	"IN_PROGRESS",
	"RESOLVED",
	"CLOSED",
]);

export const createTicketInputSchema = z.object({
	title: z
		.string()
		.trim()
		.min(3, "Title must contain at least 3 characters")
		.max(100, "Title cannot exceed 100 characters"),
	description: z
		.string()
		.trim()
		.min(10, "Description must contain at least 10 characters")
		.max(2000, "Description cannot exceed 2000 characters"),
	priority: ticketPrioritySchema.default("MEDIUM"),
});

export const ticketIdInputSchema = z.object({
	id: z.string().min(1, "Ticket ID is required"),
});

export const updateTicketStatusInputSchema = ticketIdInputSchema.extend({
	status: ticketStatusSchema,
});
