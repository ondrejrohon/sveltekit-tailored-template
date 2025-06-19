<script lang="ts">
	import '../app.css';
	import { enhance } from '$app/forms';
	import type { LayoutServerData } from './$types';

	let { data, children }: { data: LayoutServerData; children: any } = $props();
</script>

{#if data?.user}
	<h1>Hi, {data.user.email}!</h1>
	<p>Your user ID is {data.user.id}.</p>
	<form method="post" action="?/logout" use:enhance>
		<button>Sign out</button>
	</form>
{:else}
	<header class="fixed top-0 right-0 left-0 z-50 bg-white">
		<nav class="flex items-center justify-between p-4">
			<a href="/">Home</a>
			<a href="/login">Login</a>
		</nav>
	</header>
{/if}

{@render children()}
