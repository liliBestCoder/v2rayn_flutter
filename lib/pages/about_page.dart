import 'package:flutter/material.dart';

import '../app_toast.dart';

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
                padding: const EdgeInsets.fromLTRB(48, 44, 48, 40),
                child: SizedBox(
                  width: contentWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '关于 Luxwap',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF111111),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            '稳定版本：V2.1.3.20250818_release',
                            style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
                          ),
                          const SizedBox(width: 32),
                          SizedBox(
                            height: 32,
                            child: TextButton.icon(
                              onPressed: () =>
                                  showAppToast('当前已是最新版本', success: true),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                backgroundColor: const Color(0xFFF3F6FB),
                                foregroundColor: const Color(0xFF333333),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              icon: const Icon(Icons.sync_rounded, size: 15, color: Color(0xFF555555)),
                              label: const Text(
                                '更新软件',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 36),
                      const Text(
                        '版本说明',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF111111)),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '本软件持续迭代优化，如需获取最新版本或反馈问题，请联系支持团队。',
                        style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF555555),
                            height: 1.5),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        '反馈',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF111111)),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: contentWidth,
                        height: 240,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F7F8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: TextField(
                          controller: feedbackController,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: const InputDecoration(
                            hintText: '反馈内容',
                            hintStyle: TextStyle(
                                fontSize: 13, color: Color(0xFF999999)),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            fillColor: Colors.transparent,
                            contentPadding: EdgeInsets.all(20),
                          ),
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF111111)),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: contentWidth,
                        child: Center(
                          child: SizedBox(
                            width: 140,
                            height: 54,
                            child: FilledButton(
                              onPressed: _sendFeedback,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFE9F0FF),
                                foregroundColor: const Color(0xFF286AFC),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                              ),
                              child: const Text(
                                '发送',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w500),
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
