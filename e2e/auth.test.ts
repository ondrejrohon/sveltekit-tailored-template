import { expect, test } from '@playwright/test';
import { testDb } from '../src/server/db/test-db';
import * as tables from '../src/server/db/schema';
import { eq } from 'drizzle-orm';

test.describe('auth test', () => {
	test('create user and verify email', async ({ page }) => {
		const email = `testuser${Date.now()}@example.com`;

		// TODO: always wait for hydrated
		await page.goto('/');
		// Wait for SvelteKit app to be fully loaded
		await page.waitForSelector('body[data-sveltekit-hydrated]');

		await expect(page.locator('nav a')).toHaveCount(3);

		await page.getByTestId('signup').click();
		await page.getByRole('textbox', { name: 'Email' }).click();
		await page.getByRole('textbox', { name: 'Email' }).fill(email);
		await page.getByRole('textbox', { name: 'Email' }).press('Tab');
		await page.getByRole('textbox', { name: 'Password' }).fill('Nbusr123!@');
		await page.getByRole('button', { name: 'Create account' }).click();

		await Promise.all([
			page.getByRole('textbox', { name: 'Verification Code' }).click(),
			page.waitForURL('/verify-email')
		]);

		// get user from db
		const [user] = await testDb.select().from(tables.user).where(eq(tables.user.email, email));
		// update verification code in db to 111111
		await testDb
			.update(tables.emailVerificationRequest)
			.set({ code: '111111' })
			.where(eq(tables.emailVerificationRequest.userId, user.id));

		await page.getByRole('textbox', { name: 'Verification Code' }).fill('111111');
		await Promise.all([
			page.getByRole('button', { name: 'Verify Email' }).click(),
			page.waitForURL('/')
		]);

		// verify that user is verified
		const [user2] = await testDb.select().from(tables.user).where(eq(tables.user.email, email));

		expect(user2.emailVerified).toBe(true);

		// sign out and login back in
		await page.getByTestId('signout').click();
		await page.getByTestId('login').click();
		await page.getByRole('textbox', { name: 'Email' }).fill(email);
		await page.getByRole('textbox', { name: 'Password' }).fill('Nbusr123!@');
		await page.getByRole('button', { name: 'Sign in' }).click();
		await page.waitForURL('/');
		await expect(page.getByTestId('signout')).toBeVisible();

		// test password reset
		await page.getByTestId('signout').click();
		await page.getByTestId('login').click();
		await Promise.all([
			page.getByRole('link', { name: 'Reset it here' }).click(),
			page.waitForURL('/forgot-password')
		]);
		await page.getByRole('textbox', { name: 'Email' }).fill(email);
		await Promise.all([
			page.getByRole('button', { name: 'Send reset link' }).click(),
			page.waitForURL('/reset-password/verify-email')
		]);

		// test wrong code first
		await page.getByTestId('verification-code').fill('111111');
		await page.getByRole('button', { name: 'Continue to reset password' }).click();
		await expect(page.getByText('Incorrect code')).toBeVisible();

		// set verification code in db
		await testDb
			.update(tables.passwordResetSession)
			.set({ code: '111111' })
			.where(eq(tables.passwordResetSession.userId, user2.id));

		await page.getByTestId('verification-code').fill('111111');
		await Promise.all([
			page.getByRole('button', { name: 'Continue to reset password' }).click(),
			page.waitForURL('/reset-password')
		]);
		await expect(page.getByText('Reset your password')).toBeVisible();
		await page.getByRole('textbox', { name: 'New Password' }).fill('newNbusr123!@');
		await Promise.all([
			page.getByRole('button', { name: 'Reset password' }).click(),
			page.waitForURL('/')
		]);
		await expect(page.getByTestId('signout')).toBeVisible();

		// test password reset
		await page.getByTestId('signout').click();
		await page.getByTestId('login').click();
		await page.getByRole('textbox', { name: 'Email' }).fill(email);
		await page.getByRole('textbox', { name: 'Password' }).fill('newNbusr123!@');
		await page.getByRole('button', { name: 'Sign in' }).click();
		await page.waitForURL('/');
		await expect(page.getByTestId('signout')).toBeVisible();
	});

	test('create user and test too many login attempts', async ({ page }) => {
		const email = `testuser${Date.now()}@example.com`;

		// TODO: always wait for hydrated
		await page.goto('/');
		// Wait for SvelteKit app to be fully loaded
		await page.waitForSelector('body[data-sveltekit-hydrated]');

		await expect(page.locator('nav a')).toHaveCount(3);

		await page.getByTestId('signup').click();
		await page.getByRole('textbox', { name: 'Email' }).click();
		await page.getByRole('textbox', { name: 'Email' }).fill(email);
		await page.getByRole('textbox', { name: 'Email' }).press('Tab');
		await page.getByRole('textbox', { name: 'Password' }).fill('Nbusr123!@');
		await page.getByRole('button', { name: 'Create account' }).click();

		await Promise.all([
			page.getByRole('textbox', { name: 'Verification Code' }).click(),
			page.waitForURL('/verify-email')
		]);

		// get user from db
		const [user] = await testDb.select().from(tables.user).where(eq(tables.user.email, email));
		// update verification code in db to 111111
		await testDb
			.update(tables.emailVerificationRequest)
			.set({ code: '111111' })
			.where(eq(tables.emailVerificationRequest.userId, user.id));

		await page.getByRole('textbox', { name: 'Verification Code' }).fill('111111');
		await Promise.all([
			page.getByRole('button', { name: 'Verify Email' }).click(),
			page.waitForURL('/')
		]);

		// verify that user is verified
		const [user2] = await testDb.select().from(tables.user).where(eq(tables.user.email, email));

		expect(user2.emailVerified).toBe(true);

		// sign out and login back in
		await page.getByTestId('signout').click();
		await page.getByTestId('login').click();
		await page.getByRole('textbox', { name: 'Email' }).fill(email);

		// test too many login attempts
		for (let i = 0; i < 2; i++) {
			await page.getByRole('textbox', { name: 'Password' }).fill('123');
			await page.getByRole('button', { name: 'Sign in' }).click();
			console.log('test too many login attempts', i);
			await expect(page.getByText('Invalid password')).toBeVisible();
		}
		await page.getByRole('textbox', { name: 'Password' }).fill('123');
		await page.getByRole('button', { name: 'Sign in' }).click();
		await expect(page.getByText('Too many requests')).toBeVisible();
	});

	test('create user and test too many reset attempts', async ({ page }) => {
		const email = `testuser${Date.now()}@example.com`;

		// TODO: always wait for hydrated
		await page.goto('/');
		// Wait for SvelteKit app to be fully loaded
		await page.waitForSelector('body[data-sveltekit-hydrated]');

		await expect(page.locator('nav a')).toHaveCount(3);

		await page.getByTestId('signup').click();
		await page.getByRole('textbox', { name: 'Email' }).click();
		await page.getByRole('textbox', { name: 'Email' }).fill(email);
		await page.getByRole('textbox', { name: 'Email' }).press('Tab');
		await page.getByRole('textbox', { name: 'Password' }).fill('Nbusr123!@');
		await page.getByRole('button', { name: 'Create account' }).click();

		await Promise.all([
			page.getByRole('textbox', { name: 'Verification Code' }).click(),
			page.waitForURL('/verify-email')
		]);

		// get user from db
		const [user] = await testDb.select().from(tables.user).where(eq(tables.user.email, email));
		// update verification code in db to 111111
		await testDb
			.update(tables.emailVerificationRequest)
			.set({ code: '111111' })
			.where(eq(tables.emailVerificationRequest.userId, user.id));

		await page.getByRole('textbox', { name: 'Verification Code' }).fill('111111');
		await Promise.all([
			page.getByRole('button', { name: 'Verify Email' }).click(),
			page.waitForURL('/')
		]);

		// verify that user is verified
		const [user2] = await testDb.select().from(tables.user).where(eq(tables.user.email, email));

		expect(user2.emailVerified).toBe(true);

		// sign out and login back in
		await page.getByTestId('signout').click();
		await page.getByTestId('login').click();

		await Promise.all([
			page.getByRole('link', { name: 'Reset it here' }).click(),
			page.waitForURL('/forgot-password')
		]);
		await page.getByRole('textbox', { name: 'Email' }).fill(email);
		await Promise.all([
			page.getByRole('button', { name: 'Send reset link' }).click(),
			page.waitForURL('/reset-password/verify-email')
		]);

		// test too many reset attempts
		for (let i = 0; i < 5; i++) {
			await page.getByTestId('verification-code').fill('111111');
			await page.getByRole('button', { name: 'Continue to reset password' }).click();
			console.log('test too many reset attempts', i);
			await expect(page.getByText('Incorrect code')).toBeVisible();
		}
		await page.getByTestId('verification-code').fill('111111');
		await page.getByRole('button', { name: 'Continue to reset password' }).click();
		await expect(page.getByText('Too many requests')).toBeVisible();
	});
});
