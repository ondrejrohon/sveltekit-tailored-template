import { defineConfig } from 'drizzle-kit';

if (!process.env.DATABASE_TEST_URL) throw new Error('DATABASE_TEST_URL is not set');

export default defineConfig({
	schema: './src/server/db/schema.ts',

	dbCredentials: {
		url: process.env.DATABASE_TEST_URL
	},

	verbose: true,
	strict: true,
	dialect: 'postgresql'
});
