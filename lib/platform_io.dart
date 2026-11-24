import 'dart:io';
import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Named files in the app's private folders (Android and iOS).
class Disk {
  Future<File> _f(String name) async {
    final d = name == 'cloud_backup.bin' ? await getApplicationSupportDirectory() : await getApplicationDocumentsDirectory();
    return File('${d.path}/$name');
  }

  Future<bool> exists(String name) async => (await _f(name)).exists();

  Future<List<int>?> read(String name) async {
    final f = await _f(name);
    return await f.exists() ? f.readAsBytes() : null;
  }

  Future<void> write(String name, List<int> bytes) async {
    final f = await _f(name);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(f.path);
  }

  Future<void> delete(String name) async {
    final f = await _f(name);
    if (await f.exists()) await f.delete();
  }

  Future<void> rename(String from, String to) async {
    final f = await _f(from);
    if (await f.exists()) await f.rename((await _f(to)).path);
  }
}

final Disk disk = Disk();

/// Opens the phone's share sheet with the file.
Future<void> saveDownload(String name, List<int> bytes, String mime, String subject) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes, flush: true);
  await Share.shareXFiles([XFile(file.path, mimeType: mime)], subject: subject);
}
