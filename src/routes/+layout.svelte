<script lang="ts">
	import '../app.css';
	import { enhance } from '$app/forms';
	import type { LayoutServerData } from './$types';

	let { data, children }: { data: LayoutServerData; children: any } = $props();
</script>

<header class="fixed top-0 right-0 left-0 z-50 bg-white">
	<nav class="flex items-center justify-between p-4">
		<a href="/">Home</a>
		{#if data?.user}
			<form method="post" action="?/logout" use:enhance>
				<button>Sign out</button>
			</form>
		{:else}
			<div class="flex gap-4">
				<a href="/login">Login</a>
				<a href="/signup">Signup</a>
			</div>
		{/if}
	</nav>
</header>

{@render children()}
