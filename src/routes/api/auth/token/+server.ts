import { jwtLoginHandler, jwtRefreshHandler } from 'sveltekit-drizzle-lucia-template';

export const POST = jwtLoginHandler;

export const PUT = jwtRefreshHandler;
