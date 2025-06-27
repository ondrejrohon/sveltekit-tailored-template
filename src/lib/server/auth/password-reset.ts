import { encodeHexLowerCase } from '@oslojs/encoding';
import { generateRandomOTP } from './utils';
import { sha256 } from '@oslojs/crypto/sha2';

import type { RequestEvent } from '@sveltejs/kit';
import type { User } from './user';
import * as tables from '../db/schema';
import { db } from '$lib/server/db';
import { eq } from 'drizzle-orm';

export async function createPasswordResetSession(
	token: string,
	userId: string,
	email: string
): Promise<PasswordResetSession> {
	const sessionId = encodeHexLowerCase(sha256(new TextEncoder().encode(token)));
	const session: PasswordResetSession = {
		id: sessionId,
		userId,
		email,
		expiresAt: new Date(Date.now() + 1000 * 60 * 10),
		code: generateRandomOTP(),
		emailVerified: false
		// twoFactorVerified: false
	};
	await db.insert(tables.passwordResetSession).values(session);
	return session;
}

export async function validatePasswordResetSessionToken(
	token: string
): Promise<PasswordResetSessionValidationResult> {
	const sessionId = encodeHexLowerCase(sha256(new TextEncoder().encode(token)));
	// 	const row = db.queryOne(
	// 		`SELECT password_reset_session.id, password_reset_session.user_id, password_reset_session.email, password_reset_session.code, password_reset_session.expires_at, password_reset_session.email_verified, password_reset_session.two_factor_verified,
	// user.id, user.email, user.username, user.email_verified, IIF(user.totp_key IS NOT NULL, 1, 0)
	// FROM password_reset_session INNER JOIN user ON user.id = password_reset_session.user_id
	// WHERE password_reset_session.id = ?`,
	// 		[sessionId]
	// 	);
	const [row] = await db
		.select()
		.from(tables.passwordResetSession)
		.innerJoin(tables.user, eq(tables.passwordResetSession.userId, tables.user.id))
		.where(eq(tables.passwordResetSession.id, sessionId));

	if (!row) {
		return { session: null, user: null };
	}

	const session: PasswordResetSession = {
		...row.password_reset_session,
		emailVerified: row.user.emailVerified
	};

	if (Date.now() >= session.expiresAt.getTime()) {
		await db
			.delete(tables.passwordResetSession)
			.where(eq(tables.passwordResetSession.id, session.id));
		return { session: null, user: null };
	}
	return { session, user: row.user };
}

export async function setPasswordResetSessionAsEmailVerified(sessionId: string): Promise<void> {
	await db
		.update(tables.passwordResetSession)
		.set({ emailVerified: true })
		.where(eq(tables.passwordResetSession.id, sessionId));
}

// export function setPasswordResetSessionAs2FAVerified(sessionId: string): void {
// 	db.execute('UPDATE password_reset_session SET two_factor_verified = 1 WHERE id = ?', [sessionId]);
// }

export async function invalidateUserPasswordResetSessions(userId: string): Promise<void> {
	await db
		.delete(tables.passwordResetSession)
		.where(eq(tables.passwordResetSession.userId, userId));
}

export async function validatePasswordResetSessionRequest(
	event: RequestEvent
): Promise<PasswordResetSessionValidationResult> {
	const token = event.cookies.get('password_reset_session') ?? null;
	if (!token) {
		return { session: null, user: null };
	}
	const result = await validatePasswordResetSessionToken(token);
	if (!result.session) {
		deletePasswordResetSessionTokenCookie(event);
	}
	return result;
}

export function setPasswordResetSessionTokenCookie(
	event: RequestEvent,
	token: string,
	expiresAt: Date
): void {
	event.cookies.set('password_reset_session', token, {
		expires: expiresAt,
		sameSite: 'lax',
		httpOnly: true,
		path: '/',
		secure: !import.meta.env.DEV
	});
}

export function deletePasswordResetSessionTokenCookie(event: RequestEvent): void {
	event.cookies.set('password_reset_session', '', {
		maxAge: 0,
		sameSite: 'lax',
		httpOnly: true,
		path: '/',
		secure: !import.meta.env.DEV
	});
}

export function sendPasswordResetEmail(email: string, code: string): void {
	console.log(`To ${email}: Your reset code is ${code}`);
}

export interface PasswordResetSession {
	id: string;
	userId: string;
	email: string;
	expiresAt: Date;
	code: string;
	emailVerified: boolean;
	// twoFactorVerified: boolean;
}

export type PasswordResetSessionValidationResult =
	| { session: PasswordResetSession; user: User }
	| { session: null; user: null };
