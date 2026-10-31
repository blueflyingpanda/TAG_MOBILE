import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// A game played as guest or offline, waiting to be uploaded after sign-in.
class LocalGame {
  const LocalGame({
    required this.id,
    required this.settings,
    required this.startedAt,
    required this.info,
    required this.guessed,
    required this.skipped,
    this.endedAt,
  });

  final int id;
  final GameSettings settings;
  final DateTime startedAt;
  final GameInfo info;
  final List<String> guessed;
  final List<String> skipped;
  final DateTime? endedAt;
}

/// SQLite store for [LocalGame]s. Word lists accumulate across rounds so a
/// game can be uploaded in one go.
class LocalGameStore {
  LocalGameStore._(this._db);

  static const _table = 'local_games';

  final Database _db;

  static Future<LocalGameStore> open() async {
    final db = await openDatabase(
      p.join(await getDatabasesPath(), 'tag_local.db'),
      version: 1,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE $_table (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          settings TEXT NOT NULL,
          started_at TEXT NOT NULL,
          info TEXT NOT NULL,
          words_guessed TEXT NOT NULL,
          words_skipped TEXT NOT NULL,
          ended_at TEXT
        )
      '''),
    );
    return LocalGameStore._(db);
  }

  Future<int> create(GameSettings s) => _db.insert(_table, {
        'settings': jsonEncode(s.toJson()),
        'started_at': DateTime.now().toUtc().toIso8601String(),
        'info': jsonEncode(GameInfo(
          teams: [for (final t in s.selectedTeams) TeamScore(t, 0)],
          currentTeamIndex: 0,
          currentRound: 0,
        ).toJson()),
        'words_guessed': '[]',
        'words_skipped': '[]',
      });

  Future<void> update(int id, GameState state, List<WordResult> roundResults, {bool ended = false}) async {
    final rows = await _db.query(_table, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;
    List<String> words(String col) => [for (final w in jsonDecode(rows.first[col] as String) as List) w as String];
    final guessed = [...words('words_guessed'), for (final r in roundResults) if (r.guessed) r.word];
    final skipped = [...words('words_skipped'), for (final r in roundResults) if (!r.guessed) r.word];
    await _db.update(
      _table,
      {
        'info': jsonEncode(GameInfo(
          teams: [for (final e in state.teamScores.entries) TeamScore(e.key, e.value)],
          currentTeamIndex: state.currentTeamIndex,
          currentRound: state.currentRound,
        ).toJson()),
        'words_guessed': jsonEncode(guessed),
        'words_skipped': jsonEncode(skipped),
        if (ended) 'ended_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<LocalGame>> all() async {
    final rows = await _db.query(_table, orderBy: 'id');
    return [
      for (final r in rows)
        LocalGame(
          id: r['id'] as int,
          settings: GameSettings.fromJson(jsonDecode(r['settings'] as String) as Map<String, dynamic>),
          startedAt: DateTime.parse(r['started_at'] as String),
          info: GameInfo.fromJson(jsonDecode(r['info'] as String) as Map<String, dynamic>),
          guessed: [for (final w in jsonDecode(r['words_guessed'] as String) as List) w as String],
          skipped: [for (final w in jsonDecode(r['words_skipped'] as String) as List) w as String],
          endedAt: r['ended_at'] == null ? null : DateTime.parse(r['ended_at'] as String),
        ),
    ];
  }

  Future<void> delete(int id) => _db.delete(_table, where: 'id = ?', whereArgs: [id]);
}
