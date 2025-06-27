import { db } from '$lib/server/db';
import * as tables from '$lib/server/db/schema';
import { count, eq } from 'drizzle-orm';

export function verifyEmailInput(email: string): boolean {
	return /^.+@.+\..+$/.test(email) && email.length < 256;
}

export async function checkEmailAvailability(email: string): Promise<boolean> {
	const [row] = await db
		.select({ count: count() })
		.from(tables.user)
		.where(eq(tables.user.email, email));
	if (row === null) {
		throw new Error();
	}
	return row.count === 0;
}
