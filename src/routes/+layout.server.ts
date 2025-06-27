import { redirect } from '@sveltejs/kit';
import type { LayoutServerLoad } from './$types';

export const load: LayoutServerLoad = async (event) => {
	if (!event.locals.user) {
		return {};
	}

	if (!event.locals.user.emailVerified && event.url.pathname !== '/verify-email') {
		return redirect(302, '/verify-email');
	}

	return { user: event.locals.user };
};
