import { z } from "zod";

import { createTRPCRouter, protectedProcedure } from "@/server/api/trpc";

const ticketPrioritySchema = z.enum(["LOW", "MEDIUM", "HIGH", "URGENT"]);

export const ticketRouter = createTRPCRouter({
	create: protectedProcedure
		.input(
			z.object({
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
			}),
		)
		.mutation(async ({ ctx, input }) => {
			return ctx.db.ticket.create({
				data: {
					title: input.title,
					description: input.description,
					priority: input.priority,
					createdById: ctx.session.user.id,
				},
			});
		}),

	getAll: protectedProcedure.query(async ({ ctx }) => {
		return ctx.db.ticket.findMany({
			where: {
				createdById: ctx.session.user.id,
			},
			orderBy: {
				createdAt: "desc",
			},
		});
	}),

	getById: protectedProcedure
		.input(z.object({ id: z.string().min(1) }))
		.query(async ({ ctx, input }) => {
			return ctx.db.ticket.findFirst({
				where: {
					id: input.id,
					createdById: ctx.session.user.id,
				},
			});
		}),
});
