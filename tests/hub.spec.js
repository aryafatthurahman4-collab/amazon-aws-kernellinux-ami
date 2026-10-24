// @ts-check
import { test, expect } from '@playwright/test';

test.describe('Amazon Linux Reference Hub', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('hero renders with title and stats', async ({ page }) => {
    await expect(page).toHaveTitle(/Amazon Linux Reference Hub/);
    await expect(
      page.getByRole('heading', { level: 1, name: /Amazon Linux\s+Reference Hub/ })
    ).toBeVisible();

    await expect(page.locator('.stat-number[data-target="10"]')).toHaveText('10');
    await expect(page.locator('.stat-number[data-target="4"]')).toHaveText('4');
  });

  test('theme toggle switches and persists in localStorage', async ({ page }) => {
    const html = page.locator('html');
    const toggle = page.getByRole('button', { name: 'Toggle theme' });

    await toggle.click({ force: true });
    await expect(html).toHaveAttribute('data-theme', 'light');
    expect(await page.evaluate(() => localStorage.getItem('al-hub-theme'))).toBe('light');

    await toggle.click({ force: true });
    await expect(html).toHaveAttribute('data-theme', 'dark');

    await page.reload();
    await expect(html).toHaveAttribute('data-theme', 'dark');
  });

  test('IaC tabs switch panels', async ({ page }) => {
    const cloudFormation = page.getByRole('button', { name: /CloudFormation/ });
    await cloudFormation.click();

    await expect(cloudFormation).toHaveClass(/active/);
    await expect(page.locator('#tab-cloudformation')).toBeVisible();
    await expect(page.locator('#tab-terraform')).toBeHidden();

    await expect(page.locator('#tab-cloudformation')).toContainText('AWS::EC2::Instance');
  });

  test('copy button writes code to clipboard', async ({ page, context, browserName }) => {
    const canReadClipboard = browserName === 'chromium';
    if (canReadClipboard) {
      await context.grantPermissions(['clipboard-read', 'clipboard-write']);
    }

    const copyBtn = page.locator('.copy-btn').first();
    await copyBtn.click();

    await expect(copyBtn).toHaveText(/Copied/);
    if (canReadClipboard) {
      const clipboard = await page.evaluate(() => navigator.clipboard.readText());
      expect(clipboard).toContain('dnf check-release-update');
    }
  });

  test('mobile menu opens and closes on link click', async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });

    const menuBtn = page.locator('#mobileMenuBtn');
    const navLinks = page.locator('#navLinks');

    await expect(menuBtn).toBeVisible();
    await menuBtn.click({ force: true });
    await expect(navLinks).toHaveClass(/open/);

    await navLinks.getByRole('link', { name: 'Kernel' }).click({ force: true });
    await expect(navLinks).not.toHaveClass(/open/);
  });

  test('navigation jumps to sections and highlights active link', async ({ page }) => {
    await page.getByRole('link', { name: 'Cheat Sheet' }).click({ force: true });

    await expect(page.locator('#cheatsheet')).toBeInViewport();
    await expect(page.locator('.nav-link', { hasText: 'Cheat Sheet' })).toHaveClass(/active/);
  });
});
