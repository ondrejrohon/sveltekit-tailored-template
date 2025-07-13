import { redirect } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { deleteSessionTokenCookie, invalidateSession } from '$lib/server/lucia-auth/session';

export const GET: RequestHandler = async (event) => {
	if (!event.locals.session) {
		return redirect(302, '/');
	}
	await invalidateSession(event.locals.session.id);
	deleteSessionTokenCookie(event);

	return redirect(302, '/');
};
