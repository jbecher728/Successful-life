import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'platform.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keystore-backed secure storage (holds the encryption key and app-lock data).
const secure = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));

/// Local key-value store with the same API the app used with SharedPreferences,
/// but saved as an AES-256-GCM encrypted file. The key lives in the Android Keystore.
class Store {
  static Future<Store>? _opening;
  static Future<Store> getInstance() => _opening ??= _open();
  static final _algo = AesGcm.with256bits();

  final Map<String, Object> _m;
  final SecretKey _key;
  Future<void> _writing = Future<void>.value();
  Store._(this._m, this._key);
  SecretKey? _cloudKey;
  List<int>? _cloudSalt;
  static const _magic = [0x53, 0x4c, 0x42, 0x31]; // 'SLB1'
  bool get cloudOn => _cloudKey != null;

  static const _main = 'store.enc';

  static Future<Store> _open() async {
    final hasFile = await disk.exists(_main);
    // On iOS the keychain survives uninstalling. If there is no data file this is a fresh install,
    // so drop any leftover key, PIN or backup secrets from a previous install.
    if (!hasFile) {
      try {
        await secure.deleteAll();
      } catch (_) {}
    }
    var keyB64 = await secure.read(key: 'store_key');
    if (keyB64 == null) {
      final r = Random.secure();
      keyB64 = base64Encode(List<int>.generate(32, (_) => r.nextInt(256)));
      await secure.write(key: 'store_key', value: keyB64);
    }
    final key = SecretKey(base64Decode(keyB64));
    final m = <String, Object>{};
    if (hasFile) {
      try {
        final bytes = (await disk.read(_main))!;
        final box = SecretBox.fromConcatenation(bytes, nonceLength: 12, macLength: 16);
        final clear = await _algo.decrypt(box, secretKey: key);
        final j = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
        j.forEach((k, v) {
          if (v is List) {
            m[k] = List<String>.from(v);
          } else if (v is String || v is int || v is double || v is bool) {
            m[k] = v as Object;
          }
        });
      } catch (_) {
        try {
          await disk.rename(_main, 'store.enc.unreadable');
        } catch (_) {}
      }
    }
    final s = Store._(m, key);
    try {
    final ck = await secure.read(key: 'cloud_key');
      final cs = await secure.read(key: 'cloud_salt');
      if (ck != null && cs != null) {
        s._cloudKey = SecretKey(base64Decode(ck));
        s._cloudSalt = base64Decode(cs);
      }
    } catch (_) {}
    await s._migrateLegacy();
    return s;
  }

  /// Moves data from the old unencrypted SharedPreferences into the encrypted file once.
  Future<void> _migrateLegacy() async {
    if (_m.containsKey('_migrated')) return;
    try {
      final old = await SharedPreferences.getInstance();
      for (final k in old.getKeys()) {
        final v = old.get(k);
        if (v is List) {
          _m[k] = List<String>.from(v);
        } else if (v is String || v is int || v is double || v is bool) {
          _m[k] = v as Object;
        }
      }
      await old.clear();
    } catch (_) {}
    _m['_migrated'] = true;
    await _flush();
  }

  static const _cloudName = 'cloud_backup.bin';

  /// True when an encrypted backup file (restored by Android from the user's Google account) is on this phone.
  static Future<bool> cloudBackupExists() async {
    try {
      return await disk.exists(_cloudName);
    } catch (_) {
      return false;
    }
  }

  static Future<void> deleteCloudFile() async {
    try {
      await disk.delete(_cloudName);
    } catch (_) {}
  }

  static Future<SecretKey> _derive(String pass, List<int> salt) =>
      Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 100000, bits: 256).deriveKeyFromPassword(password: pass, nonce: salt);

  /// Turns on the optional Google backup: an encrypted copy that only the backup passphrase can open.
  Future<void> enableCloud(String pass) async {
    final r = Random.secure();
    final salt = List<int>.generate(16, (_) => r.nextInt(256));
    final k = await _derive(pass, salt);
    await secure.write(key: 'cloud_key', value: base64Encode(await k.extractBytes()));
    await secure.write(key: 'cloud_salt', value: base64Encode(salt));
    _cloudKey = k;
    _cloudSalt = salt;
    await _writeCloud(jsonEncode(_m));
  }

  Future<void> disableCloud() async {
    _cloudKey = null;
    _cloudSalt = null;
    await secure.delete(key: 'cloud_key');
    await secure.delete(key: 'cloud_salt');
    await deleteCloudFile();
  }

  /// Restores data from the backup file. Returns false if the passphrase is wrong or the file is unreadable.
  Future<bool> restoreFromCloud(String pass) async {
    try {
      final bytes = (await disk.read(_cloudName))!;
      final salt = bytes.sublist(4, 20);
      final k = await _derive(pass, salt);
      final box = SecretBox.fromConcatenation(bytes.sublist(20), nonceLength: 12, macLength: 16);
      final clear = await _algo.decrypt(box, secretKey: k);
      final j = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
      _m.clear();
      j.forEach((key, v) {
        if (v is List) {
          _m[key] = List<String>.from(v);
        } else if (v is String || v is int || v is double || v is bool) {
          _m[key] = v as Object;
        }
      });
      _m['_migrated'] = true;
      await secure.write(key: 'cloud_key', value: base64Encode(await k.extractBytes()));
      await secure.write(key: 'cloud_salt', value: base64Encode(salt));
      _cloudKey = k;
      _cloudSalt = salt;
      await _flush();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _writeCloud(String json) async {
    final k = _cloudKey, s = _cloudSalt;
    if (k == null || s == null) return;
    try {
      final box = await _algo.encrypt(utf8.encode(json), secretKey: k);
      await disk.write(_cloudName, [..._magic, ...s, ...box.concatenation()]);
    } catch (_) {}
  }

  /// Erases everything, including the key and any app lock. Used by "forgot PIN".
  static Future<void> wipeEverything() async {
    try {
      await deleteCloudFile();
      for (final n in ['store.enc', 'store.enc.tmp', 'store.enc.unreadable']) {
        await disk.delete(n);
      }
    } catch (_) {}
    try {
      await secure.deleteAll();
    } catch (_) {}
    try {
      final old = await SharedPreferences.getInstance();
      await old.clear();
    } catch (_) {}
    _opening = null;
  }

  String? getString(String k) {
    final v = _m[k];
    return v is String ? v : null;
  }

  int? getInt(String k) {
    final v = _m[k];
    return v is int ? v : (v is double ? v.toInt() : null);
  }

  double? getDouble(String k) {
    final v = _m[k];
    return v is num ? v.toDouble() : null;
  }

  bool? getBool(String k) {
    final v = _m[k];
    return v is bool ? v : null;
  }

  List<String>? getStringList(String k) {
    final v = _m[k];
    return v is List<String> ? List<String>.from(v) : null;
  }

  Set<String> getKeys() => _m.keys.where((k) => k != '_migrated').toSet();
  bool containsKey(String k) => _m.containsKey(k);

  Future<bool> setString(String k, String v) => _set(k, v);
  Future<bool> setInt(String k, int v) => _set(k, v);
  Future<bool> setDouble(String k, double v) => _set(k, v);
  Future<bool> setBool(String k, bool v) => _set(k, v);
  Future<bool> setStringList(String k, List<String> v) => _set(k, List<String>.from(v));
  Future<bool> remove(String k) {
    _m.remove(k);
    return _flush();
  }

  Future<bool> clear() {
    _m.clear();
    return _flush();
  }

  Future<bool> _set(String k, Object v) {
    _m[k] = v;
    return _flush();
  }

  Future<bool> _flush() {
    final snapshot = jsonEncode(_m);
    _writing = _writing.then((_) => _write(snapshot));
    return _writing.then((_) => true);
  }

  Future<void> _write(String json) async {
    try {
      final box = await _algo.encrypt(utf8.encode(json), secretKey: _key);
      await disk.write(_main, box.concatenation());
    } catch (_) {}
    await _writeCloud(json);
  }
}
