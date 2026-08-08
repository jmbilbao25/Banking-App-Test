import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// The on device key value store described in the glossary as Persistence_Store.
///
/// Reads are synchronous and writes are asynchronous on purpose. Riverpod's
/// `Notifier.build` is synchronous, so a controller has to be able to hydrate
/// its first state without awaiting. The concrete implementation therefore loads
/// everything into memory once during [openPersistenceStore] and serves reads
/// from that cache, which also means the first frame never shows a default theme
/// before flipping to the stored one.
abstract interface class PersistenceStore {
  String? readString(String key);
  bool? readBool(String key);
  int? readInt(String key);

  Future<void> writeString(String key, String value);
  Future<void> writeBool(String key, bool value);
  Future<void> writeInt(String key, int value);

  Future<void> remove(String key);

  /// Removes every key under [prefix]. Used by logout to drop a whole namespace
  /// without naming each key.
  Future<void> removeNamespace(String prefix);

  /// Convenience for the JSON blobs the snapshot and preference namespaces use.
  Map<String, Object?>? readJson(String key);
  Future<void> writeJson(String key, Map<String, Object?> value);
}

/// Every key the application persists, in one place so namespaces cannot drift.
abstract final class StoreKeys {
  static const _root = 'frostbank';

  static const preferencesNamespace = '$_root.preferences';
  static const themeMode = '$preferencesNamespace.theme_mode';
  static const balancesHidden = '$preferencesNamespace.balances_hidden';
  static const currencyCode = '$preferencesNamespace.currency_code';
  static const rememberedEmail = '$preferencesNamespace.remembered_email';
  static const sessionTimeoutSeconds =
      '$preferencesNamespace.session_timeout_seconds';
  static const biometricUnlock = '$preferencesNamespace.biometric_unlock';

  /// Security namespace. Cleared wholesale on logout, per requirement 5.10.
  static const securityNamespace = '$_root.security';
  static const pinDigest = '$securityNamespace.pin_digest';
  static const pinSalt = '$securityNamespace.pin_salt';
  static const pinAttempts = '$securityNamespace.pin_attempts';
  static const session = '$securityNamespace.session';
  static const lastBackgroundedAt = '$securityNamespace.last_backgrounded_at';

  /// Mock data set namespace, holding the snapshot requirement 6.7 reloads.
  static const dataNamespace = '$_root.data';
  static const dataSnapshot = '$dataNamespace.snapshot';
  static const splitBillsSnapshot = '$dataNamespace.split_bills';
}

/// Opens the real store. Called once from `main` before `runApp`.
Future<PersistenceStore> openPersistenceStore() async =>
    _SharedPreferencesStore(await SharedPreferences.getInstance());

class _SharedPreferencesStore implements PersistenceStore {
  _SharedPreferencesStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  String? readString(String key) => _prefs.getString(key);

  @override
  bool? readBool(String key) => _prefs.getBool(key);

  @override
  int? readInt(String key) => _prefs.getInt(key);

  @override
  Future<void> writeString(String key, String value) =>
      _prefs.setString(key, value);

  @override
  Future<void> writeBool(String key, bool value) => _prefs.setBool(key, value);

  @override
  Future<void> writeInt(String key, int value) => _prefs.setInt(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);

  @override
  Future<void> removeNamespace(String prefix) async {
    final doomed = _prefs
        .getKeys()
        .where((key) => key.startsWith(prefix))
        .toList(growable: false);
    for (final key in doomed) {
      await _prefs.remove(key);
    }
  }

  @override
  Map<String, Object?>? readJson(String key) => _decodeJson(readString(key));

  @override
  Future<void> writeJson(String key, Map<String, Object?> value) =>
      writeString(key, jsonEncode(value));
}

/// In memory store used by tests and by any build where the platform channel is
/// unavailable. Behaves identically, minus durability.
class InMemoryPersistenceStore implements PersistenceStore {
  InMemoryPersistenceStore([Map<String, Object>? seed])
    : _values = {...?seed};

  final Map<String, Object> _values;

  @override
  String? readString(String key) {
    final value = _values[key];
    return value is String ? value : null;
  }

  @override
  bool? readBool(String key) {
    final value = _values[key];
    return value is bool ? value : null;
  }

  @override
  int? readInt(String key) {
    final value = _values[key];
    return value is int ? value : null;
  }

  @override
  Future<void> writeString(String key, String value) async =>
      _values[key] = value;

  @override
  Future<void> writeBool(String key, bool value) async => _values[key] = value;

  @override
  Future<void> writeInt(String key, int value) async => _values[key] = value;

  @override
  Future<void> remove(String key) async => _values.remove(key);

  @override
  Future<void> removeNamespace(String prefix) async =>
      _values.removeWhere((key, _) => key.startsWith(prefix));

  @override
  Map<String, Object?>? readJson(String key) => _decodeJson(readString(key));

  @override
  Future<void> writeJson(String key, Map<String, Object?> value) =>
      writeString(key, jsonEncode(value));
}

/// A snapshot written by an older build, or a partial write interrupted by a
/// crash, must never stop the application from launching. A blob that does not
/// decode is treated as absent so the caller reseeds.
Map<String, Object?>? _decodeJson(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map<String, Object?> ? decoded : null;
  } on FormatException {
    return null;
  }
}
