// lib/server/tokens.ts
import { SignJWT, jwtVerify } from 'jose';
import { nanoid } from 'nanoid';

const secret = new TextEncoder().encode(process.env.JWT_SECRET);

export async function generateTokens(userId: string) {
	const accessToken = await new SignJWT({ userId })
		.setProtectedHeader({ alg: 'HS256' })
		.setExpirationTime('15m')
		.sign(secret);

	const refreshToken = await new SignJWT({
		userId,
		tokenId: nanoid()
	})
		.setProtectedHeader({ alg: 'HS256' })
		.setExpirationTime('7d')
		.sign(secret);

	// Optionally store refresh token in database for revocation
	// await storeRefreshToken(refreshToken, userId);

	return { accessToken, refreshToken };
}

export async function verifyRefreshToken(token: string) {
	const { payload } = await jwtVerify(token, secret);
	// Check if token is revoked
	// await checkIfTokenRevoked(payload.tokenId);
	return payload;
}
