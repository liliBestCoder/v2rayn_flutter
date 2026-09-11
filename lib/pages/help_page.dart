import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_toast.dart';

/// 弹出帮助与文档对话框
Future<void> showHelpDialog(BuildContext context, {int initialTab = 0}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 880,
          maxHeight: 720,
        ),
        child: HelpPage(
          isDialog: true,
          initialTab: initialTab,
          onClose: () => Navigator.of(dialogContext).pop(),
        ),
      ),
    ),
  );
}

class HelpPage extends StatefulWidget {
  const HelpPage({
    super.key,
    this.isDialog = false,
    this.initialTab = 0,
    this.onClose,
  });

  final bool isDialog;
  final int initialTab;
  final VoidCallback? onClose;

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;

  String _helpContent = _fallbackHelpGuide;
  String _privacyContent = _fallbackPrivacyPolicy;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _loadAssetDocs();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAssetDocs() async {
    try {
      final help = await rootBundle.loadString('docs/help_guide.md');
      if (mounted && help.isNotEmpty) {
        setState(() => _helpContent = help);
      }
    } catch (_) {}

    try {
      final privacy = await rootBundle.loadString('docs/privacy_policy.md');
      if (mounted && privacy.isNotEmpty) {
        setState(() => _privacyContent = privacy);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _buildHeader(context),
          const Divider(height: 1, color: Color(0xffedf0f5)),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildHelpGuideTab(),
                _buildPrivacyPolicyTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      color: const Color(0xfff8fafc),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline_rounded, color: Color(0xff2b77ff), size: 24),
              const SizedBox(width: 10),
              const Text(
                '帮助与文档中心',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xff111827),
                ),
              ),
              const Spacer(),
              if (widget.isDialog && widget.onClose != null)
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xff64748b), size: 20),
                  splashRadius: 18,
                  onPressed: widget.onClose,
                  tooltip: '关闭',
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xffe2e8f0),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(3),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  labelColor: const Color(0xff2b77ff),
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  unselectedLabelColor: const Color(0xff64748b),
                  unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.menu_book_rounded, size: 14),
                          SizedBox(width: 6),
                          Text('使用与帮助指南'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.privacy_tip_outlined, size: 14),
                          SizedBox(width: 6),
                          Text('隐私保护协议'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xffcbd5e1)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '搜索文档内容 (如: TUN, DoT, 拥堵, FAQ, UWP)...',
                      hintStyle: const TextStyle(fontSize: 11, color: Color(0xff94a3b8)),
                      prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xff94a3b8)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 14, color: Color(0xff94a3b8)),
                              onPressed: () => _searchController.clear(),
                              splashRadius: 14,
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    style: const TextStyle(fontSize: 12, color: Color(0xff1e293b)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHelpGuideTab() {
    final sections = _getHelpSections();
    final filtered = sections.where((sec) {
      if (_selectedCategory != null && sec.category != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      final fullText = '${sec.title} ${sec.content} ${sec.keywords.join(' ')}'.toLowerCase();
      return fullText.contains(_searchQuery);
    }).toList();

    return Column(
      children: [
        // Category Pills
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
          color: const Color(0xfffafbfc),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryPill('全部', null),
                _buildCategoryPill('入门与连接', '入门'),
                _buildCategoryPill('线路拥堵色', '拥堵'),
                _buildCategoryPill('核心功能(TUN/DoT)', '功能'),
                _buildCategoryPill('常见问题FAQ', 'FAQ'),
                _buildCategoryPill('技术支持', '支持'),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: Color(0xfff1f5f9)),
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptySearch()
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    return _buildHelpSectionCard(filtered[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCategoryPill(String title, String? cat) {
    final isSelected = _selectedCategory == cat;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedCategory = cat),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xff2b77ff) : const Color(0xfff1f5f9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xff475569),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHelpSectionCard(_HelpSection section) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xffe2e8f0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xffeff6ff),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(section.icon, size: 16, color: const Color(0xff2b77ff)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    section.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xff0f172a),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xfff1f5f9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    section.badge,
                    style: const TextStyle(fontSize: 10, color: Color(0xff64748b)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(
              section.content,
              style: const TextStyle(
                fontSize: 12,
                height: 1.6,
                color: Color(0xff334155),
              ),
            ),
            if (section.extraWidget != null) ...[
              const SizedBox(height: 12),
              section.extraWidget!,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyPolicyTab() {
    final lines = _privacyContent.split('\n');
    final displayLines = lines.where((line) {
      if (_searchQuery.isEmpty) return true;
      return line.toLowerCase().contains(_searchQuery);
    }).toList();

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          color: const Color(0xfff8fafc),
          child: const Row(
            children: [
              Icon(Icons.shield_outlined, size: 16, color: Color(0xff16a34a)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Luxwap 恪守严格的无访问日志记录原则（No-Logs Policy），绝不记录用户的网络流量与隐私数据。',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xff166534),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xfff1f5f9)),
        Expanded(
          child: displayLines.isEmpty
              ? _buildEmptySearch()
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xffe2e8f0)),
                    ),
                    child: SelectableText(
                      _searchQuery.isEmpty ? _privacyContent : displayLines.join('\n'),
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.7,
                        color: Color(0xff334155),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptySearch() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded, size: 48, color: Color(0xffcbd5e1)),
          const SizedBox(height: 12),
          Text(
            '未找到匹配 "$_searchQuery" 的文档内容',
            style: const TextStyle(fontSize: 13, color: Color(0xff64748b)),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _searchController.clear(),
            child: const Text('清空搜索条件', style: TextStyle(fontSize: 12, color: Color(0xff2b77ff))),
          ),
        ],
      ),
    );
  }

  List<_HelpSection> _getHelpSections() {
    return [
      _HelpSection(
        category: '入门',
        badge: '基础指引',
        title: '1. 快速入门：账号登录与注册',
        icon: Icons.person_outline,
        keywords: ['登录', '注册', 'oauth', '邮箱', 'google', 'twitter'],
        content: '1. 登录与注册切换：在主界面上方通过「账号登录」与「账号注册」双 Tab 无缝切换。\n'
            '2. 注册流程：输入有效电子邮箱与密码，点击「验证邮箱」获取 6 位验证码即可完成激活。\n'
            '3. 第三方快捷登录：支持通过 Google、X (Twitter)、Facebook 账户一键快速授权登录。',
      ),
      _HelpSection(
        category: '拥堵',
        badge: '线路规范',
        title: '2. 线路选择与三色拥堵指标说明',
        icon: Icons.alt_route,
        keywords: ['线路', '拥堵', '绿色', '黄色', '红色', '延迟', '负载'],
        content: '点击任意线路卡片即可选择节点，窗口尺寸已锁死防抖动。节点右侧拥堵图标依据服务器实时负载展示：',
        extraWidget: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xfff8fafc),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xffe2e8f0)),
          ),
          child: Column(
            children: [
              _buildCongestionRow(
                color: const Color(0xff18ad3e),
                title: '🟢 绿色通道 (负载 < 60%)',
                desc: '网络通畅、低延迟、高带宽，推荐优先连接。',
              ),
              const SizedBox(height: 8),
              _buildCongestionRow(
                color: const Color(0xffff9822),
                title: '🟡 黄色通道 (60% ≤ 负载 ≤ 85%)',
                desc: '当前节点使用人数适中，连接稳定。',
              ),
              const SizedBox(height: 8),
              _buildCongestionRow(
                color: const Color(0xffff2d2d),
                title: '🔴 红色拥堵 (负载 > 85%)',
                desc: '当前节点网络繁忙，建议避开切换其他绿色节点。',
              ),
            ],
          ),
        ),
      ),
      _HelpSection(
        category: '功能',
        badge: '核心设置',
        title: '3. TUN 虚拟网卡与全流量接管',
        icon: Icons.stream,
        keywords: ['tun', '虚拟网卡', 'wintun', '游戏', 'cmd', '命令行'],
        content: 'Luxwap 内置 2026 最新版 Xray-core 26+ 与 Wintun 虚拟驱动。\n'
            '• TUN 模式默认开启，在系统网络底层建立虚拟 TUN 网卡通道。\n'
            '• 自动接管不遵循系统代理设置的命令行工具 (Git/Curl)、应用商店以及游戏网络，免去单独配置环境变量的繁琐。',
      ),
      _HelpSection(
        category: '功能',
        badge: '安全加密',
        title: '4. DoT (DNS over TLS) 与路由分流策略',
        icon: Icons.security,
        keywords: ['dot', 'dns', 'tls', '分流', '直连', '广告过滤'],
        content: '• DoT 加密 DNS：在「设置」中配置 DoT 地址（例如 tcp://1.1.1.1:853），所有域名解析均通过 TLS 加密传输，彻底杜绝本地运营商 DNS 劫持与污染。\n'
            '• 精准分流策略：支持自动直连本国 IP、直连国内常用域名、直连本地局域网设备 (NAS/打印机) 以及一键开启恶意广告拦截。',
      ),
      _HelpSection(
        category: '功能',
        badge: 'Windows 专享',
        title: '5. 解除 Win10/11 UWP 应用网络回环限制',
        icon: Icons.window,
        keywords: ['uwp', 'windows', '应用商店', '回环', 'loopback'],
        content: 'Windows 系统的沙盒安全机制默认限制了微软应用商店及 UWP 应用（如 Windows Store、Netflix、Spotify）访问本地 127.0.0.1 代理。\n'
            '在「设置」-「系统工具」中，直接点击「解除 UWP 应用回环限制」按钮，客户端将一键完成 CheckNetIsolation 批处理豁免，无需复杂手动配置。',
      ),
      _HelpSection(
        category: 'FAQ',
        badge: '常见疑问',
        title: '6. 常见问题：关闭客户端后浏览器无法上网？',
        icon: Icons.question_answer_outlined,
        keywords: ['faq', '无法上网', '断网', '代理残留', '注册表'],
        content: '【安全防护保障】：Luxwap 在 Windows 原生层（C++ Win32）与 macOS 系统层均实现了退出守护。当您点击关闭按钮、托盘退出或强行终止时，客户端会自动清理系统代理注册表并还原为直连模式。\n'
            '【排查建议】：若因机器意外断电导致代理残留，只需重新启动 Luxwap 点击一次「连接」再点击「断开」，系统代理设置即可自动完全还原。',
      ),
      _HelpSection(
        category: 'FAQ',
        badge: '常见疑问',
        title: '7. 常见问题：高 DPI 屏幕缩放与窗口防抖',
        icon: Icons.aspect_ratio,
        keywords: ['dpi', '缩放', '高分屏', '抖动', '4k'],
        content: '• 新版已针对 125%、150%、200% 等各种高分屏缩放比例做好了物理像素对齐适配，字体与卡片边缘清晰锐利。\n'
            '• 线路点选与延迟测速已从窗口几何尺寸监听器中完全解耦，连续快速切换线路时，窗口不会再出现任何缩放抖动。',
      ),
      _HelpSection(
        category: '支持',
        badge: '联系我们',
        title: '8. 客户支持与问题反馈',
        icon: Icons.support_agent,
        keywords: ['客服', '支持', '邮箱', '反馈', '工单'],
        content: '如果您在配置使用或线路连接中遇到任何问题，欢迎随时联系支持团队：\n'
            '• 官方技术支持邮箱：support@luxwap.com\n'
            '• 隐私与合规邮箱：privacy@luxwap.com\n'
            '• 官方服务平台：可通过客户端左侧「关于」界面中的「反馈」表单直接发送反馈信息。',
        extraWidget: Row(
          children: [
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(const ClipboardData(text: 'support@luxwap.com'));
                showAppToast('技术支持邮箱已复制到剪贴板', success: true);
              },
              icon: const Icon(Icons.copy, size: 13),
              label: const Text('复制客服邮箱', style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff2b77ff),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildCongestionRow({
    required Color color,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 4, right: 8),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 11, color: Color(0xff334155), height: 1.4),
              children: [
                TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HelpSection {
  _HelpSection({
    required this.category,
    required this.badge,
    required this.title,
    required this.icon,
    required this.keywords,
    required this.content,
    this.extraWidget,
  });

  final String category;
  final String badge;
  final String title;
  final IconData icon;
  final List<String> keywords;
  final String content;
  final Widget? extraWidget;
}

const String _fallbackHelpGuide = '''
# Luxwap 客户端使用与帮助指南
> 适用版本：Luxwap Desktop 2.0+ (Windows / macOS)

## 1. 产品简介
Luxwap 是一款跨平台的高性能网络代理客户端，支持 Windows 10/11 与 macOS。内置 luxwap_core 高性能网络传输核心，提供高匿名性、弹性并发与稳定可靠的网络连接体验。

## 2. 快速入门
1. 登录与注册：主卡片上方可通过「账号登录」与「账号注册」标签无缝切换。
2. 线路选择与连接：
   - 🟢 绿色（负载 < 60%）：网络通畅，延迟低，推荐优先连接。
   - 🟡 黄色（60% ≤ 负载 ≤ 85%）：网络负载适中。
   - 🔴 红色（负载 > 85%）：网络繁忙，建议避开。
3. 点击连接开关，状态栏变绿并实时显示网络上下行速率即代表连接成功。

## 3. 核心功能与配置说明
- 路由策略与分流：支持直连本国 IP、直连中国域名、直连局域网 IP / 域名、阻断恶意广告。
- DoT (DNS over TLS)：通过 TLS 协议加密 DNS 解析请求（如 tcp://1.1.1.1:853），杜绝域名劫持。
- TUN 模式：默认开启。底层创建轻量级 TUN 虚拟网卡接管全系统所有进程网络流量。
- 解除 Win10/11 UWP 应用回环限制：一键豁免微软商店与 UWP 应用访问本地代理。
- 系统托盘与安全守护：关闭或退出时，Win32 原生层自动清理系统代理注册表并还原网络。

## 4. 技术支持与反馈
如在使用过程中遇到任何疑问或线路异常，请发送邮件至技术支持邮箱：support@luxwap.com。
''';

const String _fallbackPrivacyPolicy = '''
# Luxwap 隐私保护协议
> 最新生效日期：2026年9月11日

欢迎使用 Luxwap 客户端。我们高度重视用户的隐私与个人信息保护。

1. 核心隐私原则
- 零访问日志记录（No-Logs Policy）：我们绝不记录、存储或监控用户通过代理网络传输的任何实际网络流量、访问网址、DNS 查询内容或下载数据。
- 最小化收集原则：仅在提供基本账户认证与订阅管理所需范围内收集最基础数据。
- 本地优先原则：您的客户端自定义配置、路由规则选择均加密保存在本地设备。

2. 我们收集的信息范围
- 电子邮箱地址：用于用户身份标识与安全通知。
- 账户密码：经不可逆强哈希加密算法存储，绝不以明文形式保存或传输。
- 订阅与有效期：用于计算剩余流量与到期时间展示。

3. 我们不收集的信息
- 不收集您浏览的具体网页 URL、访问历史与搜索关键词。
- 不收集通讯内容、表单输入、传输的文件或数据包载荷。
- 不收集真实物理地理位置（GPS 数据）。

4. 数据的安全保障
- 传输加密：客户端与中台通信均采用高强度 TLS 1.3 / HTTPS 加密信道。
- 代理信道保护：所有网络代理传输均采用强加密协议（VLESS + TLS / XTLS）。
- 系统代理安全重置：退出程序时自动撤销全局代理配置，防止流量泄露。

5. 联系方式
如对本隐私协议有任何意见，请联系官方隐私支持邮箱：privacy@luxwap.com。
''';
