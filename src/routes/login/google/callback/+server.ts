import {
	generateSessionToken,
	createSession,
	setSessionTokenCookie
} from '$lib/server/auth/session';
import { google } from '$lib/server/oauth';
import { decodeIdToken } from 'arctic';

import type { RequestEvent } from '@sveltejs/kit';
import type { OAuth2Tokens } from 'arctic';
import { db } from '$lib/server/db';
import { user as userTable } from '$lib/server/db/schema';
import { eq } from 'drizzle-orm';

interface GoogleIdTokenClaims {
	sub: string;
	name: string;
	email: string;
}

export async function GET(event: RequestEvent): Promise<Response> {
	const code = event.url.searchParams.get('code');
	const state = event.url.searchParams.get('state');
	const storedState = event.cookies.get('google_oauth_state') ?? null;
	const codeVerifier = event.cookies.get('google_code_verifier') ?? null;
	if (code === null || state === null || storedState === null || codeVerifier === null) {
		return new Response(null, {
			status: 400
		});
	}
	if (state !== storedState) {
		return new Response(null, {
			status: 400
		});
	}

	let tokens: OAuth2Tokens;
	try {
		tokens = await google.validateAuthorizationCode(code, codeVerifier);
	} catch (error) {
		console.error(error);
		// Invalid code or client credentials
		return new Response(null, {
			status: 400
		});
	}
	const claims = decodeIdToken(tokens.idToken()) as GoogleIdTokenClaims;
	const googleUserId = claims.sub;
	const email = claims.email;

	if (!googleUserId) {
		console.error('Google user ID is missing');
		return new Response(null, {
			status: 400
		});
	}

	if (!email) {
		console.error('Email is missing');
		return new Response(null, {
			status: 400
		});
	}

	// get user from db by googleId
	const [existingUser] = await db
		.select()
		.from(userTable)
		.where(eq(userTable.googleId, googleUserId));

	if (existingUser?.id) {
		const sessionToken = generateSessionToken();
		const session = await createSession(sessionToken, existingUser.id);
		setSessionTokenCookie(event, sessionToken, session.expiresAt);
		return new Response(null, {
			status: 302,
			headers: {
				Location: '/'
			}
		});
	}

	// check if user exists by email
	const [existingEmailUser] = await db.select().from(userTable).where(eq(userTable.email, email));

	if (existingEmailUser?.id) {
		// update user with googleId
		await db
			.update(userTable)
			.set({ googleId: googleUserId })
			.where(eq(userTable.id, existingEmailUser.id));

		const sessionToken = generateSessionToken();
		const session = await createSession(sessionToken, existingEmailUser.id);
		setSessionTokenCookie(event, sessionToken, session.expiresAt);
		return new Response(null, {
			status: 302,
			headers: {
				Location: '/'
			}
		});
	}

	const [user] = await db
		.insert(userTable)
		.values({
			id: crypto.randomUUID(),
			googleId: googleUserId,
			email,
			passwordHash: ''
		})
		.returning();

	const sessionToken = generateSessionToken();
	const session = await createSession(sessionToken, user.id);
	setSessionTokenCookie(event, sessionToken, session.expiresAt);
	return new Response(null, {
		status: 302,
		headers: {
			Location: '/'
		}
	});
}
