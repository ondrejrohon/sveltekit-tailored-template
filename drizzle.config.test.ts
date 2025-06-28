import { defineConfig } from 'drizzle-kit';

export default defineConfig({
	schema: './src/lib/server/db/schema.ts',

	dbCredentials: {
		url: 'postgres://ondrejrohon@localhost:5432/slova_test_db'
	},

	verbose: true,
	strict: true,
	dialect: 'postgresql'
});
