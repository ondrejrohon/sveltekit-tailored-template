import type { RequestHandler } from './$types';
import { signoutHandler } from 'sveltekit-tailored';

export const GET: RequestHandler = signoutHandler;
