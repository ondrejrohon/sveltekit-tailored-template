import { fail, redirect } from '@sveltejs/kit';
import type { Actions } from './$types';
import { deleteSessionTokenCookie, invalidateSession } from '$lib/server/lucia-auth/session';

export const actions: Actions = {
	logout: async (event) => {
		if (!event.locals.session) {
			return fail(401);
		}
		await invalidateSession(event.locals.session.id);
		deleteSessionTokenCookie(event);

		return redirect(302, '/');
	}
};
