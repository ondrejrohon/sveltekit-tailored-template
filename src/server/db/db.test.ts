import { describe, it, expect } from 'vitest';
import { testDb } from 'src/server/db/test-db';
import * as tables from './schema.js';
import { eq } from 'drizzle-orm';

describe('Database Operations', () => {
	it('should write and read from user table', async () => {
		const testId = crypto.randomUUID();
		const testEmail = `test-${Date.now()}@test.com`;

		const [result] = await testDb
			.insert(tables.user)
			.values({
				id: testId,
				email: testEmail,
				passwordHash: 'test',
				emailVerified: false
			})
			.returning();

		expect(result).toBeDefined();
		expect(result.id).toBe(testId);
		expect(result.email).toBe(testEmail);

		const [readResult] = await testDb.select().from(tables.user).where(eq(tables.user.id, testId));

		expect(readResult).toBeDefined();
		expect(readResult.id).toBe(testId);
		expect(readResult.email).toBe(testEmail);

		// Clean up
		await testDb.delete(tables.user).where(eq(tables.user.id, testId));
	});
});
