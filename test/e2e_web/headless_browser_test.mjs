import http from 'http';
import { execFile } from 'child_process';
import { promisify } from 'util';
import fs from 'fs';
import path from 'path';

const execFileAsync = promisify(execFile);

// Candidate browser executables on Windows
const BROWSER_PATHS = [
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
];

function getBrowserPath() {
  for (const p of BROWSER_PATHS) {
    if (fs.existsSync(p)) {
      return p;
    }
  }
  throw new Error('No compatible headless browser (Chrome or Edge) found!');
}

function renderOauthPage(success, message) {
  return `<!doctype html>
<html>
<head><meta charset="utf-8"><title>Luxwap</title></head>
<body style="font-family:Arial,sans-serif;background:#f3f6fb;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;">
  <div style="background:#fff;border-radius:16px;padding:32px 42px;box-shadow:0 12px 36px rgba(0,0,0,.12);text-align:center;">
    <h2 style="margin:0 0 12px;color:${success ? '#238b45' : '#c62828'};">${success ? '授权成功' : '授权失败'}</h2>
    <p style="margin:0;color:#333;">${message}</p>
  </div>
</body>
</html>`;
}

async function runHeadlessBrowserTest() {
  console.log('========================================================');
  console.log('🚀 Starting Real Headless Browser End-to-End Test Suite');
  console.log('========================================================');

  const browserExe = getBrowserPath();
  console.log(`[1/4] Detected Headless Browser: ${browserExe}`);

  // Start local OAuth callback test server
  const server = http.createServer((req, res) => {
    const url = new URL(req.url, `http://${req.headers.host}`);
    const code = url.searchParams.get('code');
    const state = url.searchParams.get('state');

    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    if (code && state) {
      res.end(renderOauthPage(true, '授权完成，请返回 Luxwap'));
    } else {
      res.end(renderOauthPage(false, '授权回调缺少 code 或 state'));
    }
  });

  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const port = server.address().port;
  console.log(`[2/4] Mock OAuth Server listening on http://127.0.0.1:${port}`);

  try {
    // Test Case 1: Successful OAuth Authorization Flow in Real Headless Browser
    console.log('\n[3/4] Testing: Successful OAuth Callback Flow (with code & state)...');
    const targetSuccessUrl = `http://127.0.0.1:${port}/callback?code=mock_oauth_code_xyz123&state=state_abc456`;
    
    const { stdout: domSuccess } = await execFileAsync(browserExe, [
      '--headless',
      '--disable-gpu',
      '--no-sandbox',
      '--dump-dom',
      targetSuccessUrl,
    ]);

    if (!domSuccess.includes('授权成功') || !domSuccess.includes('授权完成，请返回 Luxwap')) {
      throw new Error(`Test Case 1 FAILED: Rendered DOM did not match success state!\nDOM Output:\n${domSuccess}`);
    }
    if (!domSuccess.includes('<title>Luxwap</title>')) {
      throw new Error('Test Case 1 FAILED: Title is not Luxwap!');
    }
    console.log('  ✅ Real Headless Browser successfully verified: Page Title="Luxwap", <h2>="授权成功"');

    // Test Case 2: Failure OAuth Callback Flow (missing code)
    console.log('\n[4/4] Testing: Failed OAuth Callback Flow (missing authorization code)...');
    const targetFailUrl = `http://127.0.0.1:${port}/callback`;

    const { stdout: domFail } = await execFileAsync(browserExe, [
      '--headless',
      '--disable-gpu',
      '--no-sandbox',
      '--dump-dom',
      targetFailUrl,
    ]);

    if (!domFail.includes('授权失败') || !domFail.includes('授权回调缺少 code 或 state')) {
      throw new Error(`Test Case 2 FAILED: Rendered DOM did not match failure state!\nDOM Output:\n${domFail}`);
    }
    console.log('  ✅ Real Headless Browser successfully verified: <h2>="授权失败" with error notice');

    console.log('\n🎉 ALL REAL HEADLESS BROWSER E2E TESTS PASSED SUCCESSFULLY!');
  } finally {
    server.close();
  }
}

runHeadlessBrowserTest().catch((err) => {
  console.error('❌ Headless Browser Test Error:', err);
  process.exit(1);
});
