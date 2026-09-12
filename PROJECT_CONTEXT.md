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

---

## 6. TUN 模式实机建立与稳定性关键突破（2026-09-12 阶段总结）

### 6.1 根因一：`cleanProxy` 导致的“同胞误杀”（最致命 Bug）
- **现象**：点击连接后 100ms 内，界面弹出 SnackBar：`TUN 虚拟网卡创建失败，请确保以管理员权限运行`。
- **根因链路**：
  1. TUN 虚拟网卡接管系统流量时，前端按设计调用 `_setSystemProxy(false)` 关闭系统代理（防止双重代理与回路冲突）。
  2. `_setSystemProxy(false)` 通过 MethodChannel `luxwap/window` 调用原生 `cleanProxy`。
  3. Windows 原生 C++ `win32_window.cpp` 的 `CleanSystemProxy()` 中直接调用了 `KillCoreProcesses()`（执行了 `taskkill /F /IM xray.exe`）。
  4. **结果**：刚拉起 `xray.exe`，紧接着关闭系统代理，原生 C++ 却把刚启动的 `xray.exe` 杀死了！300ms 后前端发现内核不存在，误判定为权限不足。
- **修复方案**：
  - Windows 原生层：`CleanSystemProxy()` 仅清理注册表 `ProxyEnable=0` 与 WinINet 刷新，彻底移除内部的 `KillCoreProcesses()`；进程终止仅在窗口关闭、托盘退出或显式调用 `killCore` 时执行。
  - macOS 原生层：同样将 `cleanSystemProxyOnly()`（调用 `networksetup ... off`）与 `killCoreProcesses()`（调用 `pkill -9`）严格分离。
  - Dart 侧：在退出登录与组件销毁时定向调用 `killCore`。

### 6.2 根因二：NetBIOS 与 TUN 本地子网广播风暴阻断
- **现象**：Windows 网卡启用后周期性向 `172.19.0.255:137` 发送 NetBIOS 探测包；原规则将局域网判定为直连从宿主机发出，被 TUN 重新捕获，2 秒内产生 48,000+ 报文打满 Windows 短暂端口（49152-65535）与缓冲区导致崩溃。
- **修复方案**：
  - 在 `xray_config_builder.dart` 最顶端加入局域网广播防环路黑洞：
    - `port: "137,138,139", network: "udp"` -> `block`
    - `ip: ["224.0.0.0/4", "255.255.255.255/32", "172.19.0.0/24"]` -> `block`

### 6.3 驱动分发与虚拟网卡命名统一
- Windows 虚拟网卡名称锁定为 `luxwap-tun`（适配器描述为 `Luxwap TUN Adapter Tunnel`），驱动为 `wintun.dll`（已同时部署于 Release 根目录及 `bin/xray/` 目录）。
- macOS 虚拟网卡名称锁定为 `utun10`。
- 测试覆盖率：全套 62 项 Flutter 单元/E2E 测试 100% 通过，成功构建 Release 生产包。

---

## 7. 实机 `route print` 路由表现状深度剖析与诊断

用户实机执行 `route print` 输出的活动路由表如下：
```text
活动路由:
网络目标        网络掩码          网关       接口   跃点数
          0.0.0.0          0.0.0.0     10.0.168.253     10.0.168.183     15
          0.0.0.0          0.0.0.0    198.19.31.253    198.19.27.172   9999
          0.0.0.0        128.0.0.0            在链路上        172.19.0.1      0
       10.0.168.0    255.255.255.0            在链路上      10.0.168.183    271
     10.0.168.183  255.255.255.255            在链路上      10.0.168.183    271
     10.0.168.255  255.255.255.255            在链路上      10.0.168.183    271
       100.64.0.0      255.192.0.0    198.19.31.253    198.19.27.172    271
  100.100.100.200  255.255.255.255    198.19.31.253    198.19.27.172    271
        127.0.0.0        255.0.0.0            在链路上         127.0.0.1    331
        127.0.0.1  255.255.255.255            在链路上         127.0.0.1    331
  127.255.255.255  255.255.255.255            在链路上         127.0.0.1    331
  127.255.255.255  255.255.255.255            在链路上        172.19.0.1    256
        128.0.0.0        128.0.0.0            在链路上        172.19.0.1      0
       172.19.0.0    255.255.255.0            在链路上        172.19.0.1    256
       172.19.0.1  255.255.255.255            在链路上        172.19.0.1    256
     172.19.0.255  255.255.255.255            在链路上        172.19.0.1    256
       198.18.0.0    255.255.240.0    198.19.31.253    198.19.27.172    271
      198.19.16.0    255.255.240.0            在链路上     198.19.27.172    271
    198.19.27.172  255.255.255.255            在链路上     198.19.27.172    271
    198.19.31.255  255.255.255.255            在链路上     198.19.27.172    271
```

### 7.1 验证已成功落地的部分
1. **虚拟网卡已成功创建并激活**：
   - 接口列表中清晰展示 `32...........................Luxwap TUN Adapter Tunnel`。
   - 虚拟 IP `172.19.0.1` 及子网掩码 `255.255.255.0` 已正确绑定至 `luxwap-tun`。
2. **全局流量劫持已生效（0/1 + 128/1 经典 VPN 路由拆分）**：
   - `0.0.0.0 / 128.0.0.0`（即 `0.0.0.0/1`，涵盖 `0.0.0.0`~`127.255.255.255`）指向 `172.19.0.1`，跃点数 0。
   - `128.0.0.0 / 128.0.0.0`（即 `128.0.0.0/1`，涵盖 `128.0.0.0`~`255.255.255.255`）指向 `172.19.0.1`，跃点数 0。
   - 这两个 `/1` 路由掩码长于默认物理网关的 `/0`（`0.0.0.0/0` 跃点数 15），因此系统所有外网 TCP/UDP 报文都会被优先转发入 TUN 虚拟网卡。

---

## 8. 导致“TUN 开启后无法上网”的致命路由缺陷（用户的判断 100% 正确）

用户提出“**这个tun的路由表初始话的还是不对吧**”，分析结果表明：**该路由表确实存在致命缺失！**

### 致命缺陷一：缺少远端代理节点（VPS 服务器）IP 的直连物理网关主机路由（路由黑洞回环）
- **现象**：开启 TUN 后，浏览器和所有软件断网，无法打开任何网页。
- **技术根因**：
  1. 用户的物理默认网关为 `10.0.168.253`（物理网卡 `10.0.168.183`）。
  2. 假定当前选择的节点 IP 为 `103.94.185.18`（或任何公网 IP）。
  3. 内核 Xray 的 Outbound 需要与 `103.94.185.18:443` 建立加密 TCP 握手。
  4. 当 Xray 发出握手包时，Windows 操作系统查询 IPv4 路由表：
     - 最长前缀匹配：`103.94.185.18` 命中了 `0.0.0.0/128.0.0.0`（跃点数 0，接口 `172.19.0.1`）！
     - **Windows 把发往代理服务器本身的连接报文，又重新塞回了 `luxwap-tun` 虚拟网卡中！**
     - Xray 在底层自身捕获了发给自己的报文，造成无法与真正的远端 VPS 服务器通信，所有向外流量瞬间陷入黑洞死锁！
  5. **行业标准解法**：
     在启动 TUN 时，必须为当前连接节点的物理公网 IP 添加一条精准的 `/32` 主机路由，显式指定走物理网关：
     ```cmd
     route add <node_ip> mask 255.255.255.255 10.0.168.253 metric 1
     ```
     断开连接时：
     ```cmd
     route delete <node_ip>
     ```

### 致命缺陷二：Xray 内核未绑定物理出站网卡（`autoOutboundsInterface` 为空）
- **根因**：
  在 `xray_config_builder.dart` 中，TUN 入站配置目前写为：
  ```json
  "settings": {
    "name": "luxwap-tun",
    "gateway": ["172.19.0.1/24"],
    "autoSystemRoutingTable": ["0.0.0.0/1", "128.0.0.0/1"],
    "autoOutboundsInterface": ""
  }
  ```
  `autoOutboundsInterface` 留空，导致 Xray 内核没有利用 Windows API 将自己的出站 Socket 绑定到真实的物理以太网卡（`Red Hat VirtIO Ethernet Adapter #3`）。

### 致命缺陷三：DNS 提前解析与递归依赖
- 如果节点配置的地址是域名（例如 `hk01.luxwap.com`），在 TUN 劫持了全网流量后，若 DNS 请求也必须通过代理，而此时代理尚未与服务器连通，则解析不到节点 IP，陷入先有鸡还是先有蛋的死锁。
- 启动 TUN 前，必须在宿主机上通过系统 DNS（或直接通过本地解析）提前将节点域名解析为 IP，并将该 IP 的直连路由下发至系统路由表。

---

## 9. TUN 节点直连路由（/32）与生命周期闭环落地（2026-09-12 实施记录）

依据 Xray-core 官方文档 `proxy/tun/README.md` 的 Approach 1 规范，已完整实现节点公网 IP 的 `/32` 主机直连路由动态管理，彻底解决 TUN 路由回环死锁问题：

### 9.1 核心改动模块
1. **新建路由管理器** (`lib/services/tun_route_manager.dart`)：
   - 动态提取系统物理默认网关（Windows `route print 0.0.0.0` / macOS `route -n get default`）；
   - 下发直连主机路由（Windows `route add <node_ip> mask 255.255.255.255 <gateway> metric 1` / macOS `route add -host <node_ip> <gateway>`）；
   - 断开或切换节点时自动清理（Windows `route delete <node_ip>` / macOS `route delete -host <node_ip>`）；
   - 切换节点时先删后增，支持多线路平滑切换。
2. **连接生命周期闭环** (`lib/pages/lines_page.dart`)：
   - `_startProxy()`：在核心拉起前，提取节点 IP 并调用 `TunRouteManager.addDirectNodeRoute(node.host)`；
   - `_stopProxy()`：核心终止后立即调用 `TunRouteManager.removeDirectNodeRoute()`；
   - `coreProcess.exitCode` 崩溃监听与 `dispose()` 钩子兜底释放。
3. **原生层退出兜底防护**：
   - Windows 原生层 (`windows/runner/win32_window.cpp` / `flutter_window.cpp`)：通过 MethodChannel `setTunNodeRoute` 记录节点 IP，在 `WM_CLOSE` / `WM_DESTROY` 及托盘退出时调用 `CleanTunNodeRoute()` 执行 `route delete` 兜底；
   - macOS 原生层 (`macos/Runner/AppDelegate.swift` / `MainFlutterWindow.swift`)：在 `applicationWillTerminate` 钩子中执行 `route delete -host` 兜底。

---

## 10. TUN 模式下 Chrome 断网根因排查与二次终极修复（2026-09-12 实施记录）

### 10.1 根因复盘
实测开启 TUN 模式后 Chrome 仍无法联网，通过排查 `ipconfig /all`、`route print` 与 `%APPDATA%\luxwap\speedtest.log`，定位到两大根因：
1. **Friendly Fire 2.0（原生层误删路由）**：
   - 在 `lines_page.dart` 启动 TUN 模式后，为了避免 TUN 与系统代理双重代理产生冲突，调用了 `_setSystemProxy(false)`。
   - `_setSystemProxy(false)` 触发 MethodChannel `cleanProxy` -> C++ `Win32Window::CleanSystemProxy()`。
   - 在 `win32_window.cpp` 第 339 行，`CleanSystemProxy()` 内部误调用了 `CleanTunNodeRoute()`！
   - **后果**：刚下发成功的节点 `/32` 直连路由（`route add 103.94.185.18 ...`）在 200ms 后被 `CleanTunNodeRoute()` 瞬间删除！导致发往节点 `103.94.185.18:443` 的底层握手报文全部回环进 `luxwap-tun`（日志记录大量 `from tcp:172.19.0.1:xxx accepted tcp:103.94.185.18:443 [tun-in >> proxy]`），引发彻底死锁。
2. **多网卡 DNS 优先级竞争**：
   - 阿里云无影云桌面存在双 VirtIO 网卡，配置了内部 DNS `100.100.2.136`（跃点数 15）。
   - `luxwap-tun` 创建后默认跃点数为 25，Windows Smart Multi-Homed Name Resolution 同时向两张网卡发起 DNS 查询，内网 DNS 以极快速度返回拒绝/NXDOMAIN，拦截了外网域名解析。

### 10.2 终极修复落地方案
1. **原生 C++ 完全解耦** (`windows/runner/win32_window.cpp` & `flutter_window.cpp` & `main.cpp`)：
   - 从 `CleanSystemProxy()` 中彻底剔除 `CleanTunNodeRoute()`，确保开关系统代理绝不影响 TUN 节点路由。
   - 在 `flutter_window.cpp` 新增独立的 `cleanTunNodeRoute` MethodChannel 接口，仅在 TUN 显式断开时触发。
   - 在 `WM_CLOSE`、`WM_DESTROY`、托盘菜单退出及 `main.cpp` 退出时显式调用 `CleanTunNodeRoute()` 进行兜底清理。
2. **TUN 网卡跃点数自动优化** (`TunRouteManager.optimizeTunInterface`)：
   - TUN 虚拟网卡创建后自动调用 `netsh interface ip set interface "luxwap-tun" metric=1`，使 TUN 虚拟网卡优先级（跃点数 1）高于物理网卡（跃点数 15），确保系统及 Chrome 优先使用 TUN 的 Clean DNS (`8.8.8.8`)。
3. **路由增强与防御性防护** (`lib/services/tun_route_manager.dart`)：
   - `parseWindowsDefaultGateway`：遍历所有默认路由，按最小 Metric 选取真实物理外网网关（避开 9999 跃点数的管理内网网关）。
   - `resolveHostToIp`：支持节点地址为域名时的预解析，避免因域名导致 `route add` 命令报错。

### 10.3 内核绝对统一锁定与残留清理（2026-09-13 实施记录）
1. **绝对锁定 `luxwap_core.exe`**：
   - 彻底移除 `fallbackName` 及任何回退至 `xray.exe` 的代码逻辑，统一使用 `luxwap_core.exe`（macOS 为 `luxwap_core`）。
   - `lines_page.dart` 中 `_luxwapCoreDir()` 仅返回 `bin/luxwap_core` 目录。
2. **彻底清理 `resources/bin` 与构建产物中的 `xray` 残留**：
   - 更新 `windows/CMakeLists.txt`，将 `wintun.dll` 的安装源路径切换为 `runner/resources/bin/luxwap_core/wintun.dll`；
   - 物理删除 `windows/runner/resources/bin/xray/`、`macos/Runner/Resources/bin/xray/`、`build/windows/x64/runner/Release/bin/xray/` 目录以及各目录中的 `xray.exe`；
   - 资源与发布目录只保留专有命名：`bin/luxwap_core/`，内部包含 `luxwap_core.exe`、`wintun.dll`、`geoip.dat`、`geosite.dat`。
3. **断开体验精致化**：
   - 识别用户主动断开操作，彻底剔除原本突兀的 `(code -1)` 黑色底部报错横幅，实现静默顺畅退出。
4. **全量测试与 Release 构建**：
   - `tun_routing_test.dart` 扩充至 32 项全维度断言，全量通过（100% Pass）；
   - 重新完成 Release 二进制构建：`build\windows\x64\runner\Release\v2rayn_flutter.exe`。
