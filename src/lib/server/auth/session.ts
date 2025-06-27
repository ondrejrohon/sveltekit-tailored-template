import { encodeBase32LowerCaseNoPadding, encodeHexLowerCase } from '@oslojs/encoding';
import { sha256 } from '@oslojs/crypto/sha2';

import type { User } from './user';
import type { RequestEvent } from '@sveltejs/kit';
import { db } from '$lib/server/db';
import * as tables from '$lib/server/db/schema';
import { eq } from 'drizzle-orm';

export async function validateSessionToken(token: string): Promise<SessionValidationResult> {
	const sessionId = encodeHexLowerCase(sha256(new TextEncoder().encode(token)));
	const [row] = await db
		.select()
		.from(tables.session)
		.innerJoin(tables.user, eq(tables.session.userId, tables.user.id))
		.where(eq(tables.session.id, sessionId));

	if (!row) {
		return { session: null, user: null };
	}
	const { session, user } = row;

	if (Date.now() >= session.expiresAt.getTime()) {
		await db.delete(tables.session).where(eq(tables.session.id, session.id));
		return { session: null, user: null };
	}
	if (Date.now() >= session.expiresAt.getTime() - 1000 * 60 * 60 * 24 * 15) {
		session.expiresAt = new Date(Date.now() + 1000 * 60 * 60 * 24 * 30);
		await db
			.update(tables.session)
			.set({ expiresAt: session.expiresAt })
			.where(eq(tables.session.id, session.id));
	}
	return { session, user };
}

export async function invalidateSession(sessionId: string): Promise<void> {
	await db.delete(tables.session).where(eq(tables.session.id, sessionId));
}

export async function invalidateUserSessions(userId: string): Promise<void> {
	await db.delete(tables.session).where(eq(tables.session.userId, userId));
}

export function setSessionTokenCookie(event: RequestEvent, token: string, expiresAt: Date): void {
	event.cookies.set('session', token, {
		httpOnly: true,
		path: '/',
		secure: import.meta.env.PROD,
		sameSite: 'lax',
		expires: expiresAt
	});
}

export function deleteSessionTokenCookie(event: RequestEvent): void {
	event.cookies.set('session', '', {
		httpOnly: true,
		path: '/',
		secure: import.meta.env.PROD,
		sameSite: 'lax',
		maxAge: 0
	});
}

export function generateSessionToken(): string {
	const tokenBytes = new Uint8Array(20);
	crypto.getRandomValues(tokenBytes);
	const token = encodeBase32LowerCaseNoPadding(tokenBytes).toLowerCase();
	return token;
}

// export function createSession(token: string, userId: number, flags: SessionFlags): Session {
export async function createSession(token: string, userId: string): Promise<Session> {
	const sessionId = encodeHexLowerCase(sha256(new TextEncoder().encode(token)));
	const session: Session = {
		id: sessionId,
		userId,
		expiresAt: new Date(Date.now() + 1000 * 60 * 60 * 24 * 30)
		// twoFactorVerified: flags.twoFactorVerified
	};
	await db.insert(tables.session).values(session);
	return session;
}

// export function setSessionAs2FAVerified(sessionId: string): void {
// 	db.execute('UPDATE session SET two_factor_verified = 1 WHERE id = ?', [sessionId]);
// }

// export interface SessionFlags {
// 	twoFactorVerified: boolean;
// }

// export interface Session extends SessionFlags {
export interface Session {
	id: string;
	expiresAt: Date;
	userId: string;
}

type SessionValidationResult = { session: Session; user: User } | { session: null; user: null };
