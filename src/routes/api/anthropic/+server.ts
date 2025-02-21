import type { RequestHandler } from './$types';
import { anthropic } from '$lib/server/anthropic';
import { db } from '$lib/server/db';
import { conversation as conversationTable } from '$lib/server/db/schema';

export const POST: RequestHandler = async ({ request, locals }) => {
	if (!locals.user) {
		return new Response('Unauthorized', { status: 401 });
	}

	const { conversation } = await request.json();
	let response = '';

	const stream = new ReadableStream({
		async start(controller) {
			try {
				const userId = locals.user!.id;
				anthropic.messages
					.stream({
						messages: conversation,
						model: 'claude-3-5-sonnet-20241022',
						max_tokens: 1024
					})
					.on('text', (text) => {
						response += text;
						controller.enqueue(`data: ${JSON.stringify({ text })}\n\n`);
					})
					.on('end', async () => {
						try {
							const newConversation = [...conversation, { role: 'assistant', content: response }];
							await db.insert(conversationTable).values({
								userId,
								conversation: JSON.stringify(newConversation)
							});
						} catch (error) {
							console.log('failed to insert conversation');
							console.error('Error details:', error);
						} finally {
							controller.enqueue(`data: ${JSON.stringify({ done: true })}\n\n`);
							controller.close();
						}
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
