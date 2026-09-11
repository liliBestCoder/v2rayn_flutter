import 'package:flutter/material.dart';

import '../app_toast.dart';
import '../theme/luxwap_theme.dart';
import 'help_page.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final feedbackController = TextEditingController();

  @override
  void dispose() {
    feedbackController.dispose();
    super.dispose();
  }

  void _sendFeedback() {
    showAppToast('反馈已提交', success: true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth = constraints.maxWidth - 68;
          return SingleChildScrollView(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(34, 58, 34, 40),
                child: SizedBox(
                  width: contentWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            '关于 Luxwap',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: LuxwapColors.neutral900,
                            ),
                          ),
                          const SizedBox(width: 128),
                          SizedBox(
                            width: 86,
                            height: 28,
                            child: TextButton.icon(
                              onPressed: () =>
                                  showAppToast('当前已是最新版本', success: true),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                backgroundColor: LuxwapColors.neutral200,
                                foregroundColor: LuxwapColors.neutral900,
                                shape: const RoundedRectangleBorder(
                                    borderRadius: LuxwapRadius.rSm),
                              ),
                              icon: const Icon(Icons.track_changes, size: 13),
                              label: const Text(
                                '更新软件',
                                style: TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Text(
                            '稳定版本：V2.1.3.20250818_release',
                            style:
                                TextStyle(fontSize: 11, color: LuxwapColors.neutral600),
                          ),
                          const SizedBox(width: 24),
                          InkWell(
                            onTap: () => showHelpDialog(context, initialTab: 0),
                            child: const Text(
                              '使用与帮助指南',
                              style: TextStyle(
                                fontSize: 11,
                                color: LuxwapColors.brand500,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          InkWell(
                            onTap: () => showHelpDialog(context, initialTab: 1),
                            child: const Text(
                              '隐私保护协议',
                              style: TextStyle(
                                fontSize: 11,
                                color: LuxwapColors.brand500,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 36),
                      const Text(
                        '版本说明',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: LuxwapColors.neutral900),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '本软件持续迭代优化，如需获取最新版本及反馈问题，请联系支持团队。',
                        style: TextStyle(
                            fontSize: 11,
                            color: LuxwapColors.neutral700,
                            height: 1.5),
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        '反馈',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: LuxwapColors.neutral900),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: contentWidth,
                        height: 170,
                        decoration: BoxDecoration(
                          color: LuxwapColors.neutral200,
                          borderRadius: LuxwapRadius.rSm,
                          border: Border.all(color: LuxwapColors.borderLight),
                        ),
                        child: TextField(
                          controller: feedbackController,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: const InputDecoration(
                            hintText: '反馈内容',
                            hintStyle: TextStyle(
                                fontSize: 11, color: LuxwapColors.neutral500),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.fromLTRB(16, 14, 16, 14),
                          ),
                          style: const TextStyle(
                              fontSize: 12, color: LuxwapColors.neutral900),
                        ),
                      ),
                      const SizedBox(height: 34),
                      SizedBox(
                        width: contentWidth,
                        child: Center(
                          child: SizedBox(
                            width: 84,
                            height: 30,
                            child: TextButton(
                              onPressed: _sendFeedback,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                backgroundColor: LuxwapColors.brand50,
                                foregroundColor: LuxwapColors.brand500,
                                shape: const RoundedRectangleBorder(
                                    borderRadius: LuxwapRadius.rLg),
                              ),
                              child: const Text(
                                '发送',
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
