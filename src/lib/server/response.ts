export const unauthorizedResponse = new Response(null, { status: 401, statusText: 'Unauthorized' });

export const successResponse = (body: Record<string, unknown> = { ok: 'ok' }) =>
	new Response(JSON.stringify(body), {
		status: 200
	});

export const badRequestResponse = (message = 'invalid request') =>
	new Response(message, {
		status: 400
	});

export const serverErrorResponse = new Response(null, { status: 500 });

export const forbiddenErrorResponse = new Response(null, { status: 403 });
