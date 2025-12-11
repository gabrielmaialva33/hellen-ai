// @ts-check
const { test, expect } = require('@playwright/test');
const fs = require('fs');
const path = require('path');

// Test file paths
const TEST_MP3 = '/Users/gabrielmaia/Documents/hellen-ai/tmp/Simulação de Aula.mp3';
const TEST_MP4 = '/Users/gabrielmaia/Documents/hellen-ai/tmp/Simulação de Aula.mp4';

// Demo credentials from seeds.exs
const DEMO_EMAIL = 'demo@hellen.ai';
const DEMO_PASSWORD = 'demo123456';

test.describe('Upload de Aula', () => {

  test('complete upload flow with login', async ({ page }) => {
    console.log('\n=== Starting upload test ===\n');

    // 1. Go to login page
    await page.goto('/login');
    await page.waitForLoadState('networkidle');
    console.log('1. Login page loaded');
    await page.screenshot({ path: 'e2e/screenshots/01-login-page.png', fullPage: true });

    // 2. Fill login form
    await page.fill('input[name="email"]', DEMO_EMAIL);
    await page.fill('input[name="password"]', DEMO_PASSWORD);
    console.log('2. Credentials filled');
    await page.screenshot({ path: 'e2e/screenshots/02-credentials-filled.png', fullPage: true });

    // 3. Submit login
    await page.click('button:has-text("Entrar")');
    console.log('3. Login submitted');

    // Wait for navigation
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(2000);

    const urlAfterLogin = page.url();
    console.log('4. URL after login:', urlAfterLogin);
    await page.screenshot({ path: 'e2e/screenshots/03-after-login.png', fullPage: true });

    // Check if login was successful
    if (urlAfterLogin.includes('/login')) {
      console.log('ERROR: Still on login page - checking for errors');
      const errorText = await page.locator('.alert-error, .error, [role="alert"]').textContent().catch(() => 'No error found');
      console.log('Error message:', errorText);
      await page.screenshot({ path: 'e2e/screenshots/03a-login-error.png', fullPage: true });
    }

    // 5. Navigate to new lesson page
    await page.goto('/lessons/new');
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(1000);

    const urlLessonsNew = page.url();
    console.log('5. URL after /lessons/new:', urlLessonsNew);
    await page.screenshot({ path: 'e2e/screenshots/04-lessons-new.png', fullPage: true });

    if (urlLessonsNew.includes('/login')) {
      console.log('ERROR: Redirected to login - session not maintained');
      return;
    }

    if (urlLessonsNew.includes('/onboarding')) {
      console.log('INFO: Redirected to onboarding - completing...');
      await page.screenshot({ path: 'e2e/screenshots/04a-onboarding.png', fullPage: true });

      // Try to complete onboarding if possible
      const continueBtn = page.locator('button:has-text("Continuar"), button:has-text("Pular")');
      if (await continueBtn.count() > 0) {
        await continueBtn.first().click();
        await page.waitForLoadState('networkidle');
      }

      // Try again
      await page.goto('/lessons/new');
      await page.waitForLoadState('networkidle');
    }

    // 6. Check upload page structure
    console.log('\n=== Checking upload page structure ===\n');

    // Find file input
    const fileInputs = await page.locator('input[type="file"]').all();
    console.log('File inputs found:', fileInputs.length);

    // Check for upload area
    const uploadArea = page.locator('[phx-drop-target], .upload-container, #upload-drop-zone');
    const uploadAreaCount = await uploadArea.count();
    console.log('Upload drop areas found:', uploadAreaCount);

    // Get all buttons
    const allButtons = await page.locator('button').all();
    console.log('\nButtons on page:');
    for (const btn of allButtons) {
      const text = (await btn.textContent())?.trim() || '';
      const disabled = await btn.isDisabled();
      console.log(`  - "${text}" (disabled: ${disabled})`);
    }

    // 7. Attempt file upload
    console.log('\n=== Attempting file upload ===\n');

    // Check if test file exists
    if (!fs.existsSync(TEST_MP3)) {
      console.log('ERROR: Test file not found:', TEST_MP3);
      return;
    }
    console.log('Test file exists:', TEST_MP3);
    const fileStats = fs.statSync(TEST_MP3);
    console.log('File size:', (fileStats.size / 1024 / 1024).toFixed(2), 'MB');

    // Find the file input (Phoenix LiveView file input)
    const fileInput = page.locator('input[type="file"]').first();
    if (await fileInput.count() === 0) {
      console.log('ERROR: No file input found');
      await page.screenshot({ path: 'e2e/screenshots/05-no-file-input.png', fullPage: true });
      return;
    }

    // Set file on input
    await fileInput.setInputFiles(TEST_MP3);
    console.log('File input set');

    // Wait for LiveView to process
    await page.waitForTimeout(3000);
    await page.screenshot({ path: 'e2e/screenshots/05-after-file-select.png', fullPage: true });

    // 8. Check if file appears in UI
    console.log('\n=== Checking file selection result ===\n');

    // Look for file name in page
    const pageContent = await page.content();
    const hasFileName = pageContent.includes('Simulação de Aula') || pageContent.includes('Simulacao de Aula');
    console.log('File name found in page:', hasFileName);

    // Check for upload entry display
    const entryDisplay = page.locator('text=Simulação de Aula, text=.mp3');
    const entryCount = await entryDisplay.count();
    console.log('Entry displays found:', entryCount);

    // Check submit button again
    const submitBtn = page.locator('button[type="submit"]');
    if (await submitBtn.count() > 0) {
      const isDisabled = await submitBtn.first().isDisabled();
      const btnText = await submitBtn.first().textContent();
      console.log(`Submit button: "${btnText?.trim()}" (disabled: ${isDisabled})`);

      if (isDisabled) {
        console.log('\nWARNING: Submit button is DISABLED after file selection!');
        console.log('This is the BUG - button should be enabled');
      } else {
        console.log('\nSUCCESS: Submit button is ENABLED');
      }
    }

    // 9. Check for errors
    const errors = await page.locator('.error, [role="alert"], .alert-error').all();
    if (errors.length > 0) {
      console.log('\nErrors found:');
      for (const err of errors) {
        const text = await err.textContent();
        console.log('  -', text?.trim());
      }
    }

    // Final screenshot
    await page.screenshot({ path: 'e2e/screenshots/06-final-state.png', fullPage: true });

    console.log('\n=== Test completed ===\n');
  });
});
