import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../models/client_config.dart';

class ClientConfigStore {
  Future<File> get _file async {
    final appSupportDir = await getApplicationSupportDirectory();
    final dir = Directory('${appSupportDir.path}${Platform.pathSeparator}v2rayn_flutter');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}${Platform.pathSeparator}config.json');
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
