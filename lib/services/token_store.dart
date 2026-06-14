import 'dart:io';
import 'package:path_provider/path_provider.dart';

class TokenStore {
  Future<File> get _file async {
    final appSupportDir = await getApplicationSupportDirectory();
    final dir = Directory('${appSupportDir.path}${Platform.pathSeparator}v2rayn_flutter');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}${Platform.pathSeparator}token.txt');
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
