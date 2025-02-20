import type { RequestHandler } from './$types';
import { anthropic } from '$lib/server/anthropic';

export const POST: RequestHandler = async ({ request }) => {
	const { conversation } = await request.json();

	const stream = new ReadableStream({
		async start(controller) {
			try {
				anthropic.messages
					.stream({
						messages: conversation,
						model: 'claude-3-5-sonnet-20241022',
						max_tokens: 1024
					})
					.on('text', (text) => {
						controller.enqueue(`data: ${JSON.stringify({ text })}\n\n`);
					})
					.on('end', () => {
						controller.enqueue(`data: ${JSON.stringify({ done: true })}\n\n`);
						controller.close();
					})
					.on('error', (error) => {
						controller.error(error);
					});
			} catch (error) {
				controller.error(error);
			}
		}
	});

	// Return SSE response with the appropriate headers
	return new Response(stream, {
		headers: {
			'Content-Type': 'text/event-stream',
			'Cache-Control': 'no-cache',
			Connection: 'keep-alive'
		}
	});
};
