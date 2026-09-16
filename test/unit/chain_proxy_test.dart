import 'package:flutter_test/flutter_test.dart';
import 'package:v2rayn_flutter/models/client_config.dart';
import 'package:v2rayn_flutter/models/line_node.dart';
import 'package:v2rayn_flutter/services/luxwap_config_builder.dart';

const _node = LineNode(
  name: '美洲HUUYWU',
  region: '美洲',
  raw: 'vless://11111111-2222-3333-4444-555555555555@us1.luxwap.net:443'
      '?encryption=none&security=tls&type=ws&host=us1.luxwap.net&path=%2F#US',
);

Map<String, dynamic> configWith(ClientConfig config) =>
    LuxwapConfigBuilder.buildConfigMap(node: _node, clientConfig: config)!;

List<Map<String, dynamic>> outboundsOf(Map<String, dynamic> config) =>
    (config['outbounds'] as List).cast<Map<String, dynamic>>();

Map<String, dynamic> taggedOutbound(Map<String, dynamic> config, String tag) =>
    outboundsOf(config).firstWhere((o) => o['tag'] == tag);

void main() {
  group('链式代理出站构造', () {
    test('socks5 前置代理带账号密码', () {
      final outbound = LuxwapConfigBuilder.buildChainOutbound(
          'socks5://alice:s3cret@127.0.0.1:1080', 'chain')!;

      expect(outbound['protocol'], 'socks');
      final server = (outbound['settings']['servers'] as List).first;
      expect(server['address'], '127.0.0.1');
      expect(server['port'], 1080);
      expect((server['users'] as List).first,
          {'user': 'alice', 'pass': 's3cret'});
    });

    test('http 前置代理无凭据时不写 users', () {
      final outbound =
          LuxwapConfigBuilder.buildChainOutbound('http://10.0.0.8:3128', 'chain')!;

      expect(outbound['protocol'], 'http');
      final server = (outbound['settings']['servers'] as List).first;
      expect(server.containsKey('users'), isFalse,
          reason: '没填账号时写空 users 会让 Xray 按需要认证处理');
    });

    test('空串、缺端口、不支持的协议一律返回 null', () {
      for (final uri in ['', '   ', 'socks5://127.0.0.1', 'ftp://a.b:21', '???']) {
        expect(LuxwapConfigBuilder.buildChainOutbound(uri, 'chain'), isNull,
            reason: '「$uri」应被判为无效');
      }
    });
  });

  group('链式代理接入运行配置', () {
    test('关闭时不产生 chain 出站，节点也不带 proxySettings', () {
      final config = configWith(const ClientConfig());

      expect(outboundsOf(config).any((o) => o['tag'] == 'chain'), isFalse);
      expect(taggedOutbound(config, 'proxy').containsKey('proxySettings'),
          isFalse);
    });

    test('开启后节点出站经由 chain', () {
      final config = configWith(const ClientConfig(
        chainEnabled: true,
        chainUri: 'socks5://127.0.0.1:1080',
      ));

      expect(taggedOutbound(config, 'proxy')['proxySettings'], {'tag': 'chain'});
      expect(taggedOutbound(config, 'chain')['protocol'], 'socks');
      // direct / block must survive so routing rules still resolve.
      expect(outboundsOf(config).map((o) => o['tag']),
          containsAll(['proxy', 'chain', 'direct', 'block']));
    });

    test('开启但地址无效时退回直连，而不是生成半截配置', () {
      final config = configWith(const ClientConfig(
        chainEnabled: true,
        chainUri: '这不是一个地址',
      ));

      expect(outboundsOf(config).any((o) => o['tag'] == 'chain'), isFalse);
      expect(taggedOutbound(config, 'proxy').containsKey('proxySettings'),
          isFalse,
          reason: '指向不存在的 chain 标签会让 Xray 启动即失败');
    });

    test('开关状态可往返序列化', () {
      const original = ClientConfig(
        chainEnabled: true,
        chainUri: 'socks5://alice:s3cret@127.0.0.1:1080',
      );
      final restored = ClientConfig.fromJson(original.toJson());

      expect(restored.chainEnabled, isTrue);
      expect(restored.chainUri, original.chainUri);
    });
  });
}
