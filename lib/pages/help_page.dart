import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_toast.dart';
import '../theme/luxwap_theme.dart';

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
      color: LuxwapColors.pageBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline_rounded, color: LuxwapColors.brand500, size: 24),
              const SizedBox(width: 10),
              const Text(
                '帮助与文档中心',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: LuxwapColors.neutral900,
                ),
              ),
              const Spacer(),
              if (widget.isDialog && widget.onClose != null)
                IconButton(
                  icon: const Icon(Icons.close, color: LuxwapColors.neutral500, size: 20),
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
                decoration: const BoxDecoration(
                  color: LuxwapColors.neutral200,
                  borderRadius: LuxwapRadius.rSm,
                ),
                padding: const EdgeInsets.all(3),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: LuxwapRadius.rSm,
                    boxShadow: LuxwapShadows.card,
                  ),
                  labelColor: LuxwapColors.brand500,
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  unselectedLabelColor: LuxwapColors.neutral600,
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
                    borderRadius: LuxwapRadius.rSm,
                    border: Border.all(color: LuxwapColors.borderLight),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '搜索文档内容 (如: TUN, DoT, 拥堵, FAQ, UWP)...',
                      hintStyle: const TextStyle(fontSize: 11, color: LuxwapColors.neutral500),
                      prefixIcon: const Icon(Icons.search, size: 16, color: LuxwapColors.neutral500),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 14, color: LuxwapColors.neutral500),
                              onPressed: () => _searchController.clear(),
                              splashRadius: 14,
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    style: const TextStyle(fontSize: 12, color: LuxwapColors.neutral900),
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
          color: LuxwapColors.pageBackground,
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
        const Divider(height: 1, color: LuxwapColors.borderLight),
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
        borderRadius: LuxwapRadius.rLg,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? LuxwapColors.brand500 : LuxwapColors.neutral200,
            borderRadius: LuxwapRadius.rLg,
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? Colors.white : LuxwapColors.neutral700,
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
        borderRadius: LuxwapRadius.rMd,
        border: Border.all(color: LuxwapColors.borderLight),
        boxShadow: LuxwapShadows.card,
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
                  decoration: const BoxDecoration(
                    color: LuxwapColors.brand50,
                    borderRadius: LuxwapRadius.rSm,
                  ),
                  child: Icon(section.icon, size: 16, color: LuxwapColors.brand500),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    section.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: LuxwapColors.neutral900,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: const BoxDecoration(
                    color: LuxwapColors.neutral200,
                    borderRadius: LuxwapRadius.rSm,
                  ),
                  child: Text(
                    section.badge,
                    style: const TextStyle(fontSize: 10, color: LuxwapColors.neutral600),
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
                color: LuxwapColors.neutral700,
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
    final sections = _getPrivacySections();
    final filteredSections = sections.where((section) {
      if (_searchQuery.isEmpty) return true;
      if (section.title.toLowerCase().contains(_searchQuery) ||
          section.summary.toLowerCase().contains(_searchQuery)) {
        return true;
      }
      return section.points.any((p) =>
          p.title.toLowerCase().contains(_searchQuery) ||
          p.desc.toLowerCase().contains(_searchQuery));
    }).toList();

    return Column(
      children: [
        // 顶部安全声明与协议标识
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          decoration: const BoxDecoration(
            color: LuxwapColors.stateSuccessSurface,
            border: Border(bottom: BorderSide(color: Color(0xffc8e6c9))),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: LuxwapRadius.rSm,
                  border: Border.all(color: LuxwapColors.stateSuccess.withValues(alpha: 0.3)),
                ),
                child: const Center(
                  child: Icon(Icons.verified_user_rounded, size: 20, color: LuxwapColors.stateSuccess),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Luxwap 隐私保护协议',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: LuxwapColors.neutral900,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: LuxwapColors.stateSuccess.withValues(alpha: 0.4)),
                          ),
                          child: const Text(
                            '最新生效日期：2026年9月11日',
                            style: TextStyle(fontSize: 10, color: LuxwapColors.stateSuccess, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Luxwap 恪守严格的无访问日志记录原则（No-Logs Policy），绝不记录用户的网络流量与隐私数据。您的配置与偏好仅加密保存在本地设备上。',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: Color(0xff2e7d32),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filteredSections.isEmpty
              ? _buildEmptySearch()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                  itemCount: filteredSections.length,
                  itemBuilder: (context, index) {
                    final sec = filteredSections[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: LuxwapRadius.rMd,
                        border: Border.all(color: LuxwapColors.borderLight),
                        boxShadow: LuxwapShadows.card,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 16,
                                  decoration: const BoxDecoration(
                                    color: LuxwapColors.brand500,
                                    borderRadius: BorderRadius.all(Radius.circular(2)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  sec.title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: LuxwapColors.neutral900,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: sec.badgeBg,
                                    borderRadius: LuxwapRadius.rSm,
                                  ),
                                  child: Text(
                                    sec.badge,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: sec.badgeColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (sec.summary.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                sec.summary,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: LuxwapColors.neutral600,
                                  height: 1.4,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            ...sec.points.map((pt) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        margin: const EdgeInsets.only(top: 6, right: 10),
                                        decoration: BoxDecoration(
                                          color: pt.dotColor ?? LuxwapColors.brand500,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      Expanded(
                                        child: RichText(
                                          text: TextSpan(
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: LuxwapColors.neutral800,
                                              height: 1.5,
                                            ),
                                            children: [
                                              TextSpan(
                                                text: '${pt.title}：',
                                                style: const TextStyle(fontWeight: FontWeight.w600),
                                              ),
                                              TextSpan(text: pt.desc),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                    );
                  },
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
          const Icon(Icons.search_off_rounded, size: 48, color: LuxwapColors.neutral400),
          const SizedBox(height: 12),
          Text(
            '未找到匹配 "$_searchQuery" 的文档内容',
            style: const TextStyle(fontSize: 13, color: LuxwapColors.neutral500),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _searchController.clear(),
            child: const Text('清空搜索条件', style: TextStyle(fontSize: 12, color: LuxwapColors.brand500)),
          ),
        ],
      ),
    );
  }

  List<_PrivacySection> _getPrivacySections() {
    return [
      _PrivacySection(
        chapter: '01',
        title: '1. 核心隐私原则',
        badge: '核心承诺',
        badgeBg: LuxwapColors.stateSuccessSurface,
        badgeColor: LuxwapColors.stateSuccess,
        summary: 'Luxwap 致力于为全球用户构建最安全、私密、透明的网络代理环境，恪守三大基本底线。',
        points: [
          _PrivacyPoint(
            title: '零访问日志记录（No-Logs Policy）',
            desc: '我们绝不记录、存储或监控用户通过代理网络传输的任何实际网络流量、访问网址、DNS 查询内容或下载数据。',
            dotColor: LuxwapColors.stateSuccess,
          ),
          _PrivacyPoint(
            title: '最小化收集原则',
            desc: '我们仅在提供基本账户认证与订阅管理所需范围内收集最基础的数据。',
            dotColor: LuxwapColors.brand500,
          ),
          _PrivacyPoint(
            title: '本地优先原则',
            desc: '您的所有客户端自定义配置、路由规则选择、节点偏好均加密保存在您的本地设备上。',
            dotColor: LuxwapColors.brand500,
          ),
        ],
      ),
      _PrivacySection(
        chapter: '02',
        title: '2. 我们收集的信息范围',
        badge: '信息合规',
        badgeBg: LuxwapColors.brand50,
        badgeColor: LuxwapColors.brand500,
        summary: '为了确保服务的持续可用性与账户安全性，我们仅在必要场景下处理以下有限信息：',
        points: [
          _PrivacyPoint(
            title: '账户与注册信息',
            desc: '电子邮箱地址（用于用户身份标识与安全验证码发送）；账户密码（在服务器端经不可逆强哈希加密算法存储，本软件绝不以明文形式保存或传输）；第三方授权信息（Google、X、Facebook 授权仅获取公开 OpenID 及邮箱，绝不获取您的社交好友关系或第三方账号密码）。',
          ),
          _PrivacyPoint(
            title: '服务运行与订阅信息',
            desc: '当前套餐到期时间、套餐流量总额及当期已使用流量计数（用于展示剩余可用额度）；基于合规任务与使用时长累计的会员积分数据。',
          ),
          _PrivacyPoint(
            title: '设备与技术信息',
            desc: '设备操作系统版本（如 Windows 10/11 或 macOS，用于适配最佳代理核心架构组件）；应用版本（用于检测最新可用更新与推送安全补丁）。',
          ),
        ],
      ),
      _PrivacySection(
        chapter: '03',
        title: '3. 我们不收集的信息 (明确禁止清单)',
        badge: '严禁收集',
        badgeBg: LuxwapColors.stateErrorSurface,
        badgeColor: LuxwapColors.stateError,
        summary: '我们在任何情况下均绝不收集或记录以下任何用户隐私数据：',
        points: [
          _PrivacyPoint(
            title: '网络访问记录',
            desc: '绝不收集您浏览的具体网页 URL、访问历史记录、下载内容与搜索关键词。',
            dotColor: LuxwapColors.stateError,
          ),
          _PrivacyPoint(
            title: '通信与载荷内容',
            desc: '绝不收集您的通讯内容、表单输入、传输的文件或数据包实际载荷。',
            dotColor: LuxwapColors.stateError,
          ),
          _PrivacyPoint(
            title: '物理地理位置',
            desc: '绝不收集您的真实物理地理位置（GPS 精度数据）。',
            dotColor: LuxwapColors.stateError,
          ),
          _PrivacyPoint(
            title: '本地敏感文件',
            desc: '绝不读取任何未经授权的本地计算机文件或敏感软硬件信息。',
            dotColor: LuxwapColors.stateError,
          ),
        ],
      ),
      _PrivacySection(
        chapter: '04',
        title: '4. 数据的安全保障',
        badge: '安全架构',
        badgeBg: LuxwapColors.brand50,
        badgeColor: LuxwapColors.brand500,
        summary: '我们采用全球业界领先的端到端强加密架构保护数据安全：',
        points: [
          _PrivacyPoint(
            title: '全链路传输加密',
            desc: '客户端与中台服务器之间的所有通信均采用高强度 TLS 1.3 / HTTPS 加密信道，防止中间人窃听与篡改。',
          ),
          _PrivacyPoint(
            title: '代理信道保护',
            desc: '所有网络代理传输均采用强加密协议（VLESS + TLS / XTLS / ChaCha20），保障公用 Wi-Fi 及不可信网络环境下的通信安全。',
          ),
          _PrivacyPoint(
            title: '系统代理安全重置',
            desc: '客户端内置底层安全退出防护机制，在关闭程序或异常退出时立即撤销全局代理配置，防止用户网络中断或流量泄露。',
          ),
        ],
      ),
      _PrivacySection(
        chapter: '05',
        title: '5. Cookie 与本地存储',
        badge: '存储透明',
        badgeBg: LuxwapColors.neutral200,
        badgeColor: LuxwapColors.neutral700,
        summary: '本桌面客户端不依赖传统网页 Cookie。您的本地配置信息保存在系统标准应用配置目录：',
        points: [
          _PrivacyPoint(
            title: '本地配置文件路径',
            desc: 'Windows 系统存储于 %APPDATA%\\luxwap\\config.json；macOS 系统存储于 ~/Library/Application Support/luxwap/config.json。您可随时在客户端重置或在本地手动清除。',
          ),
        ],
      ),
      _PrivacySection(
        chapter: '06',
        title: '6. 用户的权利与支持',
        badge: '用户赋权',
        badgeBg: LuxwapColors.brand50,
        badgeColor: LuxwapColors.brand500,
        summary: '依据相关法律法规，您对您的个人信息享有完整权利：',
        points: [
          _PrivacyPoint(
            title: '查询与更正',
            desc: '您可在客户端「个人中心」随时查看您的用户 ID、昵称、注册邮箱，并可自主修改昵称或更新密码。',
          ),
          _PrivacyPoint(
            title: '注销账号',
            desc: '如需注销账号并删除所有云端关联数据，可通过官方客服渠道申请彻底注销。',
          ),
          _PrivacyPoint(
            title: '联系我们',
            desc: '如对本隐私协议有任何意见、建议或申诉，请随时联系官方隐私团队邮箱：privacy@luxwap.com。',
          ),
        ],
      ),
    ];
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
            color: LuxwapColors.neutral200,
            borderRadius: LuxwapRadius.rSm,
            border: Border.all(color: LuxwapColors.borderLight),
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
        content: 'Luxwap 内置 2026 最新版网络加速核心与 Wintun 虚拟驱动。\n'
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
                backgroundColor: LuxwapColors.brand500,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: const RoundedRectangleBorder(borderRadius: LuxwapRadius.rLg),
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
              style: const TextStyle(fontSize: 11, color: LuxwapColors.neutral700, height: 1.4),
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

class _PrivacySection {
  _PrivacySection({
    required this.chapter,
    required this.title,
    required this.badge,
    required this.badgeBg,
    required this.badgeColor,
    required this.summary,
    required this.points,
  });

  final String chapter;
  final String title;
  final String badge;
  final Color badgeBg;
  final Color badgeColor;
  final String summary;
  final List<_PrivacyPoint> points;
}

class _PrivacyPoint {
  _PrivacyPoint({
    required this.title,
    required this.desc,
    this.dotColor,
  });

  final String title;
  final String desc;
  final Color? dotColor;
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
