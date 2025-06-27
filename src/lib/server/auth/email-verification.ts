import { generateRandomOTP } from './utils';
import { db } from '$lib/server/db';
import * as tables from '$lib/server/db/schema';
import { and, eq } from 'drizzle-orm';
import { ExpiringTokenBucket } from './rate-limit';
import { encodeBase32 } from '@oslojs/encoding';

import type { RequestEvent } from '@sveltejs/kit';

export async function getUserEmailVerificationRequest(
	userId: string,
	id: string
): Promise<EmailVerificationRequest | null> {
	const [row] = await db
		.select()
		.from(tables.emailVerificationRequest)
		.where(
			and(
				eq(tables.emailVerificationRequest.id, id),
				eq(tables.emailVerificationRequest.userId, userId)
			)
		);
	return row ?? null;
}

export async function createEmailVerificationRequest(
	userId: string,
	email: string
): Promise<EmailVerificationRequest> {
	deleteUserEmailVerificationRequest(userId);
	const idBytes = new Uint8Array(20);
	crypto.getRandomValues(idBytes);
	const id = encodeBase32(idBytes).toLowerCase();

	const code = generateRandomOTP();
	const expiresAt = new Date(Date.now() + 1000 * 60 * 10);
	const [row] = await db
		.insert(tables.emailVerificationRequest)
		.values({ id, userId, code, email, expiresAt })
		.returning();
	return row;
}

export async function deleteUserEmailVerificationRequest(userId: string): Promise<void> {
	await db
		.delete(tables.emailVerificationRequest)
		.where(eq(tables.emailVerificationRequest.userId, userId));
}

export function sendVerificationEmail(email: string, code: string): void {
	console.log(`To ${email}: Your verification code is ${code}`);
}

export function setEmailVerificationRequestCookie(
	event: RequestEvent,
	request: EmailVerificationRequest
): void {
	event.cookies.set('email_verification', request.id, {
		httpOnly: true,
		path: '/',
		secure: import.meta.env.PROD,
		sameSite: 'lax',
		expires: request.expiresAt
	});
}

export function deleteEmailVerificationRequestCookie(event: RequestEvent): void {
	event.cookies.set('email_verification', '', {
		httpOnly: true,
		path: '/',
		secure: import.meta.env.PROD,
		sameSite: 'lax',
		maxAge: 0
	});
}

export async function getUserEmailVerificationRequestFromRequest(
	event: RequestEvent
): Promise<EmailVerificationRequest | null> {
	if (event.locals.user === null) {
		return null;
	}
	const id = event.cookies.get('email_verification') ?? null;
	if (id === null) {
		return null;
	}
	const request = await getUserEmailVerificationRequest(event.locals.user.id, id);
	if (request === null) {
		deleteEmailVerificationRequestCookie(event);
	}
	return request;
}

export const sendVerificationEmailBucket = new ExpiringTokenBucket<number>(3, 60 * 10);

export interface EmailVerificationRequest {
	id: string;
	userId: string;
	code: string;
	email: string;
	expiresAt: Date;
}
