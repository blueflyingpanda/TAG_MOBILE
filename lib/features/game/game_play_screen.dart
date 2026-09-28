import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../game/game_logic.dart';
import '../../state/providers.dart';
import '../../ui/widgets.dart';
import 'card_stack.dart';

/// Same cadence as the web deck: the next card rises 100ms into the exit.
const _cardAdvanceDelay = Duration(milliseconds: 100);

class GamePlayScreen extends ConsumerStatefulWidget {
  const GamePlayScreen({super.key});

  @override
  ConsumerState<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends ConsumerState<GamePlayScreen> {
  final _deck = GlobalKey<CardStackState>();

  // Per-round state (not persisted, as on web).
  bool _active = false;
  bool _ending = false;
  List<String> _roundWords = const [];
  int _wordIndex = 0;
  String? _currentWord;
  List<WordResult> _results = const [];
  bool _exiting = false;
  bool _cheating = false;
  bool _paused = false;
  bool _pausedOnce = false;

  /// Timer anchor; shifted on resume so the remaining time is preserved.
  DateTime? _timerStart;

  /// Real round start, for cheat detection.
  DateTime? _roundStart;
  int _remaining = 0;
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  GameState get _game => ref.read(gameProvider)!;

  int _computeRemaining() {
    final start = _timerStart;
    if (start == null) return _remaining;
    final ms = _game.settings.roundTimer * 1000 - DateTime.now().difference(start).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
    _tick();
  }

  void _tick() {
    if (!_active || _paused || _ending) return;
    final r = _computeRemaining();
    if (r != _remaining) {
      if (r > 0 && r <= 5) HapticFeedback.selectionClick();
      setState(() => _remaining = r);
    }
    if (r <= 0) _endRound(timedOut: true);
  }

  void _startRound() {
    final game = _game;
    final words = availableWords(game.settings.theme, game.wordsUsed, game.settings.difficulty);
    if (words.isEmpty) return;
    HapticFeedback.mediumImpact();
    final deck = shuffled(words);
    final now = DateTime.now();
    setState(() {
      _active = true;
      _ending = false;
      _roundWords = deck;
      _wordIndex = 0;
      _currentWord = deck.first;
      _results = const [];
      _cheating = false;
      _paused = false;
      _pausedOnce = false;
      _exiting = false;
      _timerStart = now;
      _roundStart = now;
      _remaining = game.settings.roundTimer;
    });
    WakelockPlus.enable();
    _startTicker();
  }

  void _endRound({bool timedOut = false}) {
    if (_ending) return;
    _ending = true;
    _ticker?.cancel();
    WakelockPlus.disable();
    if (timedOut) HapticFeedback.heavyImpact();

    final results = [..._results];
    final current = _currentWord;
    // Timed out with a word still on screen: offer it separately, no penalty.
    final lastWord = timedOut && current != null && !_cheating && !results.any((r) => r.word == current)
        ? current
        : null;

    setState(() {
      _active = false;
      _currentWord = null;
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      ref.read(gameProvider.notifier).endRound(results, lastWord);
      _ending = false;
      if (ref.read(gameProvider)?.hasPendingResults ?? false) context.go('/results');
    });
  }

  void _handleWord(bool guessed) {
    final word = _currentWord;
    if (word == null || _exiting || _cheating || _paused || !_active) return;
    setState(() => _exiting = true);
    _deck.currentState?.fling(guessed);

    Future.delayed(_cardAdvanceDelay, () {
      if (!mounted || _ending) return;
      final results = [..._results, WordResult(word, guessed)];
      final guessedCount = results.where((r) => r.guessed).length;

      if (isCheating(guessedCount, DateTime.now().difference(_roundStart!))) {
        HapticFeedback.vibrate();
        setState(() {
          _results = results;
          _cheating = true;
          _exiting = false;
          _currentWord = null;
        });
        return;
      }

      final next = _wordIndex + 1;
      if (next >= _roundWords.length) {
        setState(() {
          _results = results;
          _exiting = false;
        });
        _endRound();
        return;
      }
      setState(() {
        _results = results;
        _wordIndex = next;
        _currentWord = _roundWords[next];
        _exiting = false;
      });
    });
  }

  /// One pause per round; remaining words (incl. the current one) are
  /// reshuffled as a penalty.
  void _pause() {
    if (_pausedOnce || _cheating) return;
    _ticker?.cancel();
    final remaining = _computeRemaining();
    final done = _roundWords.sublist(0, _results.length);
    final rest = shuffled(_roundWords.sublist(_results.length));
    setState(() {
      _remaining = remaining;
      _roundWords = [...done, ...rest];
      _wordIndex = _results.length;
      _currentWord = rest.isEmpty ? null : rest.first;
      _paused = true;
      _pausedOnce = true;
      _timerStart = null;
    });
  }

  void _resume() {
    final elapsed = _game.settings.roundTimer - _remaining;
    setState(() {
      _paused = false;
      _timerStart = DateTime.now().subtract(Duration(seconds: elapsed));
    });
    _startTicker();
  }

  Future<void> _newGame() async {
    await ref.read(gameProvider.notifier).finish();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameProvider);
    if (game == null) return const SizedBox.shrink();

    final gameWinners = winners(game);
    final Widget body;
    if (gameWinners.isNotEmpty && !_active) {
      body = _GameOver(game: game, winners: gameWinners, onNewGame: _newGame);
    } else if (!_active && !_ending) {
      body = _RoundIntro(game: game, onStart: _startRound, onLeave: () => context.go('/'));
    } else {
      body = _activeRound(game);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Back is ignored mid-round so a stray gesture can't abandon it.
        if (_active || _ending) return;
        context.go('/');
      },
      child: Scaffold(
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: KeyedSubtree(
              key: ValueKey(gameWinners.isNotEmpty && !_active ? 'over' : (_active || _ending) ? 'round' : 'intro'),
              child: body,
            ),
          ),
        ),
      ),
    );
  }

  Widget _activeRound(GameState game) {
    final t = ref.watch(tProvider);
    final c = context.colors;
    final guessed = _results.where((r) => r.guessed).length;
    final skipped = _results.length - guessed;
    final backWord = !_ending && _active && !_paused && _wordIndex + 1 < _roundWords.length
        ? _roundWords[_wordIndex + 1]
        : null;

    Widget? overlay;
    if (_cheating) {
      overlay = DeckPlaceholder(emoji: '⚠️', title: t.cs_cheatingTitle, subtitle: t.cs_cheatingDesc, danger: true);
    } else if (_paused) {
      overlay = DeckPlaceholder(emoji: '⏸️', title: t.cs_pausedTitle, subtitle: t.cs_pausedDesc);
    }

    final banner = _cheating
        ? _Banner(text: t.gp_cheatingDetected, color: c.error)
        : _paused
            ? _Banner(text: t.gp_roundPaused, color: c.text)
            : null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(
            children: [
              Text(t.gp_round(game.currentRound), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const Spacer(),
              Flexible(
                child: Text(
                  game.currentTeam,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.success),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Countdown(seconds: _remaining, warning: _remaining <= 5 && _remaining > 0 && !_paused),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _CounterLabel(value: skipped, color: c.error, label: t.gp_skipped),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('${_results.length} / ${_roundWords.length}',
                  style: TextStyle(fontSize: 12, color: c.textA(0.6))),
            ),
            _CounterLabel(value: guessed, color: c.success, label: t.gp_guessed),
          ],
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, -0.3), end: Offset.zero).animate(a),
              child: child,
            ),
          ),
          child: banner ?? const SizedBox(height: 8),
        ),
        Expanded(
          child: Center(
            child: CardStack(
              key: _deck,
              index: _wordIndex,
              currentWord: _currentWord,
              backWord: backWord,
              locked: _exiting || _cheating || _paused,
              overlay: overlay,
              onSwipe: _handleWord,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: _paused
                ? GameButton(label: t.gp_resume, onPressed: _resume, expand: false)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: GameButton(
                              label: t.gp_skipBtn,
                              variant: ButtonVariant.error,
                              onPressed: _cheating ? null : () => _handleWord(false),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GameButton(
                              label: t.gp_guessedBtn,
                              onPressed: _cheating ? null : () => _handleWord(true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      GameButton(
                        label: '⏸️ ${_pausedOnce ? t.gp_paused : t.gp_pause}',
                        variant: ButtonVariant.muted,
                        expand: false,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        fontSize: 14,
                        onPressed: _cheating || _pausedOnce ? null : _pause,
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _CounterLabel extends StatelessWidget {
  const _CounterLabel({required this.value, required this.color, required this.label});

  final int value;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          RollingCounter(value: value, color: color),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: context.colors.textA(0.6))),
        ],
      );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      key: ValueKey(text),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: gameBorderRadius,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(text,
          textAlign: TextAlign.center, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14)),
    );
  }
}

class _RoundIntro extends ConsumerWidget {
  const _RoundIntro({required this.game, required this.onStart, required this.onLeave});

  final GameState game;
  final VoidCallback onStart;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final c = context.colors;
    final remaining = availableWords(game.settings.theme, game.wordsUsed, game.settings.difficulty).length;

    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: t.nav_home,
            onPressed: onLeave,
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _SpringIn(
                  child: GameCard(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        Text(t.gp_round(game.currentRound),
                            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(game.currentTeam,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: c.success)),
                        const SizedBox(height: 20),
                        Tile(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              Text(t.gp_currentScores,
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 12),
                              for (final e in game.teamScores.entries)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          e.key,
                                          style: TextStyle(
                                            fontWeight:
                                                e.key == game.currentTeam ? FontWeight.w700 : FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                      Text(t.gp_score(e.value, game.settings.pointsRequired),
                                          style: const TextStyle(fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(t.gp_wordsRemaining(remaining), style: TextStyle(color: c.textA(0.7))),
                        const SizedBox(height: 20),
                        GameButton(
                          label: t.gp_startRound,
                          fontSize: 20,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          onPressed: onStart,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GameOver extends ConsumerWidget {
  const _GameOver({required this.game, required this.winners, required this.onNewGame});

  final GameState game;
  final List<String> winners;
  final VoidCallback onNewGame;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final c = context.colors;
    final sorted = game.teamScores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _SpringIn(
              child: GameCard(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    const Text('🎉', style: TextStyle(fontSize: 52)),
                    const SizedBox(height: 8),
                    Text(t.gp_gameOver, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Text(
                      winners.length == 1 ? t.gp_singleWinner(winners.first) : t.gp_multipleWinners(winners.join(' & ')),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: c.success),
                    ),
                    const SizedBox(height: 20),
                    for (final e in sorted)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Tile(
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(e.key,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                              ),
                              Text('${e.value}',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.success)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: GameButton(label: t.gp_newGame, onPressed: onNewGame, expand: false),
        ),
      ],
    );
  }
}

/// Scale + fade entrance with a spring (web: initial scale 0.9 → 1).
class _SpringIn extends StatelessWidget {
  const _SpringIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutBack,
        child: child,
        builder: (context, v, child) => Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.9 + 0.1 * v, child: child),
        ),
      );
}
