// routes/api/auth/token/+server.ts
import { json } from '@sveltejs/kit';
import { generateTokens, verifyRefreshToken } from '$lib/server/jwt-auth';
import { RefillingTokenBucket, Throttler } from '$lib/server/lucia-auth/rate-limit';
import { verifyEmailInput } from '$lib/server/lucia-auth/email';
import { getUserFromEmail, getUserPasswordHash } from '$lib/server/lucia-auth/user';
import { verifyPasswordHash } from '$lib/server/lucia-auth/password';

const throttler = new Throttler<string>([0, 1, 2, 4, 8, 16, 30, 60, 180, 300]);
const ipBucket = new RefillingTokenBucket<string>(20, 1);

export async function POST({ request }) {
	// TODO: Assumes X-Forwarded-For is always included.
	const clientIP = request.headers.get('X-Forwarded-For');
	if (clientIP !== null && !ipBucket.check(clientIP, 1)) {
		return new Response(JSON.stringify({ error: 'Too many requests' }), { status: 429 });
	}

	const { email, password } = await request.json();

	if (typeof email !== 'string' || typeof password !== 'string') {
		return new Response(JSON.stringify({ error: 'Invalid or missing fields' }), { status: 400 });
	}

	if (email === '' || password === '') {
		return new Response(JSON.stringify({ error: 'Please enter your email and password.' }), {
			status: 400
		});
	}

	if (!verifyEmailInput(email)) {
		return new Response(JSON.stringify({ error: 'Invalid email' }), { status: 400 });
	}

	const user = await getUserFromEmail(email);
	if (!user) {
		return new Response(JSON.stringify({ error: 'Account does not exist' }), { status: 400 });
	}

	if (clientIP !== null && !ipBucket.consume(clientIP, 1)) {
		return new Response(JSON.stringify({ error: 'Too many requests' }), { status: 429 });
	}

	if (!throttler.consume(user.id)) {
		return new Response(JSON.stringify({ error: 'Too many requests' }), { status: 429 });
	}

	const passwordHash = await getUserPasswordHash(user.id);
	const validPassword = await verifyPasswordHash(passwordHash, password);
	if (!validPassword) {
		return new Response(JSON.stringify({ error: 'Invalid password' }), { status: 400 });
	}
	throttler.reset(user.id);

	// Generate tokens instead of session
	const { accessToken, refreshToken } = await generateTokens(user.id);

	return json({ accessToken, refreshToken });
}

export async function PUT({ request }) {
	const { refreshToken } = await request.json();
	try {
		const { userId } = await verifyRefreshToken(refreshToken);

		if (!userId) {
			return json({ error: 'Invalid refresh token' }, { status: 401 });
		}

		// Generate new tokens
		const tokens = await generateTokens(userId as string);
		return json(tokens);
	} catch (error) {
		console.error(error);
		return json({ error: 'Invalid refresh token' }, { status: 401 });
	}
}
