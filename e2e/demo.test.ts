import { expect, test } from '@playwright/test';
import { testDb } from '../src/lib/server/db/test-db';
import * as tables from '../src/lib/server/db/schema';
import { eq } from 'drizzle-orm';

test('home page has expected h1', async ({ page }) => {
	await page.goto('/');
	await expect(page.locator('h1')).toBeVisible();

	const [user] = await testDb
		.insert(tables.user)
		.values({
			id: crypto.randomUUID(),
			email: 'test@test.com',
			passwordHash: 'test',
			emailVerified: false
		})
		.returning();

	const [readUser] = await testDb.select().from(tables.user).where(eq(tables.user.id, user.id));

	expect(readUser).toBeDefined();
	expect(readUser.email).toBe('test@test.com');
	expect(readUser.passwordHash).toBe('test');
	expect(readUser.emailVerified).toBe(false);

	// clean up
	await testDb.delete(tables.user).where(eq(tables.user.id, user.id));
});
