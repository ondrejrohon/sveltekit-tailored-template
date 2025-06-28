import { describe, it, expect } from 'vitest';
import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';
import * as tables from './server/db/schema.js';
import { eq } from 'drizzle-orm';

// Create a test database connection
const testClient = postgres('postgres://ondrejrohon@localhost:5432/slova_test_db');
const testDb = drizzle(testClient);

describe('Database Operations', () => {
	it('should write and read from user table', async () => {
		const testId = crypto.randomUUID();
		const testEmail = `test-${Date.now()}@test.com`;

		console.log('Inserting test user...');
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

		console.log('Reading test user...');
		const [readResult] = await testDb.select().from(tables.user).where(eq(tables.user.id, testId));

		expect(readResult).toBeDefined();
		expect(readResult.id).toBe(testId);
		expect(readResult.email).toBe(testEmail);

		console.log('Cleaning up test user...');
		// Clean up
		await testDb.delete(tables.user).where(eq(tables.user.id, testId));

		console.log('Test completed successfully!');
	});
});
