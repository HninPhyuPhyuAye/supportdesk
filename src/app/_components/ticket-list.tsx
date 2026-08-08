"use client";

import { useState } from "react";

import { api } from "@/trpc/react";

type TicketPriority = "LOW" | "MEDIUM" | "HIGH" | "URGENT";

export function TicketList() {
	const [tickets] = api.ticket.getAll.useSuspenseQuery();
	const utils = api.useUtils();

	const [title, setTitle] = useState("");
	const [description, setDescription] = useState("");
	const [priority, setPriority] = useState<TicketPriority>("MEDIUM");

	const createTicket = api.ticket.create.useMutation({
		onSuccess: async () => {
			await utils.ticket.getAll.invalidate();
			setTitle("");
			setDescription("");
			setPriority("MEDIUM");
		},
	});

	return (
		<section className="grid w-full max-w-5xl gap-8 lg:grid-cols-[2fr_3fr]">
			<div className="rounded-2xl bg-white p-6 text-slate-900 shadow-xl">
				<h2 className="font-bold text-2xl">Create a support ticket</h2>
				<p className="mt-1 text-slate-600">
					Describe the technical issue you need help with.
				</p>

				<form
					className="mt-6 flex flex-col gap-4"
					onSubmit={(event) => {
						event.preventDefault();
						createTicket.mutate({
							title,
							description,
							priority,
						});
					}}
				>
					<label className="flex flex-col gap-1 font-medium">
						Title
						<input
							className="rounded-lg border border-slate-300 px-3 py-2"
							maxLength={100}
							minLength={3}
							onChange={(event) => setTitle(event.target.value)}
							placeholder="Example: Cannot access company email"
							required
							type="text"
							value={title}
						/>
					</label>

					<label className="flex flex-col gap-1 font-medium">
						Description
						<textarea
							className="min-h-32 rounded-lg border border-slate-300 px-3 py-2"
							maxLength={2000}
							minLength={10}
							onChange={(event) => setDescription(event.target.value)}
							placeholder="Explain what happened and any troubleshooting you tried."
							required
							value={description}
						/>
					</label>

					<label className="flex flex-col gap-1 font-medium">
						Priority
						<select
							className="rounded-lg border border-slate-300 px-3 py-2"
							onChange={(event) =>
								setPriority(event.target.value as TicketPriority)
							}
							value={priority}
						>
							<option value="LOW">Low</option>
							<option value="MEDIUM">Medium</option>
							<option value="HIGH">High</option>
							<option value="URGENT">Urgent</option>
						</select>
					</label>

					{createTicket.error && (
						<p className="rounded-lg bg-red-50 p-3 text-red-700">
							{createTicket.error.message}
						</p>
					)}

					<button
						className="rounded-lg bg-blue-700 px-4 py-2 font-semibold text-white transition hover:bg-blue-800 disabled:cursor-not-allowed disabled:opacity-60"
						disabled={createTicket.isPending}
						type="submit"
					>
						{createTicket.isPending ? "Creating ticket..." : "Create ticket"}
					</button>
				</form>
			</div>

			<div className="rounded-2xl bg-white p-6 text-slate-900 shadow-xl">
				<h2 className="font-bold text-2xl">My tickets</h2>
				<p className="mt-1 text-slate-600">
					You have {tickets.length} support ticket
					{tickets.length === 1 ? "" : "s"}.
				</p>

				{tickets.length === 0 ? (
					<p className="mt-6 rounded-lg bg-slate-100 p-6 text-center text-slate-600">
						You have not created any tickets yet.
					</p>
				) : (
					<ul className="mt-6 flex flex-col gap-4">
						{tickets.map((ticket) => (
							<li
								className="rounded-xl border border-slate-200 p-4"
								key={ticket.id}
							>
								<div className="flex flex-wrap items-start justify-between gap-2">
									<h3 className="font-semibold text-lg">{ticket.title}</h3>
									<div className="flex gap-2 text-xs">
										<span className="rounded-full bg-blue-100 px-2 py-1 font-semibold text-blue-800">
											{ticket.status.replace("_", " ")}
										</span>
										<span className="rounded-full bg-amber-100 px-2 py-1 font-semibold text-amber-800">
											{ticket.priority}
										</span>
									</div>
								</div>

								<p className="mt-2 whitespace-pre-wrap text-slate-700">
									{ticket.description}
								</p>
								<p className="mt-3 text-slate-500 text-sm">
									Created {ticket.createdAt.toLocaleString()}
								</p>
							</li>
						))}
					</ul>
				)}
			</div>
		</section>
	);
}
