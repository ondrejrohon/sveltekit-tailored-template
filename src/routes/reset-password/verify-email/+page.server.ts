import {
	resetPasswordVerificationActions,
	resetPasswordVerificationLoadHandler
} from 'sveltekit-drizzle-lucia-template';

export const load = resetPasswordVerificationLoadHandler;

export const actions = resetPasswordVerificationActions;
