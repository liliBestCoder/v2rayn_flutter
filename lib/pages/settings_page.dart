import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../app_toast.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final outerDns = TextEditingController(text: '8.8.8.8');
  final innerDns = TextEditingController(text: '223.5.5.5');
  final globalDns = TextEditingController(text: '8.8.8.8');

  bool passByIp = true;
  bool passByDomain = true;
  bool passByLanIp = true;
  bool passByLanDomain = false;
  bool blockAds = false;
  bool vpnRoute = true;
  bool geoUpdating = false;
  int? geoPercent;
  String geoLabel = '';
  String? geoError;
  String routeStrategy = 'AsIs';
  String language = '简体中文';
  bool configLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (configLoaded) {
      return;
    }
    final config = AppScope.of(context).clientConfig;
    outerDns.text = config.outerDns;
    innerDns.text = config.innerDns;
    globalDns.text = config.globalDns;
    passByIp = config.passByIp;
    passByDomain = config.passByDomain;
    passByLanIp = config.passByLanIp;
    passByLanDomain = config.passByLanDomain;
    blockAds = config.blockAds;
    vpnRoute = config.vpnRoute;
    routeStrategy = config.routeStrategy;
    language = config.language;
    configLoaded = true;
  }

  @override
  void dispose() {
    outerDns.dispose();
    innerDns.dispose();
    globalDns.dispose();
    super.dispose();
  }

  Future<void> _updateGeoData() async {
    if (geoUpdating) {
      return;
    }
    setState(() {
      geoUpdating = true;
      geoLabel = 'geoip';
      geoPercent = 0;
      geoError = null;
    });
    try {
      await _downloadGeoFile(
        url:
            'https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat',
        fileName: 'geoip.dat',
        label: 'geoip',
      );
      await _downloadGeoFile(
        url:
            'https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat',
        fileName: 'geosite.dat',
        label: 'geosite',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        geoUpdating = false;
        geoLabel = 'geosite';
        geoPercent = 100;
      });
      await Future<void>.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          geoLabel = '';
          geoPercent = null;
        });
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        geoUpdating = false;
        geoError = '失败';
      });
    }
  }

  Future<void> _saveConfig({bool notify = false}) async {
    final state = AppScope.of(context);
    await state.updateClientConfig(
      state.clientConfig.copyWith(
        routeStrategy: routeStrategy,
        language: language,
        passByIp: passByIp,
        passByDomain: passByDomain,
        passByLanIp: passByLanIp,
        passByLanDomain: passByLanDomain,
        blockAds: blockAds,
        vpnRoute: vpnRoute,
        outerDns:
            outerDns.text.trim().isEmpty ? '8.8.8.8' : outerDns.text.trim(),
        innerDns:
            innerDns.text.trim().isEmpty ? '223.5.5.5' : innerDns.text.trim(),
        globalDns:
            globalDns.text.trim().isEmpty ? '8.8.8.8' : globalDns.text.trim(),
      ),
    );
    if (notify) {
      showAppToast('配置已保存，重启代理后生效', success: true);
    }
  }

  void _setAndSave(VoidCallback change) {
    setState(change);
    _saveConfig(notify: true);
  }

  Future<void> _downloadGeoFile({
    required String url,
    required String fileName,
    required String label,
  }) async {
    final dir = File(Platform.resolvedExecutable).parent;
    final target = File('${dir.path}${Platform.pathSeparator}$fileName');
    final temp =
        File('${target.path}.${DateTime.now().millisecondsSinceEpoch}.tmp');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'download failed: ${response.statusCode}',
          uri: Uri.parse(url),
        );
      }

      final sink = temp.openWrite();
      var received = 0;
      final total = response.contentLength;
      await for (final chunk in response) {
        received += chunk.length;
        sink.add(chunk);
        if (total > 0 && mounted) {
          final percent = (received * 100 / total).clamp(0, 100).floor();
          setState(() {
            geoLabel = label;
            geoPercent = percent;
          });
        }
      }
      await sink.flush();
      await sink.close();

      if (await target.exists()) {
        await target.delete();
      }
      await temp.rename(target.path);
    } catch (_) {
      if (await temp.exists()) {
        await temp.delete();
      }
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 22, 30, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('路由配置'),
            const SizedBox(height: 10),
            _SettingRow(
              title: '更新数据包(Geo)',
              subtitle: '上次更新时间2025-08-08',
              trailing: _GeoUpdateButton(
                label: geoLabel,
                percent: geoPercent,
                error: geoError,
                updating: geoUpdating,
                onPressed: _updateGeoData,
              ),
            ),
            _SettingRow(
              title: '路由策略',
              subtitle: '国内默认AsIs，海外默认IPIfNonMatch',
              trailing: _DropdownText(
                value: routeStrategy,
                values: const ['AsIs', 'IPIfNonMatch', 'IPOnDemand'],
                onSelected: (value) => _setAndSave(() => routeStrategy = value),
              ),
            ),
            _SettingRow(
              title: '直连本国IP',
              subtitle: '本国IP不使用VPN，直连更快（推荐打开）',
              trailing: _MiniSwitch(
                value: passByIp,
                onChanged: (v) => _setAndSave(() => passByIp = v),
              ),
            ),
            _SettingRow(
              title: '直连中国域名',
              subtitle: '仅中国用户生效，海外用户没有对应geosite分类',
              trailing: _MiniSwitch(
                value: passByDomain,
                onChanged: (v) => _setAndSave(() => passByDomain = v),
              ),
            ),
            _SettingRow(
              title: '直连局域网IP',
              subtitle: '局域网IP不使用VPN，直连更快（推荐打开）',
              trailing: _MiniSwitch(
                value: passByLanIp,
                onChanged: (v) => _setAndSave(() => passByLanIp = v),
              ),
            ),
            _SettingRow(
              title: '直连局域网域名',
              subtitle: '局域网域名不使用VPN，直连更快（推荐打开）',
              trailing: _MiniSwitch(
                value: passByLanDomain,
                onChanged: (v) => _setAndSave(() => passByLanDomain = v),
              ),
            ),
            _SettingRow(
              title: '阻断广告',
              subtitle: '阻断常规广告，个别网站可能无法彻底阻断',
              trailing: _MiniSwitch(
                value: blockAds,
                onChanged: (v) => _setAndSave(() => blockAds = v),
              ),
            ),
            const SizedBox(height: 16),
            const _SectionTitle('DNS配置'),
            const SizedBox(height: 8),
            _SettingRow(
              title: '启用VPN路由  端口：10853',
              subtitle: '启用分流DNS，配置会在重启代理后生效',
              trailing: _MiniSwitch(
                value: vpnRoute,
                onChanged: (v) => _setAndSave(() => vpnRoute = v),
              ),
            ),
            _SettingRow(
              title: '域外流量DNS8.8.8.8',
              subtitle: '访问境外使用的DNS，推荐国外DNS',
              trailing: _EditableDnsField(
                controller: outerDns,
                onChanged: () => _saveConfig(notify: true),
              ),
            ),
            _SettingRow(
              title: '域内流量DNS223.5.5.5',
              subtitle: '中国域名使用的DNS，推荐国内DNS',
              trailing: _EditableDnsField(
                controller: innerDns,
                onChanged: () => _saveConfig(notify: true),
              ),
            ),
            _SettingRow(
              title: '全局流量DNS8.8.8.8',
              subtitle: '不区分流量，全局一个DNS地址',
              trailing: _EditableDnsField(
                controller: globalDns,
                onChanged: () => _saveConfig(notify: true),
              ),
            ),
            const SizedBox(height: 10),
            _SettingRow(
              title: '语言',
              subtitle: '',
              trailing: _DropdownText(
                value: language,
                values: const ['简体中文', 'English'],
                onSelected: (value) => _setAndSave(() => language = value),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xff111111),
      ),
    );
  }
}

class _GeoUpdateButton extends StatelessWidget {
  const _GeoUpdateButton({
    required this.label,
    required this.percent,
    required this.error,
    required this.updating,
    required this.onPressed,
  });

  final String label;
  final int? percent;
  final String? error;
  final bool updating;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final text = error ?? (percent == null ? '' : '$label $percent%');
    return InkWell(
      onTap: updating ? null : onPressed,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 124,
        height: 32,
        child: Stack(
          alignment: Alignment.centerRight,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xfff3f3f3),
              ),
            ),
            if (text.isEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 5.5),
                child: Image.asset(
                  'assets/images/cloud.png',
                  width: 15,
                  height: 15,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 34),
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: error == null
                        ? const Color(0xff2b77ff)
                        : const Color(0xffd32f2f),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: subtitle.isEmpty ? 34 : 48,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 168,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff555555),
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: Color(0xffb2b2b2),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Expanded(child: _DashedLine()),
          const SizedBox(width: 16),
          SizedBox(
            width: 128,
            child: Align(alignment: Alignment.centerRight, child: trailing),
          ),
        ],
      ),
    );
  }
}

class _DropdownText extends StatelessWidget {
  const _DropdownText({
    required this.value,
    required this.values,
    required this.onSelected,
  });

  final String value;
  final List<String> values;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '',
      initialValue: value,
      onSelected: onSelected,
      itemBuilder: (context) => values
          .map(
            (item) => PopupMenuItem<String>(
              value: item,
              height: 30,
              child: Text(item, style: const TextStyle(fontSize: 10)),
            ),
          )
          .toList(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 10, color: Color(0xff111111)),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.arrow_drop_down, size: 15, color: Color(0xff111111)),
        ],
      ),
    );
  }
}

class _EditableDnsField extends StatefulWidget {
  const _EditableDnsField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  State<_EditableDnsField> createState() => _EditableDnsFieldState();
}

class _EditableDnsFieldState extends State<_EditableDnsField> {
  late final FocusNode focusNode;
  bool editing = false;

  @override
  void initState() {
    super.initState();
    focusNode = FocusNode();
    focusNode.addListener(() {
      if (!focusNode.hasFocus && editing && mounted) {
        setState(() => editing = false);
        widget.onChanged();
      }
    });
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() => editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusNode.requestFocus();
      widget.controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.controller.text.length,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!editing) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: _startEditing,
        child: SizedBox(
          width: 96,
          height: 24,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              widget.controller.text,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 10, color: Color(0xff111111)),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: 96,
      height: 24,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter): () {
            setState(() => editing = false);
            widget.onChanged();
          },
        },
        child: TextField(
          controller: widget.controller,
          focusNode: focusNode,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          style: const TextStyle(fontSize: 10, color: Color(0xff111111)),
        ),
      ),
    );
  }
}

class _MiniSwitch extends StatelessWidget {
  const _MiniSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 32,
        height: 20,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 22,
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xffdddddd),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            AnimatedAlign(
              duration: const Duration(milliseconds: 120),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      value ? const Color(0xff4396f4) : const Color(0xff999999),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashPainter(),
      child: const SizedBox(width: double.infinity, height: 1),
    );
  }
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xff9f9f9f)
      ..strokeWidth = 0.8;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + 4, 0), paint);
      x += 8;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
