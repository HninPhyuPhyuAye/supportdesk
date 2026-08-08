import { headers } from "next/headers";
import { redirect } from "next/navigation";

import { TicketList } from "@/app/_components/ticket-list";
import { auth } from "@/server/better-auth";
import { getSession } from "@/server/better-auth/server";
import { api, HydrateClient } from "@/trpc/server";

export default async function Home() {
	const session = await getSession();

	if (session) {
		void api.ticket.getAll.prefetch();
	}

	return (
		<HydrateClient>
			<main className="min-h-screen bg-slate-100 text-slate-900">
				<header className="border-slate-200 border-b bg-white">
					<div className="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
						<div>
							<h1 className="font-bold text-2xl text-blue-800">SupportDesk</h1>
							<p className="text-slate-600 text-sm">
								Simple IT support ticket management
							</p>
						</div>

						{session && (
							<form>
								<button
									className="rounded-lg border border-slate-300 px-4 py-2 font-semibold text-slate-700 transition hover:bg-slate-100"
									formAction={async () => {
										"use server";
										await auth.api.signOut({
											headers: await headers(),
										});
										redirect("/");
									}}
									type="submit"
								>
									Sign out
								</button>
							</form>
						)}
					</div>
				</header>

				{session ? (
					<div className="mx-auto max-w-6xl px-6 py-10">
						<div className="mb-8">
							<h2 className="font-bold text-3xl">
								Welcome, {session.user.name}
							</h2>
							<p className="mt-1 text-slate-600">
								Create a new support request or review your existing tickets.
							</p>
						</div>

						<TicketList />
					</div>
				) : (
					<section className="mx-auto flex max-w-3xl flex-col items-center px-6 py-24 text-center">
						<p className="font-semibold text-blue-700 uppercase tracking-wide">
							IT support made simple
						</p>
						<h2 className="mt-4 font-bold text-5xl tracking-tight">
							Report and track technical issues in one place
						</h2>
						<p className="mt-6 max-w-2xl text-lg text-slate-600">
							SupportDesk helps users create, prioritize, and monitor their IT
							support requests.
						</p>

						<form className="mt-10">
							<button
								className="rounded-lg bg-blue-700 px-6 py-3 font-semibold text-white transition hover:bg-blue-800"
								formAction={async () => {
									"use server";
									const response = await auth.api.signInSocial({
										body: {
											provider: "github",
											callbackURL: "/",
										},
									});

									if (!response.url) {
										throw new Error("GitHub sign-in URL was not returned");
									}

									redirect(response.url);
								}}
								type="submit"
							>
								Sign in with GitHub
							</button>
						</form>
					</section>
				)}
			</main>
		</HydrateClient>
	);
}
