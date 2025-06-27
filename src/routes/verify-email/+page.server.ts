import { fail, redirect } from '@sveltejs/kit';
import {
	createEmailVerificationRequest,
	deleteEmailVerificationRequestCookie,
	deleteUserEmailVerificationRequest,
	getUserEmailVerificationRequestFromRequest,
	sendVerificationEmail,
	sendVerificationEmailBucket,
	setEmailVerificationRequestCookie
} from '$lib/server/email/verify-email';
import { invalidateUserPasswordResetSessions } from '$lib/server/lucia-auth/password-reset';
import { updateUserEmailAndSetEmailAsVerified } from '$lib/server/lucia-auth/user';
import { ExpiringTokenBucket } from '$lib/server/lucia-auth/rate-limit';

import type { Actions, RequestEvent } from './$types';

export async function load(event: RequestEvent) {
	if (!event.locals.user) {
		return redirect(302, '/login');
	}
	let verificationRequest = await getUserEmailVerificationRequestFromRequest(event);
	if (!verificationRequest || Date.now() >= verificationRequest.expiresAt.getTime()) {
		if (event.locals.user.emailVerified) {
			return redirect(302, '/');
		}
		// Note: We don't need rate limiting since it takes time before requests expire
		verificationRequest = await createEmailVerificationRequest(
			event.locals.user.id,
			event.locals.user.email
		);
		sendVerificationEmail(verificationRequest.email, verificationRequest.code);
		setEmailVerificationRequestCookie(event, verificationRequest);
	}
	return {
		email: verificationRequest.email
	};
}

const bucket = new ExpiringTokenBucket<string>(5, 60 * 30);

export const actions: Actions = {
	verify: verifyCode,
	resend: resendEmail
};

async function verifyCode(event: RequestEvent) {
	if (!event.locals.session || !event.locals.user) {
		return fail(401, {
			verify: {
				message: 'Not authenticated'
			}
		});
	}
	// if (event.locals.user.registered2FA && !event.locals.session.twoFactorVerified) {
	// 	return fail(403, {
	// 		verify: {
	// 			message: "Forbidden"
	// 		}
	// 	});
	// }
	if (!bucket.check(event.locals.user.id, 1)) {
		return fail(429, {
			verify: {
				message: 'Too many requests'
			}
		});
	}

	let verificationRequest = await getUserEmailVerificationRequestFromRequest(event);
	if (!verificationRequest) {
		return fail(401, {
			verify: {
				message: 'Not authenticated'
			}
		});
	}
	const formData = await event.request.formData();
	const code = formData.get('code');
	if (typeof code !== 'string') {
		return fail(400, {
			verify: {
				message: 'Invalid or missing fields'
			}
		});
	}
	if (code === '') {
		return fail(400, {
			verify: {
				message: 'Enter your code'
			}
		});
	}
	if (!bucket.consume(event.locals.user.id, 1)) {
		return fail(400, {
			verify: {
				message: 'Too many requests'
			}
		});
	}
	if (Date.now() >= verificationRequest.expiresAt.getTime()) {
		verificationRequest = await createEmailVerificationRequest(
			verificationRequest.userId,
			verificationRequest.email
		);
		sendVerificationEmail(verificationRequest.email, verificationRequest.code);
		return {
			verify: {
				message: 'The verification code was expired. We sent another code to your inbox.'
			}
		};
	}
	if (verificationRequest.code !== code) {
		return fail(400, {
			verify: {
				message: 'Incorrect code.'
			}
		});
	}
	deleteUserEmailVerificationRequest(event.locals.user.id);
	invalidateUserPasswordResetSessions(event.locals.user.id);
	updateUserEmailAndSetEmailAsVerified(event.locals.user.id, verificationRequest.email);
	deleteEmailVerificationRequestCookie(event);
	// if (!event.locals.user.registered2FA) {
	// 	return redirect(302, '/2fa/setup');
	// }
	return redirect(302, '/');
}

async function resendEmail(event: RequestEvent) {
	if (!event.locals.session || !event.locals.user) {
		return fail(401, {
			resend: {
				message: 'Not authenticated'
			}
		});
	}
	// enable for 2fa
	// if (event.locals.user.registered2FA && !event.locals.session.twoFactorVerified) {
	// 	return fail(403, {
	// 		resend: {
	// 			message: 'Forbidden'
	// 		}
	// 	});
	// }
	if (!sendVerificationEmailBucket.check(event.locals.user.id, 1)) {
		return fail(429, {
			resend: {
				message: 'Too many requests'
			}
		});
	}

	let verificationRequest = await getUserEmailVerificationRequestFromRequest(event);
	if (!verificationRequest) {
		if (event.locals.user.emailVerified) {
			return fail(403, {
				resend: {
					message: 'Forbidden'
				}
			});
		}
		if (!sendVerificationEmailBucket.consume(event.locals.user.id, 1)) {
			return fail(429, {
				resend: {
					message: 'Too many requests'
				}
			});
		}
		verificationRequest = await createEmailVerificationRequest(
			event.locals.user.id,
			event.locals.user.email
		);
	} else {
		if (!sendVerificationEmailBucket.consume(event.locals.user.id, 1)) {
			return fail(429, {
				resend: {
					message: 'Too many requests'
				}
			});
		}
		verificationRequest = await createEmailVerificationRequest(
			event.locals.user.id,
			verificationRequest.email
		);
	}
	sendVerificationEmail(verificationRequest.email, verificationRequest.code);
	setEmailVerificationRequestCookie(event, verificationRequest);
	return {
		resend: {
			message: 'A new code was sent to your inbox.'
		}
	};
}
