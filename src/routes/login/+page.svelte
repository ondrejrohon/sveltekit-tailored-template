<script lang="ts">
	import { enhance } from '$app/forms';
	import type { ActionData } from './$types';
	import { Button } from '$lib/components/ui/button';

	let { form }: { form: ActionData } = $props();
</script>

<h1>Login/Register</h1>
<form method="post" action="?/login" use:enhance>
	<label>
		Email
		<input name="email" type="email" />
	</label>
	<label>
		Password
		<input type="password" name="password" />
	</label>
	<Button>Login</Button>
	<Button formaction="?/register">Register</Button>
</form>

<span>or</span>

<Button href="/login/google" class="google-button">Sign in with Google</Button>

<p style="color: red">{form?.message ?? ''}</p>
