import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../core/config.dart';
import 'models.dart';

const _appVersion = String.fromEnvironment('APP_VERSION');

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;

  @override
  String toString() => message;
}

/// Thin wrapper over the TAG REST API (see TAG_API/src/api).
class Api {
  Api({
    required String? Function() token,
    required String Function() anonId,
    required void Function() onUnauthorized,
  })
      : _dio = Dio(BaseOptions(
          baseUrl: apiBase,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final t = token();
        if (t != null) options.headers['Authorization'] = 'Bearer $t';
        options.headers['X-Anon-Id'] = anonId();
        options.headers['X-Platform'] = Platform.operatingSystem;
        if (_appVersion.isNotEmpty) options.headers['X-App-Version'] = _appVersion;
        handler.next(options);
      },
      onError: (e, handler) {
        if (e.response?.statusCode == 401) onUnauthorized();
        handler.next(e);
      },
    ));
  }

  final Dio _dio;

  Future<T> _call<T>(Future<Response<dynamic>> Function() request, T Function(dynamic) parse,
      {required String action}) async {
    try {
      final res = await request();
      return parse(res.data);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      throw ApiException(
        code == null ? 'Network error — check your connection' : 'Failed to $action ($code)',
        statusCode: code,
      );
    }
  }

  /// Fire-and-forget usage event; never throws or blocks the UI.
  void trackEvent(String name, [Map<String, Object?> props = const {}]) {
    _dio.post<void>('/events', data: {'name': name, 'props': props}).then((_) {}, onError: (_) {});
  }

  // Auth

  Future<String> exchangeGoogleIdToken(String idToken) => _call(
        () => _dio.post(googleNativeAuthUrl, data: {'id_token': idToken}),
        (d) => (d as Map)['token'] as String,
        action: 'sign in',
      );

  /// Permanently deletes the signed-in account (DELETE /auth/me).
  Future<void> deleteAccount() => _call(
        () => _dio.delete('/auth/me'),
        (_) {},
        action: 'delete account',
      );

  // Themes

  Future<Paginated<ThemeListItem>> getThemes({
    int page = 1,
    int size = 50,
    String? language,
    String? name,
    bool? mine,
    bool? verified,
    bool? favourites,
    String? order,
    bool? descending,
  }) =>
      _call(
        () => _dio.get('/themes/', queryParameters: {
          'page': page,
          'size': size,
          'language': ?language,
          'name': ?name,
          'mine': ?mine,
          'verified': ?verified,
          'favourites': ?favourites,
          'order': ?order,
          'descending': ?descending,
        }),
        (d) => Paginated.fromJson(d as Map<String, dynamic>, ThemeListItem.fromJson),
        action: 'fetch themes',
      );

  Future<GameTheme> getTheme(int id) => _call(
        () => _dio.get('/themes/$id'),
        (d) => GameTheme.fromJson(d as Map<String, dynamic>),
        action: 'fetch theme',
      );

  Future<GameTheme> createTheme(Map<String, dynamic> payload) => _call(
        () => _dio.post('/themes/', data: payload),
        (d) => GameTheme.fromJson(d as Map<String, dynamic>),
        action: 'create theme',
      );

  /// Replaces name/summary/words/teams. Does not affect visibility.
  Future<GameTheme> updateTheme(
    int id, {
    required String name,
    required String summary,
    required ThemeDescription description,
  }) =>
      _call(
        () => _dio.put('/themes/$id', data: {'name': name, 'summary': summary, 'description': description.toJson()}),
        (d) => GameTheme.fromJson(d as Map<String, dynamic>),
        action: 'update theme',
      );

  Future<GameTheme> setThemeVisibility(int id, bool isPublic) => _call(
        () => _dio.patch('/themes/$id', data: {'public': isPublic}),
        (d) => GameTheme.fromJson(d as Map<String, dynamic>),
        action: 'update visibility',
      );

  /// Server crops to 16:9, resizes to 640x360 WebP (<= 256 KB). 413: over 5 MB, 422: not an image.
  Future<GameTheme> uploadCoverImage(int id, Uint8List bytes, String filename) => _call(
        () => _dio.put(
          '/themes/$id/cover-image',
          data: FormData.fromMap({'file': MultipartFile.fromBytes(bytes, filename: filename)}),
          options: Options(sendTimeout: const Duration(seconds: 60)),
        ),
        (d) => GameTheme.fromJson(d as Map<String, dynamic>),
        action: 'upload cover image',
      );

  Future<void> deleteCoverImage(int id) => _call(
        () => _dio.delete('/themes/$id/cover-image'),
        (_) {},
        action: 'delete cover image',
      );

  Future<void> setFavourite(int id, bool favourite) => _call(
        () => favourite
            ? _dio.post('/themes/$id/favourite')
            : _dio.delete('/themes/$id/favourite'),
        (_) {},
        action: 'update favourite',
      );

  // Games

  Future<Paginated<GameListItem>> getGames({int page = 1, int size = 50}) => _call(
        () => _dio.get('/games/', queryParameters: {
          'page': page,
          'size': size,
          'order': 'id',
          'descending': true,
        }),
        (d) => Paginated.fromJson(d as Map<String, dynamic>, GameListItem.fromJson),
        action: 'load games',
      );

  Future<GameDetails> getGame(int id) => _call(
        () => _dio.get('/games/$id'),
        (d) => GameDetails.fromJson(d as Map<String, dynamic>),
        action: 'load game',
      );

  Future<int> createGame(GameSettings s, {DateTime? startedAt}) => _call(
        () => _dio.post('/games/', data: {
          'theme_id': s.theme.id,
          'difficulty': s.difficulty,
          'started_at': (startedAt ?? DateTime.now()).toUtc().toIso8601String(),
          'ended_at': null,
          'points': s.pointsRequired,
          'round': s.roundTimer,
          'skip_penalty': s.skipPenalty,
          'info': GameInfo(
            teams: [for (final t in s.selectedTeams) TeamScore(t, 0)],
            currentTeamIndex: 0,
            currentRound: 0,
          ).toJson(),
        }),
        (d) => ((d as Map)['id'] as num).toInt(),
        action: 'create game',
      );

  /// The server merges word lists, so send only this round's results.
  Future<void> updateGame(int id, GameState state, List<WordResult> roundResults, {bool ended = false}) =>
      putGame(
        id,
        info: GameInfo(
          teams: [for (final e in state.teamScores.entries) TeamScore(e.key, e.value)],
          currentTeamIndex: state.currentTeamIndex,
          currentRound: state.currentRound,
        ),
        guessed: [for (final r in roundResults) if (r.guessed) r.word],
        skipped: [for (final r in roundResults) if (!r.guessed) r.word],
        endedAt: ended ? DateTime.now() : null,
      );

  Future<void> putGame(
    int id, {
    required GameInfo info,
    required List<String> guessed,
    required List<String> skipped,
    DateTime? endedAt,
  }) =>
      _call(
        () => _dio.put('/games/$id', data: {
          'info': info.toJson(),
          'words_guessed': guessed,
          'words_skipped': skipped,
          if (endedAt != null) 'ended_at': endedAt.toUtc().toIso8601String(),
        }),
        (_) {},
        action: 'update game',
      );
}
