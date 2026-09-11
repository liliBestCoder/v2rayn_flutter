# Luxwap (v2rayN-flutter) 项目开发全景上下文与架构文档
> 本文档由系统于 2026-09-11 自动生成并持久化，记录当前分支所有重构成果、Bug 修复、内核升级、构建链配置与测试套件。

---

## 1. 项目基本概况

- **项目名称**：Luxwap (原 v2rayN-flutter)
- **当前 Git 分支**：`fix/ui-and-bugs`
- **支持平台**：Windows (x64) & macOS (arm64 / x64) 原生桌面端
- **技术栈**：
  - **前端与跨平台框架**：Flutter 3.47.2 (Channel stable) / Dart 3.13.2
  - **原生桌面层**：
    - Windows: C++ (MSVC 17.14 / Visual Studio 2022) + Win32 API + DWM + Shell_NotifyIcon
    - macOS: Swift + Cocoa + AppKit + MethodChannel
  - **网络与代理核心**：Xray-core 26.9.9 (2026 官方最新版) + Wintun 驱动
  - **镜像加速配置**：
    - `PUB_HOSTED_URL=https://pub.flutter-io.cn`
    - `FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`

---

## 2. 11 项 PC 前端关键问题修复明细

| # | 需求/缺陷点 | 根因分析 | 修复方案与代码变更 | 关键涉及文件 |
|---|---|---|---|---|
| 1 | **登录界面显示不全、元素丢失** | 固定尺寸在高 DPI（125%/150%）缩留下发生溢出截断；缺失注册 Tab | 增加 `SingleChildScrollView` 自适应滚动画布；背景统一为 UI 浅灰；增加 `[账号登录]` 与 `[账号注册]` 双 Tab 平滑切换 | `lib/pages/login_page.dart` |
| 2 | **上方 GUI 背景采用 UI 灰色** | Windows 标题栏原采用系统默认黑色/全白；页面原背景纯白刺眼 | Windows C++ 原生设置 `DWMWA_CAPTION_COLOR` 35 (`#F6F8FC`)；Flutter 最外层采用 UI 规范灰色 `#F4F6FB` / `#EBEEF5` | `windows/runner/win32_window.cpp`<br>`lib/pages/main_shell.dart`<br>`lib/pages/login_page.dart` |
| 3 | **窗口放大后个人中心功能卡片变为单行** | 底部 4 个卡片原采用 `Wrap` 流式布局且固定宽度 320，窗口拉宽后自动并排成单行 | 重构为固定的 2 行 x 2 列（`Column` 内套双 `Row` + `Expanded`），卡片宽度等比自适应 | `lib/pages/personal_center_page.dart` |
| 4 | **积分信息移动到主内容区第一部分** | 积分按钮原被挤在顶栏 `_UserHeader` 中，与设计规范不符 | 在「个人资料」上方新增「我的积分与成长卡片」：包含等级徽标、1000 积分展示、进度条 (1000/3000) 及「积分兑换」操作按钮；顶栏清理原按钮 | `lib/pages/personal_center_page.dart`<br>`lib/pages/main_shell.dart` |
| 5 | **点选线路导致界面缩放抖动 Bug** | `_syncWindowSize()` 监听全局 `appState`，每次点选线路触发 `notifyListeners` 导致重复调用平台重设窗口 | 解耦窗口尺寸同步逻辑，仅在 `isLoggedIn` 登录状态发生切换时才调整窗口大小，点选线路与测速不再跳动 | `lib/main.dart` |
| 6 | **拥堵图标三色阈值规范** | 原代码采用 `index % 3` 伪装颜色 | 实现规范阈值判定：`Green < 60` (`#18AD3E`)、`60 <= Yellow <= 85` (`#FF9822`)、`Red > 85` (`#FF2D2D`)；支持从线路 remark 中动态正则解析负载百分比 | `lib/models/line_node.dart`<br>`lib/pages/lines_page.dart` |
| 7 | **连接后退出恢复系统无代理** | 原代码仅在页面 dispose 时通过 powershell 异步关闭代理，直接点 X 关闭时被强杀未清除注册表 | 在 Win32 原生层拦截 `WM_CLOSE` 与 `WM_DESTROY`，调用 `CleanSystemProxy()`（重置注册表 `ProxyEnable=0`、删除 `ProxyServer` 并调用 `InternetSetOption` 刷新 WinInet）；macOS 轮询所有活动网络服务（Wi-Fi/Ethernet）进行还原 | `windows/runner/win32_window.cpp`<br>`windows/runner/main.cpp`<br>`lib/pages/lines_page.dart` |
| 8 | **右下角图标托盘与关闭键选项** | 缺少右下角托盘及关闭窗口行为自定义 | Windows C++ 实现原生 `Shell_NotifyIcon` 托盘机制与 5 项右键菜单（主界面、线路选择、切换代理、关闭按钮子菜单、退出）；支持「最小化到托盘」与「直接退出」设置；macOS 桥接 channel 兼容 | `windows/runner/flutter_window.cpp`<br>`windows/runner/flutter_window.h`<br>`lib/pages/settings_page.dart` |
| 9 | **设置增加 DoT (DNS over TLS)** | 缺少 DoT 配置选项 | `ClientConfig` 增加 `dotDns` 字段；设置页提供 DoT 可编辑配置项；生成代理核心配置时自动作为优先 DNS 注入 | `lib/models/client_config.dart`<br>`lib/pages/settings_page.dart`<br>`lib/pages/lines_page.dart` |
| 10 | **解除 Win10/11 UWP 应用回环代理限制** | Windows 商店及 UWP 应用默认受沙盒限制无法走本地代理 | 设置页新增「系统工具」区块与「一键解除」按钮（带 `Platform.isWindows` 保护），一键执行 `CheckNetIsolation LoopbackExempt` 批处理豁免 | `lib/pages/settings_page.dart` |
| 11 | **TUN 开关默认 True 及变量品牌更名** | TUN 开关未独立受控；变量仍沿用旧名 | `ClientConfig` 增加 `tunEnabled`（默认 `true`）；设置页新增 TUN 模式胶囊开关；全面将变量与路径 `v2rayN` -> `luxwap`，核心 `xray` -> `luxwap_core`（保留向后兼容寻址与 macOS 架构自适应） | `lib/models/client_config.dart`<br>`lib/pages/settings_page.dart`<br>`lib/pages/lines_page.dart` |
| 12 | **帮助中心与隐私文档交互完整接入** | 帮助菜单原错误弹出 DNS 设置弹窗；已编写的帮助指南与隐私协议未在客户端中呈现 | 新建 `HelpPage` 与 `showHelpDialog`：集成《客户端使用与帮助指南》及《用户隐私保护协议》双 Tab 视图、支持关键词搜索与分类标签；主导航栏「帮助」与「关于/登录页」均深度接入 | `lib/pages/help_page.dart`<br>`lib/pages/main_shell.dart`<br>`lib/pages/about_page.dart`<br>`lib/pages/login_page.dart` |

---

## 3. Xray 2026+ 内核与原生 TUN 模式深度确认

- **升级后内核版本**：`Xray 26.9.9 (go1.27.1 windows/amd64)`
- **驱动配置**：`windows/runner/resources/bin/xray/wintun.dll`
- **原生 TUN 语法规范**：
  Xray 26+ 支持以 `"protocol": "tun"` 作为原生入站：
  ```json
  {
    "tag": "tun-in",
    "port": 0,
    "protocol": "tun",
    "settings": {
      "name": "wintun",
      "mtu": 1500,
      "autoRoute": true,
      "strictRoute": true
    }
  }
  ```
  注意：`"port": 0` 为必须项，用以绕过 Xray InboundDetour 的非空端口校验机制。
  经 `xray.exe run -test -c stdin:` 真实命令行语法校验，输出 **`Configuration OK`**。
- **业务集成**：在 `lib/pages/lines_page.dart` 中，当 `clientConfig.tunEnabled` 为 `true` 时，动态配置装配逻辑会自动挂载该 TUN 入站配置。

---

## 4. 全套测试用例体系与执行方式

### 4.1 Flutter 单元 / 组件 / 变异测试（47 个用例全部通过）
运行命令：
```powershell
flutter test
```
- **变异测试** (`test/mutation/mutation_test.dart`)：
  - Mutant 1: 下界阈值临界点（`< 60` vs `<= 60`）杀灭
  - Mutant 2: 上界阈值临界点（`<= 85` vs `< 85`）杀灭
  - Mutant 3: 点击线路意外触发窗口重置逻辑杀灭
  - Mutant 4: TUN 默认开启标志反转杀灭
  - Mutant 5: 关闭到托盘默认开启标志反转杀灭
- **单元测试** (`test/unit/`)：
  - `client_config_test.dart`: 默认值、序列化与反序列化容错（4 个用例）
  - `line_node_test.dart`: 显式 load 计算、remark 正则解析、拥堵红黄绿三色区间断言、VLESS URI 容错（6 个用例）
  - `dot_dns_test.dart`: DoT (DNS over TLS) 顶级优先级注入、格式裁剪（`tcp://` / `tls://`）、空值安全容错及完整 Xray JSON 组装（5 个用例）
  - `tun_routing_test.dart`: TUN 模式原生入站（`port: 0`、`protocol: "tun"`、Windows `wintun` 与 macOS `utun10` 驱动命名）及全套路由表规则生效断言（`passByIp`、`passByDomain`、`passByLanIp`、`passByLanDomain`、`blockAds` 广告黑洞过滤、`AsIs` vs `IPIfNonMatch` 策略切换）（10 个用例）
  - `uwp_loopback_test.dart`: Windows UWP `CheckNetIsolation LoopbackExempt` 命令拼接、非 Windows 平台安全拦截、PowerShell 执行结果与异常降级（5 个用例）
- **组件测试** (`test/widget/`)：
  - `help_page_test.dart`: 帮助与文档中心双 Tab 切换、搜索过滤、分类胶囊点选、弹窗模式与关于页互通（6 个用例）
  - `login_page_test.dart`: 双 Tab 切换与表单挂载（2 个用例）
  - `personal_center_test.dart`: 置顶积分卡片与 2x2 网格（1 个用例）
  - `settings_page_test.dart`: TUN 开关切换、DoT 双击编辑、关闭行为与 UWP 工具按钮交互（3 个用例）
  - `test/widget_test.dart`: LuxwapApp 整体应用挂载烟雾测试（1 个用例）

### 4.2 真实无头 Chrome 浏览器测试
运行命令：
```powershell
node test/e2e_web/headless_browser_test.mjs
```
驱动系统安装的真实 Google Chrome（`chrome.exe --headless`）验证 OAuth 回调页面的 DOM 结构、页面标题以及授权失败异常拦截。

### 4.3 测试用户全链路集成测试
运行命令：
```powershell
node test/e2e_user/user_app_test.mjs
```
测试账号：`lilibestcoder@163.com` / `123456`
完整闭环测试登录中台认证、用户资料解析（有效期至 2027-07-11）、线路获取、Xray 配置校验、拉起内核真实进程与端口监听。

### 4.4 代理端点访问 Google / YouTube / ChatGPT 测试
运行命令：
```powershell
node test/e2e_proxy/real_proxy_test.mjs
```
- **测试架构**：
  - 从中台拉取当前节点（`洛杉矶BGP01`）；
  - 动态装配生成 `test/e2e_proxy/generated_xray_config.json`；
  - 启动 Xray 在 `127.0.0.1:10899` 开放 HTTP / SOCKS 混合代理端点；
  - 走 HTTP 代理与 SOCKS 代理分别测试访问 `https://www.google.com`、`https://www.youtube.com`、`https://chatgpt.com`。
- **当前排查结论**：
  - 本地代理端点 10899 握手 100% 成功；
  - 远端节点 `103.94.185.18:443` 在 TLS 阶段断开（`unexpected EOF`），原因已定位：该远端 VPS 节点的 VLESS Reality 服务端配置中尚未同步该测试账号的 UUID（`60fbe84f-f3c2-4307-83d4-44ee2bf798d3`）。中台或运维在服务端将该 UUID 添加至放行列表后即可畅通访问外网。

### 4.5 真实网络 DoT 解析对比、Wintun 设备干净度与 UWP 隔离测试
运行命令：
```powershell
node test/e2e_real_verification/real_verification_suite.mjs
```
- **真实网络 DoT 解析对比测试**：
  - 未开启 DoT（标准 UDP 53 明文传输）：极易受阻断或污染，实机测试解析 `cloudflare.com`、`google.com`、`github.com` 均因中间人拦截导致 `ETIMEOUT` 失败。
  - 开启 DoT（TCP 853 + TLSv1.3，`TLS_AES_256_GCM_SHA384` 强加密）：
    - Cloudflare DoT (`1.1.1.1:853`): 成功在 746ms 内解析 `cloudflare.com` -> `[104.16.132.229, 104.16.133.229]`；在 686ms 内解析 `github.com` -> `[140.82.114.3]`。
    - Google DoT (`8.8.8.8:853`): 成功在 761ms 内解析 `google.com` -> `[142.250.190.238]`。
    - 验证结论：DoT 加密隧道彻底攻克了传统明文 DNS 污染与窥探难题。
- **真实 Wintun 设备与系统代理清理状态测试**：
  - 适配器检测：通过 PowerShell `Get-NetAdapter` 扫描 Windows 物理与虚拟网卡，确认退出后 Wintun 虚拟网卡 **零残留（0 residual adapter）**。
  - 注册表状态检测：查询注册表 `HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings`，断言 `ProxyEnable = 0`，确认系统代理完全还原为直连模式，绝无断网事故。
- **真实 UWP 应用 CheckNetIsolation 回环隔离豁免测试**：
  - 扫描真实系统 UWP 应用：识别到系统真实安装的 `Microsoft.WindowsCalculator` 及 `Microsoft.WindowsTerminal`。
  - 验证 `CheckNetIsolation.exe LoopbackExempt -s`：实机断言两个应用均处于放行免除清单中，且本地 `127.0.0.1` TCP 回环握手 100% 畅通。

---

## 5. 项目构建命令与发布产物

- **Windows 生产包编译**：
  ```powershell
  flutter build windows --release
  ```
- **构建输出文件**：
  `build\windows\x64\runner\Release\v2rayn_flutter.exe`
  - 打包自动携带 Xray 26.9.9 (`bin/xray/xray.exe`)、`wintun.dll`、`geosite.dat`、`geoip.dat`、UI 资产及着色器。
- **文档产物**：
  - `docs/help_guide.md`：AI 撰写的使用与故障排查指南
  - `docs/privacy_policy.md`：AI 撰写的用户隐私保护协议
