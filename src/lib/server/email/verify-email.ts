import { generateRandomOTP } from '$lib/server/auth/utils';
import { ExpiringTokenBucket } from '$lib/server/auth/rate-limit';
import { and, eq } from 'drizzle-orm';

import type { RequestEvent } from '@sveltejs/kit';
import { db } from '$lib/server/db';
import * as table from '$lib/server/db/schema';

export async function getUserEmailVerificationRequest(
	userId: string,
	id: string
): Promise<EmailVerificationRequest | null> {
	const [row] = await db
		.select()
		.from(table.emailVerificationRequest)
		.where(
			and(
				eq(table.emailVerificationRequest.id, id),
				eq(table.emailVerificationRequest.userId, userId)
			)
		);
	if (!row) {
		return null;
	}
	return row;
}

export async function createEmailVerificationRequest(
	userId: string,
	email: string
): Promise<EmailVerificationRequest> {
	deleteUserEmailVerificationRequest(userId);
	const id = crypto.randomUUID();

	const code = generateRandomOTP();
	const expiresAt = new Date(Date.now() + 1000 * 60 * 10);
	const [row] = await db.insert(table.emailVerificationRequest).values({
		id,
		userId,
		code,
		email,
		expiresAt
	});
	return row;
}

export async function deleteUserEmailVerificationRequest(userId: string): Promise<void> {
	await db
		.delete(table.emailVerificationRequest)
		.where(eq(table.emailVerificationRequest.userId, userId));
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
	if (!event.locals.user) {
		return null;
	}
	const id = event.cookies.get('email_verification') ?? null;
	if (!id) {
		return null;
	}
	const request = await getUserEmailVerificationRequest(event.locals.user.id, id);
	if (!request) {
		deleteEmailVerificationRequestCookie(event);
	}
	return request;
}

export const sendVerificationEmailBucket = new ExpiringTokenBucket<string>(3, 60 * 10);

export interface EmailVerificationRequest {
	id: string;
	userId: string;
	code: string;
	email: string;
	expiresAt: Date;
}
