import { TRPCError } from "@trpc/server";

import { createTRPCRouter, protectedProcedure } from "@/server/api/trpc";
import {
	createTicketInputSchema,
	ticketIdInputSchema,
	updateTicketStatusInputSchema,
} from "./ticket.schemas";

export const ticketRouter = createTRPCRouter({
	create: protectedProcedure
		.input(createTicketInputSchema)
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
		.input(ticketIdInputSchema)
		.query(async ({ ctx, input }) => {
			return ctx.db.ticket.findFirst({
				where: {
					id: input.id,
					createdById: ctx.session.user.id,
				},
			});
		}),

	updateStatus: protectedProcedure
		.input(updateTicketStatusInputSchema)
		.mutation(async ({ ctx, input }) => {
			const result = await ctx.db.ticket.updateMany({
				where: {
					id: input.id,
					createdById: ctx.session.user.id,
				},
				data: {
					status: input.status,
				},
			});

			if (result.count === 0) {
				throw new TRPCError({
					code: "NOT_FOUND",
					message: "Ticket not found",
				});
			}

			return {
				id: input.id,
				status: input.status,
			};
		}),
});
