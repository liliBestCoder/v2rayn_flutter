import http from 'http';
import net from 'net';
import { spawn } from 'child_process';
import fs from 'fs';
import path from 'path';

const API_BASE = 'http://101.201.215.20:8000';
const USERNAME = 'lilibestcoder@163.com';
const PASSWORD = '123456';
const PROXY_PORT = 10899;
const XRAY_PATH = path.resolve('windows/runner/resources/bin/xray/xray.exe');

async function httpRequest(urlPath, method = 'GET', headers = {}, body = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(API_BASE + urlPath);
    const req = http.request({
      hostname: url.hostname,
      port: url.port || 80,
      path: url.pathname + url.search,
      method,
      headers: {
        ...headers,
        ...(body ? { 'Content-Length': Buffer.byteLength(body) } : {})
      }
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body: data }));
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

function waitPort(port, timeoutMs = 6000) {
  return new Promise((resolve) => {
    const start = Date.now();
    const tryConnect = () => {
      const socket = net.createConnection({ host: '127.0.0.1', port }, () => {
        socket.destroy();
        resolve(true);
      });
      socket.on('error', () => {
        socket.destroy();
        if (Date.now() - start > timeoutMs) {
          resolve(false);
        } else {
          setTimeout(tryConnect, 150);
        }
      });
    };
    tryConnect();
  });
}

function buildXrayConfig(rawNodeUri, uuid) {
  const uriStr = rawNodeUri.replace('${uuid}', uuid);
  const parsed = new URL(uriStr);

  const query = parsed.searchParams;
  const user = {
    id: parsed.username || uuid,
    encryption: query.get('encryption') || 'none',
    level: 0
  };
  if (query.get('flow')) {
    user.flow = query.get('flow');
  }

  const realitySettings = {
    show: false,
    fingerprint: query.get('fp') || 'chrome',
    serverName: query.get('sni') || '',
    publicKey: query.get('pbk') || '',
    shortId: query.get('sid') || '',
    spiderX: query.get('spx') || ''
  };

  return {
    log: { loglevel: 'warning' },
    dns: {
      servers: ['8.8.8.8', '1.1.1.1', 'localhost']
    },
    inbounds: [
      {
        tag: 'mixed-in',
        listen: '127.0.0.1',
        port: PROXY_PORT,
        protocol: 'mixed'
      }
    ],
    outbounds: [
      {
        tag: 'proxy',
        protocol: 'vless',
        settings: {
          vnext: [
            {
              address: parsed.hostname,
              port: parseInt(parsed.port || '443', 10),
              users: [user]
            }
          ]
        },
        streamSettings: {
          network: query.get('type') || 'tcp',
          security: query.get('security') || 'reality',
          realitySettings: realitySettings
        }
      },
      { tag: 'direct', protocol: 'freedom' },
      { tag: 'block', protocol: 'blackhole' }
    ],
    routing: {
      domainStrategy: 'IPIfNonMatch',
      rules: [
        {
          type: 'field',
          domain: ['geosite:category-ads-all'],
          outboundTag: 'block'
        }
      ]
    }
  };
}

function runCurlProbe(proxyType, proxyPort, targetUrl, timeoutSec = 8) {
  return new Promise((resolve) => {
    const proxyArg = proxyType === 'http'
      ? `http://127.0.0.1:${proxyPort}`
      : `socks5h://127.0.0.1:${proxyPort}`;

    const args = [
      '-x', proxyArg,
      targetUrl,
      '-o', 'NUL',
      '-s',
      '-w', 'http_code=%{http_code}\ntime_total=%{time_total}\nssl_verify=%{ssl_verify_result}\n',
      '--max-time', timeoutSec.toString()
    ];

    const startTime = Date.now();
    const proc = spawn('curl.exe', args);
    let output = '';
    let errorOutput = '';

    proc.stdout.on('data', d => output += d.toString());
    proc.stderr.on('data', d => errorOutput += d.toString());

    proc.on('close', (exitCode) => {
      const durationMs = Date.now() - startTime;
      const matchCode = output.match(/http_code=(\d+)/);
      const matchTime = output.match(/time_total=([0-9.]+)/);
      const httpCode = matchCode ? parseInt(matchCode[1], 10) : 0;
      const timeTotal = matchTime ? parseFloat(matchTime[1]) : (durationMs / 1000);

      resolve({
        proxyType,
        targetUrl,
        exitCode,
        httpCode,
        timeTotal,
        success: exitCode === 0 && httpCode > 0,
        error: exitCode !== 0 ? `curl exit code ${exitCode} (${errorOutput.trim() || 'Connection failed/Reset'})` : null
      });
    });
  });
}

async function runSuite() {
  console.log('================================================================');
  console.log('🧪 端到端测试：中台节点提取 -> 构造 Xray 配置 -> 启动代理端点');
  console.log(`   代理端点: 127.0.0.1:${PROXY_PORT} (HTTP/SOCKS 协议)`);
  console.log('   测试目标: Google, YouTube, ChatGPT');
  console.log('================================================================\n');

  // 1. 登录中台获取 Token
  console.log('[步骤 1/4] 🔑 登录中台账号 (lilibestcoder@163.com)...');
  const loginBody = new URLSearchParams({
    username: USERNAME,
    password: PASSWORD,
    deviceId: 'test-runner-pc',
    os: 'windows',
    deviceType: 'PC',
    deviceName: 'test-runner'
  }).toString();

  const loginRes = await httpRequest('/api/client/login', 'POST', {
    'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8'
  }, loginBody);

  const loginJson = JSON.parse(loginRes.body);
  if (loginJson.code !== 0 || !loginJson.data) {
    throw new Error(`登录中台失败: ${loginRes.body}`);
  }
  const token = loginJson.data;
  console.log('  ✅ 登录成功，获取 Session Token.');

  // 2. 获取用户资料与中台节点
  console.log('\n[步骤 2/4] 📡 获取用户 UUID 与中台线路节点...');
  const userRes = await httpRequest('/api/client/user-info', 'GET', { token });
  const userJson = JSON.parse(userRes.body);
  const uuid = userJson.data?.uuid;
  console.log(`  用户 UUID: ${uuid}`);

  const lineRes = await httpRequest('/api/client/line-list', 'GET', { token });
  const lineJson = JSON.parse(lineRes.body);
  const lines = lineJson.data || [];
  if (lines.length === 0) {
    throw new Error('中台返回的线路列表为空！');
  }
  const rawNode = lines[0];
  console.log(`  ✅ 成功获取中台节点: ${rawNode.slice(0, 80)}...`);

  // 3. 构造 Xray 配置并启动 10899 代理端点
  console.log(`\n[步骤 3/4] ⚙️ 根据当前节点构造 Xray 配置并启动 127.0.0.1:${PROXY_PORT}...`);
  const xrayConfig = buildXrayConfig(rawNode, uuid);
  fs.writeFileSync('test/e2e_proxy/generated_xray_config.json', JSON.stringify(xrayConfig, null, 2));
  console.log('  ✅ 成功生成 Xray 配置文件 test/e2e_proxy/generated_xray_config.json');

  const xrayProc = spawn(XRAY_PATH, ['run', '-c', 'stdin:'], {
    cwd: path.dirname(XRAY_PATH),
    env: {
      ...process.env,
      'XRAY_LOCATION_ASSET': path.dirname(XRAY_PATH)
    }
  });

  xrayProc.stdin.write(JSON.stringify(xrayConfig));
  xrayProc.stdin.end();

  const isReady = await waitPort(PROXY_PORT, 6000);
  if (!isReady) {
    xrayProc.kill();
    throw new Error(`代理端点 127.0.0.1:${PROXY_PORT} 启动失败，端口未在规定时间内开启！`);
  }
  console.log(`  ✅ 代理端点已在 127.0.0.1:${PROXY_PORT} 正常就绪并监听！`);

  // 4. 执行测试用例：访问 Google, YouTube, ChatGPT
  console.log('\n[步骤 4/4] 🎯 执行测试用例 (走 HTTP / SOCKS 协议测试访问)...');

  const testTargets = [
    { name: 'Google', url: 'https://www.google.com' },
    { name: 'YouTube', url: 'https://www.youtube.com' },
    { name: 'ChatGPT', url: 'https://chatgpt.com' }
  ];

  const results = {
    timestamp: new Date().toISOString(),
    node: rawNode.slice(0, 80),
    uuid,
    proxyPort: PROXY_PORT,
    cases: []
  };

  // HTTP 协议代理测试
  console.log('\n  --- 走 HTTP 代理协议 (127.0.0.1:10899) ---');
  for (const target of testTargets) {
    process.stdout.write(`  [测试用例: HTTP -> ${target.name}] 发起请求... `);
    const res = await runCurlProbe('http', PROXY_PORT, target.url);
    results.cases.push({ ...res, targetName: target.name });
    if (res.success) {
      console.log(`🟢 通过 (HTTP ${res.httpCode}, 耗时: ${res.timeTotal}s)`);
    } else {
      console.log(`🔴 失败 (${res.error}, 耗时: ${res.timeTotal}s)`);
    }
  }

  // SOCKS5 协议代理测试
  console.log('\n  --- 走 SOCKS5 协议代理 (127.0.0.1:10899) ---');
  for (const target of testTargets) {
    process.stdout.write(`  [测试用例: SOCKS5 -> ${target.name}] 发起请求... `);
    const res = await runCurlProbe('socks5', PROXY_PORT, target.url);
    results.cases.push({ ...res, targetName: target.name });
    if (res.success) {
      console.log(`🟢 通过 (HTTP ${res.httpCode}, 耗时: ${res.timeTotal}s)`);
    } else {
      console.log(`🔴 失败 (${res.error}, 耗时: ${res.timeTotal}s)`);
    }
  }

  // 释放代理进程
  xrayProc.kill();
  await new Promise(r => setTimeout(r, 600));

  console.log('\n================================================================');
  console.log('📋 测试结果统计表:');
  console.log('================================================================');
  console.table(results.cases.map(c => ({
    '目标网站': c.targetName,
    '代理协议': c.proxyType.toUpperCase(),
    '代理端口': PROXY_PORT,
    'HTTP响应码': c.httpCode || 'N/A',
    '耗时(秒)': c.timeTotal.toFixed(2),
    '测试结论': c.success ? 'PASSED ✅' : 'FAILED ❌',
    '错误/原因': c.error || '无'
  })));

  fs.writeFileSync('test/e2e_proxy/real_test_result.json', JSON.stringify(results, null, 2));
}

runSuite().catch(err => {
  console.error('\n❌ 测试流程异常终止:', err);
  process.exit(1);
});
