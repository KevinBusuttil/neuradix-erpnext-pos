import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persisted connection + session configuration.
///
/// Values are kept in secure storage so the API token survives restarts and is
/// available while offline.
class AppConfig {
  AppConfig(this._storage);

  final FlutterSecureStorage _storage;

  static const _kSiteUrl = 'site_url';
  static const _kApiKey = 'api_key';
  static const _kApiSecret = 'api_secret';
  static const _kPosProfile = 'pos_profile';
  static const _kDeviceId = 'device_id';
  static const _kLastSnapshotAt = 'last_snapshot_at';

  Future<String?> get siteUrl => _storage.read(key: _kSiteUrl);
  Future<String?> get apiKey => _storage.read(key: _kApiKey);
  Future<String?> get apiSecret => _storage.read(key: _kApiSecret);
  Future<String?> get posProfile => _storage.read(key: _kPosProfile);
  Future<String?> get deviceId => _storage.read(key: _kDeviceId);
  Future<String?> get lastSnapshotAt => _storage.read(key: _kLastSnapshotAt);

  Future<void> setSite(String url) => _storage.write(key: _kSiteUrl, value: url);
  Future<void> setToken(String key, String secret) async {
    await _storage.write(key: _kApiKey, value: key);
    await _storage.write(key: _kApiSecret, value: secret);
  }

  Future<void> setPosProfile(String name) =>
      _storage.write(key: _kPosProfile, value: name);
  Future<void> setDeviceId(String id) =>
      _storage.write(key: _kDeviceId, value: id);
  Future<void> setLastSnapshotAt(String iso) =>
      _storage.write(key: _kLastSnapshotAt, value: iso);

  Future<bool> get isConfigured async {
    final url = await siteUrl;
    final key = await apiKey;
    return (url?.isNotEmpty ?? false) && (key?.isNotEmpty ?? false);
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _kApiKey);
    await _storage.delete(key: _kApiSecret);
  }
}
