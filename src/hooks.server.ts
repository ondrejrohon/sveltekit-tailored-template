import type { Handle } from '@sveltejs/kit';
import { jwtVerify, errors } from 'jose';
import { JWT_SECRET } from '$env/static/private';
import { db } from '$lib/server/db';
import * as tables from '$lib/server/db/schema';
import { eq } from 'drizzle-orm';
import { sessionCookieName } from '$lib/server/constants';
import {
	deleteSessionTokenCookie,
	setSessionTokenCookie,
	validateSessionToken
} from '$lib/server/auth/session';

const secret = new TextEncoder().encode(JWT_SECRET);

const handleAuth: Handle = async ({ event, resolve }) => {
	const authHeader = event.request.headers.get('authorization');

	if (authHeader?.startsWith('Bearer ')) {
		// Token auth for mobile
		const token = authHeader.split(' ')[1];
		try {
			const { payload } = await jwtVerify(token, secret);
			event.locals.user = await db
				.select()
				.from(tables.user)
				.where(eq(tables.user.id, payload.userId as string));
		} catch (error) {
			// Token invalid/expired
			event.locals.user = null;

			const errorMessage = error instanceof errors.JWTExpired ? 'token_expired' : 'token_invalid';

			return new Response(JSON.stringify({ message: errorMessage }), {
				status: 401,
				headers: {
					'Content-Type': 'application/json'
				}
			});
		}
	} else {
		// cookies auth for web
		const sessionToken = event.cookies.get(sessionCookieName);
		if (!sessionToken) {
			event.locals.user = null;
			event.locals.session = null;
			return resolve(event);
		}

		const { session, user } = await validateSessionToken(sessionToken);
		if (session) {
			setSessionTokenCookie(event, sessionToken, session.expiresAt);
		} else {
			deleteSessionTokenCookie(event);
		}

		event.locals.user = user;
		event.locals.session = session;
	}

	return resolve(event);
};

export const handle: Handle = handleAuth;
