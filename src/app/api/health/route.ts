export function GET() {
	return Response.json(
		{
			service: "supportdesk",
			status: "ok",
		},
		{
			headers: {
				"Cache-Control": "no-store",
			},
			status: 200,
		},
	);
}
