// import { decrypt, decryptToString, encrypt, encryptString } from '$lib/server/auth/encryption';
import { hashPassword } from '$lib/server/auth/password';
// import { generateRandomRecoveryCode } from '$lib/server/auth/utils';
import { db } from '$lib/server/db';
import * as tables from '$lib/server/db/schema';
import { and, eq } from 'drizzle-orm';

export function verifyUsernameInput(username: string): boolean {
	return username.length > 3 && username.length < 32 && username.trim() === username;
}

export async function createUser(email: string, password: string): Promise<User> {
	const passwordHash = await hashPassword(password);
	const id = crypto.randomUUID();
	const [row] = await db.insert(tables.user).values({ id, email, passwordHash }).returning();
	if (row === null) {
		throw new Error('Unexpected error');
	}
	return row;
}

export async function updateUserPassword(userId: string, password: string): Promise<void> {
	const passwordHash = await hashPassword(password);
	await db.update(tables.user).set({ passwordHash }).where(eq(tables.user.id, userId));
}

export async function updateUserEmailAndSetEmailAsVerified(
	userId: string,
	email: string
): Promise<void> {
	// db.execute('UPDATE user SET email = ?, email_verified = 1 WHERE id = ?', [email, userId]);
	await db
		.update(tables.user)
		.set({ email, emailVerified: true })
		.where(eq(tables.user.id, userId));
}

export async function setUserAsEmailVerifiedIfEmailMatches(
	userId: string,
	email: string
): Promise<boolean> {
	const result = await db
		.update(tables.user)
		.set({ emailVerified: true })
		.where(and(eq(tables.user.id, userId), eq(tables.user.email, email)));
	return result.length > 0;
}

export async function getUserPasswordHash(userId: string): Promise<string> {
	// const row = db.queryOne('SELECT password_hash FROM user WHERE id = ?', [userId]);
	const [row] = await db
		.select({ passwordHash: tables.user.passwordHash })
		.from(tables.user)
		.where(eq(tables.user.id, userId));
	return row?.passwordHash ?? null;
}

// export function getUserRecoverCode(userId: number): string {
// 	const row = db.queryOne('SELECT recovery_code FROM user WHERE id = ?', [userId]);
// 	if (row === null) {
// 		throw new Error('Invalid user ID');
// 	}
// 	return decryptToString(row.bytes(0));
// }

// export function getUserTOTPKey(userId: number): Uint8Array | null {
// 	const row = db.queryOne('SELECT totp_key FROM user WHERE id = ?', [userId]);
// 	if (row === null) {
// 		throw new Error('Invalid user ID');
// 	}
// 	const encrypted = row.bytesNullable(0);
// 	if (encrypted === null) {
// 		return null;
// 	}
// 	return decrypt(encrypted);
// }

// export function updateUserTOTPKey(userId: number, key: Uint8Array): void {
// 	const encrypted = encrypt(key);
// 	db.execute('UPDATE user SET totp_key = ? WHERE id = ?', [encrypted, userId]);
// }

// export function resetUserRecoveryCode(userId: number): string {
// 	const recoveryCode = generateRandomRecoveryCode();
// 	const encrypted = encryptString(recoveryCode);
// 	db.execute('UPDATE user SET recovery_code = ? WHERE id = ?', [encrypted, userId]);
// 	return recoveryCode;
// }

export async function getUserFromEmail(email: string): Promise<User | null> {
	// const row = db.queryOne(
	// 	'SELECT id, email, username, email_verified, IIF(totp_key IS NOT NULL, 1, 0) FROM user WHERE email = ?',
	// 	[email]
	// );
	const [row] = await db
		.select({
			id: tables.user.id,
			email: tables.user.email,
			emailVerified: tables.user.emailVerified
		})
		.from(tables.user)
		.where(eq(tables.user.email, email));
	return row ?? null;
}

export interface User {
	id: string;
	email: string;
	// username: string;
	emailVerified: boolean;
	// registered2FA: boolean;
}
