<script lang="ts">
	import type { LayoutServerData } from './$types';
	import { onMount } from 'svelte';
	import { browser } from '$app/environment';
	import '../app.css';

	let { data, children }: { data: LayoutServerData; children: any } = $props();

	onMount(() => {
		if (browser) {
			document.body.setAttribute('data-sveltekit-hydrated', '');
		}
	});
</script>

<header class="fixed top-0 right-0 left-0 z-50 bg-white">
	<nav class="flex items-center justify-between p-4">
		<a href="/">Home</a>
		{#if data?.user}
			<a href="/signout" data-testid="signout">Sign out</a>
		{:else}
			<div class="flex gap-4">
				<a href="/login" data-testid="login">Login</a>
				<a href="/signup" data-testid="signup">Signup</a>
			</div>
		{/if}
	</nav>
</header>

<main class="mt-[3.5rem] p-4">
	{@render children()}
</main>
