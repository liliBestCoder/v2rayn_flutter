import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../models/client_config.dart';

class ClientConfigStore {
  Future<File> get _file async {
    final appSupportDir = await getApplicationSupportDirectory();
    final dir = Directory('${appSupportDir.path}${Platform.pathSeparator}luxwap');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final target = File('${dir.path}${Platform.pathSeparator}config.json');
    if (!await target.exists()) {
      final legacyFile = File(
        '${appSupportDir.path}${Platform.pathSeparator}v2rayn_flutter${Platform.pathSeparator}config.json',
      );
      if (await legacyFile.exists()) {
        try {
          await legacyFile.copy(target.path);
        } catch (_) {}
      }
    }
    return target;
  }

  Future<ClientConfig> load() async {
    final file = await _file;
    if (!await file.exists()) {
      return const ClientConfig();
    }
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is Map<String, dynamic>) {
        return ClientConfig.fromJson(json);
      }
    } catch (_) {
      // Fall through to defaults if the local config is damaged.
    }
    return const ClientConfig();
  }

  Future<void> save(ClientConfig config) async {
    final file = await _file;
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(config.toJson()),
    );
  }
}
