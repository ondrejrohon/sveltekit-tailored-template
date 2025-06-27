<script lang="ts">
	import { enhance } from '$app/forms';
	import type { ActionData, PageData } from './$types';
	import { Button } from '$lib/components/ui/button';

	export let data: PageData;
	export let form: ActionData;
</script>

<div class="flex min-h-screen items-center justify-center bg-gray-50 px-4 py-12 sm:px-6 lg:px-8">
	<div class="w-full max-w-md space-y-8">
		<div class="text-center">
			<h1 class="mb-2 text-3xl font-bold text-gray-900">Verify your email address</h1>
			<p class="text-gray-600">We sent an 8-digit code to {data.email}</p>
		</div>

		<div class="rounded-lg border border-gray-200 bg-white px-6 py-8 shadow-lg">
			<form method="post" use:enhance class="space-y-6">
				<div>
					<label for="code" class="mb-2 block text-sm font-medium text-gray-700">
						Verification Code
					</label>
					<input
						id="code"
						class="w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm transition-colors focus:border-blue-500 focus:ring-2 focus:ring-blue-500 focus:outline-none"
						name="code"
						type="text"
						required
						placeholder="Enter 8-digit code"
					/>
				</div>

				<Button
					class="w-full rounded-md bg-blue-600 px-4 py-2 font-medium text-white transition-colors hover:bg-blue-700"
					type="submit"
				>
					Verify Email
				</Button>
			</form>

			<div class="mt-6 text-center">
				<p class="text-sm text-gray-600">
					Didn't receive the code?
					<a
						href="/forgot-password"
						class="font-medium text-blue-600 transition-colors hover:text-blue-500"
					>
						Request a new one
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
