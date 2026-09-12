import 'dart:io';
import 'package:path_provider/path_provider.dart';

class TokenStore {
  Future<File> get _file async {
    final appSupportDir = await getApplicationSupportDirectory();
    final dir = Directory('${appSupportDir.path}${Platform.pathSeparator}luxwap');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final target = File('${dir.path}${Platform.pathSeparator}token.txt');
    if (!await target.exists()) {
      final legacyFile = File(
        '${appSupportDir.path}${Platform.pathSeparator}v2rayn_flutter${Platform.pathSeparator}token.txt',
      );
      if (await legacyFile.exists()) {
        try {
          await legacyFile.copy(target.path);
        } catch (_) {}
      }
    }
    return target;
  }

  Future<String?> loadToken() async {
    final file = await _file;
    if (!await file.exists()) {
      return null;
    }
    final value = (await file.readAsString()).trim();
    return value.isEmpty ? null : value;
  }

  Future<void> saveToken(String token) async {
    final file = await _file;
    await file.writeAsString(token);
  }

  Future<void> clear() async {
    final file = await _file;
    if (await file.exists()) {
      await file.delete();
    }
  }
}
