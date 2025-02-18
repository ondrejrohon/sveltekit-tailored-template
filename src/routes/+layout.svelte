<script lang="ts">
	import '../app.css';
	import { enhance } from '$app/forms';
	import type { LayoutServerData } from './$types';

	let { data, children }: { data: LayoutServerData; children: any } = $props();
</script>

{#if data?.user}
	<h1>Hi, {data.user.username}!</h1>
	<p>Your user ID is {data.user.id}.</p>
	<form method="post" action="?/logout" use:enhance>
		<button>Sign out</button>
	</form>
{:else}
	<a href="/login">Login</a>
{/if}

{@render children()}
