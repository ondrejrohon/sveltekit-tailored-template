<script>
	const body = JSON.stringify({
		conversation: [
			{
				role: 'user',
				content: 'write me haiku about flying'
			}
		]
	});

	async function streamResponse() {
		const response = await fetch('/api/anthropic', {
			method: 'POST',
			body
		});

		const reader = response.body?.getReader();

		if (!reader) return;

		const decoder = new TextDecoder();

		while (true) {
			const { done, value } = await reader.read();
			if (done) break;
			const text = decoder.decode(value, { stream: true });
			console.log(text);
		}
	}
</script>

<div>
	<h1>Anthropic</h1>
	<button onclick={streamResponse}>stream</button>
</div>
