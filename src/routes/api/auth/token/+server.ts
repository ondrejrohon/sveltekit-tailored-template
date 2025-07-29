import { jwtLoginHandler, jwtRefreshHandler } from 'sveltekit-tailored';

export const POST = jwtLoginHandler;

export const PUT = jwtRefreshHandler;
