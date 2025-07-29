import type { RequestHandler } from './$types';
import { signoutHandler } from 'sveltekit-drizzle-lucia-template';

export const GET: RequestHandler = signoutHandler;
