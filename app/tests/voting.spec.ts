import { test, expect } from '@playwright/test';

const proofTimeout = 60_000;

test('load the app correctly', async ({ page }) => {
  await page.goto('/');
  await expect(page).toHaveTitle(/Private Voting/);
});

test('create an account', async ({ page }) => {
  await page.goto('/');

  const createAccountButton = await page.locator('#create-account');
  const accountDisplay = await page.locator('#account-display');

  await expect(createAccountButton).toBeVisible();
  await createAccountButton.click();

  await expect(accountDisplay).toBeVisible({ timeout: proofTimeout });
  await expect(accountDisplay).toHaveText(/Account: 0x[a-fA-F0-9]{4}/);
});

test('cast vote', async ({ page }) => {
  await page.goto('/');

  const createAccountButton = await page.locator('#create-account');
  const accountDisplay = await page.locator('#account-display');
  const voteButton = await page.locator('#vote-button');
  const voteInput = await page.locator('#vote-input');
  const voteResults = await page.locator('#vote-results');

  // Create account
  await expect(createAccountButton).toBeVisible();
  await createAccountButton.click();
  await expect(accountDisplay).toBeVisible({ timeout: proofTimeout });
  await expect(accountDisplay).toHaveText(/Account: 0x[a-fA-F0-9]{4}/);

  // Cast vote
  await expect(voteInput).toBeVisible();
  await expect(voteButton).toBeVisible();
  await voteInput.selectOption('3');
  await voteButton.click();
  await expect(voteButton).toBeEnabled({
    enabled: true,
    timeout: proofTimeout,
  });

  // Verify vote results
  await expect(voteResults).toHaveText(/Candidate 0: 0 votes/);
  await expect(voteResults).toHaveText(/Candidate 3: 1 votes/);
});
