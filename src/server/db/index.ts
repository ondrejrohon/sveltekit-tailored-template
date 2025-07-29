import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';
import { env } from '$env/dynamic/private';

if (!env.DATABASE_URL) throw new Error('DATABASE_URL is not set');

const dbUrl = process.env.NODE_ENV === 'test' ? env.DATABASE_TEST_URL : env.DATABASE_URL;

console.log('env', process.env.NODE_ENV, 'dbUrl', dbUrl);

const client = postgres(dbUrl);

export const db = drizzle(client);
