import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tag/data/auth.dart';
import 'package:tag/data/models.dart';
import 'package:tag/features/themes/import_theme_sheet.dart';
import 'package:tag/game/game_logic.dart';

GameTheme _theme({Map<String, int>? words}) => GameTheme(
      id: 1,
      name: 'Test',
      language: 'en',
      isPublic: true,
      verified: true,
      description: ThemeDescription(
        words: words ?? {for (var i = 0; i < 40; i++) 'w$i': i < 30 ? 1 : 3},
        teams: const ['A', 'B', 'C'],
      ),
    );

GameState _game({bool skipPenalty = true, int points = 5, List<String> teams = const ['A', 'B']}) =>
    initializeGameState(GameSettings(
      theme: _theme(),
      selectedTeams: teams,
      difficulty: 1,
      pointsRequired: points,
      roundTimer: 60,
      skipPenalty: skipPenalty,
    ));

void main() {
  test('availableWords filters by difficulty and used words', () {
    final words = availableWords(_theme(), const ['w0', 'w1'], 1);
    expect(words.length, 28);
    expect(words, isNot(contains('w0')));
    expect(availableWords(_theme(), const [], 3).length, 40);
  });

  test('confirmRound scores with skip penalty and passes the turn', () {
    final out = confirmRound(_game(points: 50), const [
      WordResult('w0', true),
      WordResult('w1', true),
      WordResult('w2', false),
    ]);
    expect(out.gameOver, isFalse);
    expect(out.state.teamScores['A'], 1);
    expect(out.state.currentTeamIndex, 1);
    expect(out.state.currentRound, 1);
    expect(out.state.wordsUsed, containsAll(['w0', 'w1', 'w2']));
  });

  test('no skip penalty and last word credit', () {
    final out = confirmRound(
      _game(skipPenalty: false, points: 50),
      const [WordResult('w0', true), WordResult('w1', false)],
      lastWord: 'w5',
      lastWordGuessed: true,
    );
    expect(out.state.teamScores['A'], 2);
    expect(out.resultsForApi.last.word, 'w5');
    expect(out.state.wordsUsed, contains('w5'));
  });

  test('round increments after the last team plays', () {
    var s = advanceTeam(_game());
    expect(s.currentRound, 1);
    s = advanceTeam(s);
    expect(s.currentTeamIndex, 0);
    expect(s.currentRound, 2);
  });

  test('reaching the target ends the game without passing the turn', () {
    final out = confirmRound(_game(points: 2), const [WordResult('w0', true), WordResult('w1', true)]);
    expect(out.gameOver, isTrue);
    expect(checkWinCondition(out.state), ['A']);
    expect(out.state.currentTeamIndex, 0);
  });

  test('exhausted deck: top score wins, ties included', () {
    final s = _game(points: 100).copyWith(
      wordsUsed: [for (var i = 0; i < 30; i++) 'w$i'],
      teamScores: {'A': 4, 'B': 4},
    );
    expect(winners(s), ['A', 'B']);
  });

  test('cheating = more guesses than whole seconds elapsed', () {
    expect(isCheating(3, const Duration(milliseconds: 2900)), isTrue);
    expect(isCheating(2, const Duration(seconds: 2)), isFalse);
  });

  test('GameState survives a JSON round trip', () {
    final s = _game().copyWith(roundResults: const [WordResult('w0', true)], lastWord: 'w9');
    final back = GameState.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
    expect(back.lastWord, 'w9');
    expect(back.roundResults.single.word, 'w0');
    expect(back.settings.theme.description.words.length, 40);
    expect(back.copyWith(lastWord: null).lastWord, isNull);
  });

  test('userFromToken decodes payload and rejects expired tokens', () {
    String jwt(Map<String, dynamic> p) =>
        'h.${base64Url.encode(utf8.encode(jsonEncode(p))).replaceAll('=', '')}.s';
    final exp = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
    final u = userFromToken(jwt({'user_id': 7, 'email': 'jo@x.com', 'admin': false, 'exp': exp}));
    expect(u?.id, '7');
    expect(u?.username, 'jo');
    expect(userFromToken(jwt({'user_id': 7, 'admin': false, 'exp': 1})), isNull);
    expect(userFromToken('garbage'), isNull);
  });

  group('parseImportedTheme', () {
    Map<String, dynamic> base({List<String>? teams, Object? words}) => {
          'name': 'T',
          'language': 'en',
          'description': {
            'teams': teams ?? [for (var i = 0; i < 10; i++) 'Team $i'],
            'words': words ?? [for (var i = 0; i < 30; i++) 'word$i'],
          },
        };

    test('accepts list words and normalizes to difficulty map', () {
      final p = parseImportedTheme(jsonEncode(base()), isPublic: false);
      expect(p['public'], isFalse);
      expect((p['description']['words'] as Map)['word0'], {'difficulty': 1});
    });

    test('rejects wrong team count and duplicate words', () {
      expect(() => parseImportedTheme(jsonEncode(base(teams: ['a'])), isPublic: true),
          throwsA(isA<FormatException>()));
      final dupWords = [...List.generate(30, (i) => 'w$i'), 'W0'];
      expect(
        () => parseImportedTheme(jsonEncode(base(words: dupWords)), isPublic: true),
        throwsA(predicate((e) => e is FormatException && e.message.contains('"w0"'))),
      );
    });
  });
}
