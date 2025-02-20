import type { RequestHandler } from './$types';

export const GET: RequestHandler = async ({ locals }) => {
	// TODO: remove later
	if (!locals.user) {
		return new Response('unauthorized', { status: 401 });
	}

	return new Response(JSON.stringify({ status: 'ok', timestamp: new Date().toISOString() }));
};
