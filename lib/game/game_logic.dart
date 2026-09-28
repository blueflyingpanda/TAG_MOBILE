// Pure game rules, ported from TAG/src/utils/game.ts and App.tsx.
import 'dart:math';

import '../data/models.dart';

List<String> availableWords(GameTheme theme, List<String> wordsUsed, int maxDifficulty) {
  final used = wordsUsed.toSet();
  return [
    for (final e in theme.description.words.entries)
      if (!used.contains(e.key) && e.value <= maxDifficulty) e.key,
  ];
}

List<T> shuffled<T>(List<T> list, [Random? random]) => [...list]..shuffle(random);

GameState initializeGameState(GameSettings settings) => GameState(
      settings: settings,
      currentTeamIndex: 0,
      currentRound: 1,
      teamScores: {for (final t in settings.selectedTeams) t: 0},
      wordsUsed: const [],
    );

List<String> _topTeams(Map<String, int> scores) {
  if (scores.isEmpty) return const [];
  final maxScore = scores.values.reduce(max);
  return [for (final e in scores.entries) if (e.value == maxScore) e.key];
}

/// Teams that reached the target score (ties included).
List<String> checkWinCondition(GameState state) {
  if (state.teamScores.isEmpty) return const [];
  final maxScore = state.teamScores.values.reduce(max);
  if (maxScore < state.settings.pointsRequired) return const [];
  return _topTeams(state.teamScores);
}

/// Winners by target score, or — when the deck is exhausted — by top score.
List<String> winners(GameState state) {
  final byTarget = checkWinCondition(state);
  if (byTarget.isNotEmpty) return byTarget;
  final remaining =
      availableWords(state.settings.theme, state.wordsUsed, state.settings.difficulty);
  return remaining.isEmpty ? _topTeams(state.teamScores) : const [];
}

/// Cheating if more words were guessed than whole seconds elapsed.
bool isCheating(int guessedCount, Duration elapsed) => guessedCount > elapsed.inSeconds;

GameState advanceTeam(GameState state) {
  final next = (state.currentTeamIndex + 1) % state.settings.selectedTeams.length;
  return state.copyWith(
    currentTeamIndex: next,
    currentRound: next == 0 ? state.currentRound + 1 : state.currentRound,
    roundResults: const [],
    lastWord: null,
  );
}

class ConfirmOutcome {
  const ConfirmOutcome(this.state, this.resultsForApi, this.gameOver);

  final GameState state;
  final List<WordResult> resultsForApi;
  final bool gameOver;
}

/// Applies confirmed round results: scores the current team, marks words used,
/// then either ends the game or passes the turn.
ConfirmOutcome confirmRound(
  GameState state,
  List<WordResult> results, {
  String? lastWord,
  bool lastWordGuessed = false,
}) {
  var scoreChange = 0;
  for (final r in results) {
    if (r.guessed) {
      scoreChange += 1;
    } else if (state.settings.skipPenalty) {
      scoreChange -= 1;
    }
  }

  final wordsUsed = [...state.wordsUsed];
  final resultsForApi = [...results];
  if (lastWordGuessed && lastWord != null) {
    scoreChange += 1;
    wordsUsed.add(lastWord);
    resultsForApi.add(WordResult(lastWord, true));
  }
  wordsUsed.addAll(results.map((r) => r.word));

  final scores = {...state.teamScores};
  scores[state.currentTeam] = (scores[state.currentTeam] ?? 0) + scoreChange;

  final scored = state.copyWith(teamScores: scores, wordsUsed: wordsUsed);
  if (checkWinCondition(scored).isNotEmpty) {
    return ConfirmOutcome(
        scored.copyWith(roundResults: const [], lastWord: null), resultsForApi, true);
  }
  return ConfirmOutcome(advanceTeam(scored), resultsForApi, false);
}

/// Earned points preview on the round results screen.
int earnedPoints(List<WordResult> results, {required bool skipPenalty, bool lastWordGuessed = false}) {
  final guessed = results.where((r) => r.guessed).length;
  final skipped = results.length - guessed;
  return (skipPenalty ? guessed - skipped : guessed) + (lastWordGuessed ? 1 : 0);
}
