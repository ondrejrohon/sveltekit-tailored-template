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
			<form method="post" use:enhance action="?/verify" class="space-y-6">
				<div>
					<label for="form-verify.code" class="mb-2 block text-sm font-medium text-gray-700">
						Verification Code
					</label>
					<input
						id="form-verify.code"
						name="code"
						required
						class="w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm transition-colors focus:border-blue-500 focus:ring-2 focus:ring-blue-500 focus:outline-none"
						placeholder="Enter 8-digit code"
					/>
				</div>

				<Button
					class="w-full rounded-md bg-blue-600 px-4 py-2 font-medium text-white transition-colors hover:bg-blue-700"
					type="submit"
				>
					Verify Email
				</Button>

				{#if form?.verify?.message}
					<div class="rounded-md border border-red-200 bg-red-50 p-3">
						<p class="text-sm text-red-600">{form.verify.message}</p>
					</div>
				{/if}
			</form>

			<div class="mt-6">
				<div class="relative">
					<div class="absolute inset-0 flex items-center">
						<div class="w-full border-t border-gray-300"></div>
					</div>
					<div class="relative flex justify-center text-sm">
						<span class="bg-white px-2 text-gray-500">Or</span>
					</div>
				</div>

				<div class="mt-6">
					<form method="post" use:enhance action="?/resend">
						<Button
							class="w-full rounded-md border border-gray-300 bg-white px-4 py-2 font-medium text-gray-700 transition-colors hover:bg-gray-50"
							type="submit"
						>
							Resend Code
						</Button>
					</form>
				</div>
			</div>

			{#if form?.resend?.message}
				<div class="mt-4 rounded-md border border-green-200 bg-green-50 p-3">
					<p class="text-sm text-green-600">{form.resend.message}</p>
				</div>
			{/if}
		</div>
	</div>
</div>
