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
			<a href="/signout">Sign out</a>
		{:else}
			<div class="flex gap-4">
				<a href="/login">Login</a>
				<a href="/signup">Signup</a>
			</div>
		{/if}
	</nav>
</header>

<main class="mt-[3.5rem] p-4">
	{@render children()}
</main>
