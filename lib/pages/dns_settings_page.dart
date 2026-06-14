import 'package:flutter/material.dart';

class DnsSettingsPage extends StatelessWidget {
  const DnsSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('DNS 设置'),
      content: const SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(decoration: InputDecoration(labelText: '国内 DNS', hintText: '223.5.5.5')),
            TextField(decoration: InputDecoration(labelText: '国外 DNS', hintText: '8.8.8.8')),
            TextField(decoration: InputDecoration(labelText: '分流规则', hintText: 'geosite/geolocation')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('保存')),
      ],
    );
  }
}
