import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Named values in this browser's private storage for this site (nothing leaves the device).
class Disk {
  String _k(String n) => 'sl_$n';

  Future<bool> exists(String name) async => web.window.localStorage.getItem(_k(name)) != null;

  Future<List<int>?> read(String name) async {
    final v = web.window.localStorage.getItem(_k(name));
    return v == null ? null : base64Decode(v);
  }

  Future<void> write(String name, List<int> bytes) async {
    web.window.localStorage.setItem(_k(name), base64Encode(bytes));
  }

  Future<void> delete(String name) async {
    web.window.localStorage.removeItem(_k(name));
  }

  Future<void> rename(String from, String to) async {
    final v = web.window.localStorage.getItem(_k(from));
    if (v != null) {
      web.window.localStorage.setItem(_k(to), v);
      web.window.localStorage.removeItem(_k(from));
    }
  }
}

final Disk disk = Disk();

/// Downloads the file to the device (iPhone: saves to Files).
Future<void> saveDownload(String name, List<int> bytes, String mime, String subject) async {
  final blob = web.Blob([Uint8List.fromList(bytes).toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final a = web.document.createElement('a') as web.HTMLAnchorElement;
  a.href = url;
  a.download = name;
  web.document.body!.append(a);
  a.click();
  a.remove();
  web.URL.revokeObjectURL(url);
}
