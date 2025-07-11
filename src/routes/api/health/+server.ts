import type { RequestHandler } from './$types';
import { db } from '$lib/server/db';

export const GET: RequestHandler = async ({ locals }) => {
	try {
		// Check database connectivity
		await db.execute('SELECT 1');

		// Check if user is authenticated (optional for health check)
		const isAuthenticated = !!locals.user;

		return new Response(
			'ok'
			// JSON.stringify({
			// 	status: 'ok',
			// 	timestamp: new Date().toISOString(),
			// 	database: 'connected',
			// 	authenticated: isAuthenticated
			// }),
			// {
			// 	headers: {
			// 		'Content-Type': 'application/json'
			// 	}
			// }
		);
	} catch (error) {
		console.error('Health check failed:', error);
		return new Response(
			JSON.stringify({
				status: 'error',
				timestamp: new Date().toISOString(),
				error: 'Database connection failed'
			}),
			{
				status: 500,
				headers: {
					'Content-Type': 'application/json'
				}
			}
		);
	}
};
