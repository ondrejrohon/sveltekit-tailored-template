// routes/api/auth/token/+server.ts
import * as auth from '$lib/server/auth';
import { json } from '@sveltejs/kit';
import { generateTokens, verifyRefreshToken } from '$lib/server/tokens';

export async function POST({ request }) {
	// Regular login logic
	const { username, password } = await request.json();
	const user = await auth.authenticateUser(username, password);

	if (!user) {
		return json({ error: 'Invalid username or password' }, { status: 401 });
	}

	// Generate tokens instead of session
	const { accessToken, refreshToken } = await generateTokens(user.id);

	return json({ accessToken, refreshToken });
}

// Refresh token endpoint
export async function PUT({ request }) {
	const { refreshToken } = await request.json();
	const { userId } = await verifyRefreshToken(refreshToken);

	// Generate new tokens
	const tokens = await generateTokens(userId);
	return json(tokens);
}
