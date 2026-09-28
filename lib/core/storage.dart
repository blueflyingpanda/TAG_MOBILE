import 'dart:convert';

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

  /// Server game id, or null for a game that couldn't be created on the server.
  int? get gameId => _prefs.getInt(_gameIdKey);

  Future<void> setGameId(int? id) =>
      id == null ? _prefs.remove(_gameIdKey) : _prefs.setInt(_gameIdKey, id);

  String? get locale => _prefs.getString(_localeKey);
  Future<void> setLocale(String code) => _prefs.setString(_localeKey, code);

  /// 'light' | 'dark' | null (follow system)
  String? get themeMode => _prefs.getString(_themeModeKey);
  Future<void> setThemeMode(String mode) => _prefs.setString(_themeModeKey, mode);
}
