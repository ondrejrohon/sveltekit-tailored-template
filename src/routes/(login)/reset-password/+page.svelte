<script lang="ts">
	import { enhance } from '$app/forms';
	import type { ActionData } from './$types';
	import { Button } from '$lib/components/ui/button';

	let { form }: { form: ActionData } = $props();
</script>

<div class="flex min-h-screen items-center justify-center bg-gray-50 px-4 py-12 sm:px-6 lg:px-8">
	<div class="w-full max-w-md space-y-8">
		<div class="text-center">
			<h1 class="mb-2 text-3xl font-bold text-gray-900">Reset your password</h1>
			<p class="text-gray-600">Enter your new password below</p>
		</div>

		<div class="rounded-lg border border-gray-200 bg-white px-6 py-8 shadow-lg">
			<form method="post" use:enhance class="space-y-6">
				<div>
					<label for="password" class="mb-2 block text-sm font-medium text-gray-700">
						New Password
					</label>
					<input
						id="password"
						class="w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm transition-colors focus:border-blue-500 focus:ring-2 focus:ring-blue-500 focus:outline-none"
						type="password"
						name="password"
						autocomplete="new-password"
						required
					/>
				</div>

				<Button
					class="w-full rounded-md bg-blue-600 px-4 py-2 font-medium text-white transition-colors hover:bg-blue-700"
					type="submit"
				>
					Reset password
				</Button>
			</form>

			<div class="mt-6 text-center">
				<p class="text-sm text-gray-600">
					Remember your password?
					<a href="/login" class="font-medium text-blue-600 transition-colors hover:text-blue-500">
						Sign in here
					</a>
				</p>
			</div>

			{#if form?.message}
				<div class="mt-4 rounded-md border border-red-200 bg-red-50 p-3">
					<p class="text-sm text-red-600">{form.message}</p>
				</div>
			{/if}
		</div>
	</div>
</div>
