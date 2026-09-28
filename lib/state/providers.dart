import 'dart:ui';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage.dart';
import '../data/api.dart';
import '../data/auth.dart';
import '../data/models.dart';
import '../game/game_logic.dart' as logic;
import '../i18n/translations.dart';

/// Overridden in main() with the instance loaded before runApp.
final storageProvider = Provider<AppStorage>((_) => throw UnimplementedError());

final apiProvider = Provider<Api>((ref) {
  final storage = ref.watch(storageProvider);
  return Api(
    token: () => storage.token,
    onUnauthorized: () => ref.read(authProvider.notifier).logout(),
  );
});

// ── Auth ────────────────────────────────────────────────────────────────────

class AuthNotifier extends Notifier<User?> {
  @override
  User? build() => userFromToken(ref.read(storageProvider).token);

  Future<void> signInWithGoogle() async {
    final idToken = await GoogleAuth.signIn();
    final token = await ref.read(apiProvider).exchangeGoogleIdToken(idToken);
    await ref.read(storageProvider).setToken(token);
    state = userFromToken(token);
  }

  Future<void> logout() async {
    if (state == null) return;
    state = null;
    await ref.read(storageProvider).setToken(null);
    await ref.read(gameProvider.notifier).clear();
    await GoogleAuth.signOut();
  }
}

final authProvider = NotifierProvider<AuthNotifier, User?>(AuthNotifier.new);

// ── Preferences ─────────────────────────────────────────────────────────────

class LocaleNotifier extends Notifier<String> {
  @override
  String build() {
    final stored = ref.read(storageProvider).locale;
    if (stored != null && locales.containsKey(stored)) return stored;
    final system = PlatformDispatcher.instance.locale.languageCode;
    return locales.containsKey(system) ? system : 'en';
  }

  void set(String code) {
    state = code;
    ref.read(storageProvider).setLocale(code);
  }

  void toggle() => set(state == 'en' ? 'ru' : 'en');
}

final localeProvider = NotifierProvider<LocaleNotifier, String>(LocaleNotifier.new);

final tProvider = Provider<Translations>((ref) => locales[ref.watch(localeProvider)]!);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => switch (ref.read(storageProvider).themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  void set(ThemeMode mode) {
    state = mode;
    ref.read(storageProvider).setThemeMode(mode == ThemeMode.dark ? 'dark' : 'light');
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

// ── Game ────────────────────────────────────────────────────────────────────

/// The game in progress (between rounds), persisted so it survives restarts.
/// Server sync is best-effort: gameplay never blocks on the network.
class GameNotifier extends Notifier<GameState?> {
  AppStorage get _storage => ref.read(storageProvider);
  Api get _api => ref.read(apiProvider);

  @override
  GameState? build() => _storage.gameState;

  void _set(GameState? s) {
    state = s;
    _storage.setGameState(s);
  }

  Future<void> start(GameSettings settings) async {
    int? id;
    try {
      id = await _api.createGame(settings);
    } catch (_) {
      // Offline: play locally, the game just won't show up in history.
    }
    await _storage.setGameId(id);
    _set(logic.initializeGameState(settings));
  }

  void resume(GameState s, int gameId) {
    _storage.setGameId(gameId);
    _set(s);
  }

  /// Round finished — hold results for confirmation.
  void endRound(List<WordResult> results, String? lastWord) {
    final s = state;
    if (s == null) return;
    if (results.isEmpty && lastWord == null) {
      // Nothing to confirm: pass the turn straight away.
      final next = logic.advanceTeam(s);
      _set(next);
      _sync(next, const []);
      return;
    }
    _set(s.copyWith(roundResults: results, lastWord: lastWord));
  }

  /// Returns true when the game is over.
  bool confirmRound(List<WordResult> results, bool lastWordGuessed) {
    final s = state;
    if (s == null) return false;
    final outcome =
        logic.confirmRound(s, results, lastWord: s.lastWord, lastWordGuessed: lastWordGuessed);
    _set(outcome.state);
    _sync(outcome.state, outcome.resultsForApi);
    return outcome.gameOver;
  }

  Future<void> finish() async {
    final s = state;
    final id = _storage.gameId;
    if (s != null && id != null) {
      try {
        await _api.updateGame(id, s, const [], ended: true);
      } catch (_) {}
    }
    await clear();
  }

  Future<void> clear() async {
    state = null;
    await _storage.setGameState(null);
    await _storage.setGameId(null);
  }

  void _sync(GameState s, List<WordResult> results) {
    final id = _storage.gameId;
    if (id == null) return;
    _api.updateGame(id, s, results).catchError((_) {});
  }
}

final gameProvider = NotifierProvider<GameNotifier, GameState?>(GameNotifier.new);
