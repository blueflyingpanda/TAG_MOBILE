import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';

/// Local persistence. The auth token lives in the platform keystore; everything
/// else is non-sensitive and goes to shared preferences.
///
/// Values are loaded once at startup ([init]) so reads are synchronous, which
/// lets the router decide the first screen without a loading flash.
class AppStorage {
  AppStorage._(this._prefs, this._secure, this._token);

  static const _tokenKey = 'auth_token';
  static const _gameStateKey = 'tag_game_state';
  static const _gameIdKey = 'tag_current_game_id';
  static const _anonIdKey = 'tag_anon_id';
  static const _localGameIdKey = 'tag_current_local_game_id';
  static const _localeKey = 'tag_locale';
  static const _themeModeKey = 'tag_theme';

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;
  String? _token;

  static Future<AppStorage> init() async {
    final prefs = await SharedPreferences.getInstance();
    const secure = FlutterSecureStorage();
    String? token;
    try {
      token = await secure.read(key: _tokenKey);
    } catch (_) {
      // Keystore can be invalidated (e.g. after a backup restore); treat as logged out.
      await secure.deleteAll();
    }
    return AppStorage._(prefs, secure, token);
  }

  String? get token => _token;

  Future<void> setToken(String? token) async {
    _token = token;
    if (token == null) {
      await _secure.delete(key: _tokenKey);
    } else {
      await _secure.write(key: _tokenKey, value: token);
    }
  }

  GameState? get gameState {
    final raw = _prefs.getString(_gameStateKey);
    if (raw == null) return null;
    try {
      return GameState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> setGameState(GameState? state) => state == null
      ? _prefs.remove(_gameStateKey)
      : _prefs.setString(_gameStateKey, jsonEncode(state.toJson()));

  /// Server game id, or null when the game is local (see [localGameId]).
  int? get gameId => _prefs.getInt(_gameIdKey);

  Future<void> setGameId(int? id) =>
      id == null ? _prefs.remove(_gameIdKey) : _prefs.setInt(_gameIdKey, id);

  /// Row id in the local games DB for a guest/offline game awaiting upload.
  /// Random per-install id sent with every API request so the backend can
  /// tie guest activity together (analytics).
  String get anonId {
    final existing = _prefs.getString(_anonIdKey);
    if (existing != null) return existing;
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
    final hex = [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')].join();
    final id = '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
    _prefs.setString(_anonIdKey, id);
    return id;
  }

  int? get localGameId => _prefs.getInt(_localGameIdKey);

  Future<void> setLocalGameId(int? id) =>
      id == null ? _prefs.remove(_localGameIdKey) : _prefs.setInt(_localGameIdKey, id);

  String? get locale => _prefs.getString(_localeKey);
  Future<void> setLocale(String code) => _prefs.setString(_localeKey, code);

  /// 'light' | 'dark' | null (follow system)
  String? get themeMode => _prefs.getString(_themeModeKey);
  Future<void> setThemeMode(String mode) => _prefs.setString(_themeModeKey, mode);
}
