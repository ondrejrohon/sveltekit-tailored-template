import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';
import { config } from 'dotenv';

config();

if (!process.env.DATABASE_TEST_URL) {
	throw new Error('DATABASE_TEST_URL is not set in environment variables');
}

const client = postgres(process.env.DATABASE_TEST_URL);
export const testDb = drizzle(client);
