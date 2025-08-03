import {
	resetPasswordVerificationActions,
	resetPasswordVerificationLoadHandler
} from 'sveltekit-tailored';

export const load = resetPasswordVerificationLoadHandler;

export const actions = resetPasswordVerificationActions;
