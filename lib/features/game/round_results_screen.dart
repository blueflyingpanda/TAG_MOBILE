import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../game/game_logic.dart';
import '../../state/providers.dart';
import '../../ui/widgets.dart';

class RoundResultsScreen extends ConsumerStatefulWidget {
  const RoundResultsScreen({super.key});

  @override
  ConsumerState<RoundResultsScreen> createState() => _RoundResultsScreenState();
}

class _RoundResultsScreenState extends ConsumerState<RoundResultsScreen> {
  late final List<WordResult> _results = [...?ref.read(gameProvider)?.roundResults];
  bool _lastWordGuessed = false;

  void _toggle(int i) {
    HapticFeedback.selectionClick();
    setState(() => _results[i] = _results[i].toggled());
  }

  void _confirm() {
    HapticFeedback.mediumImpact();
    ref.read(gameProvider.notifier).confirmRound(_results, _lastWordGuessed);
    context.go('/play');
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.colors;
    final game = ref.watch(gameProvider);
    if (game == null) return const SizedBox.shrink();

    final lastWord = game.lastWord;
    final baseGuessed = _results.where((r) => r.guessed).length;
    final skipped = _results.length - baseGuessed;
    final guessed = baseGuessed + (_lastWordGuessed ? 1 : 0);
    final earned =
        earnedPoints(_results, skipPenalty: game.settings.skipPenalty, lastWordGuessed: _lastWordGuessed);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          children: [
                            Text(t.rr_title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text(t.rr_hint, textAlign: TextAlign.center, style: TextStyle(color: c.textA(0.6))),
                            if (_results.isEmpty) ...[
                              const SizedBox(height: 12),
                              Text(t.rr_noWords, style: TextStyle(color: c.textA(0.6))),
                            ],
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _Stat(value: '$guessed', label: t.rr_guessed, color: c.success),
                                _Stat(
                                  value: '⭐ $earned',
                                  label: t.rr_earned,
                                  color: earned > 0 ? c.success : (earned < 0 ? c.error : c.textA(0.8)),
                                  pulse: true,
                                ),
                                _Stat(value: '$skipped', label: t.rr_skipped, color: c.error),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => _WordRow(
                          word: _results[i].word,
                          state: _results[i].guessed ? true : false,
                          onTap: () => _toggle(i),
                        ),
                      ),
                    ),
                    if (lastWord != null)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.rr_lastWord, style: TextStyle(fontSize: 13, color: c.textA(0.5))),
                              const SizedBox(height: 8),
                              _WordRow(
                                word: lastWord,
                                state: _lastWordGuessed ? true : null,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _lastWordGuessed = !_lastWordGuessed);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: GameButton(label: t.rr_confirm, onPressed: _confirm),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.color, this.pulse = false});

  final String value;
  final String label;
  final Color color;
  final bool pulse;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          TweenAnimationBuilder<double>(
            key: ValueKey(value),
            tween: Tween(begin: pulse ? 1.25 : 0.6, end: 1),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            builder: (context, s, child) => Transform.scale(scale: s, child: child),
            child: Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: color)),
          ),
          Text(label, style: TextStyle(fontSize: 13, color: context.colors.textA(0.6))),
        ],
      );
}

/// A tappable word row. [state]: true = guessed, false = skipped, null = unset.
class _WordRow extends StatelessWidget {
  const _WordRow({required this.word, required this.state, required this.onTap});

  final String word;
  final bool? state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (bg, border, emoji) = switch (state) {
      true => (c.success.withValues(alpha: 0.15), c.success.withValues(alpha: 0.3), '✅'),
      false => (c.error.withValues(alpha: 0.10), c.error.withValues(alpha: 0.3), '❌'),
      null => (c.textA(0.05), c.textA(0.1), '❓'),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Color.alphaBlend(bg, c.card),
        borderRadius: gameBorderRadius,
        border: Border.all(color: border),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: gameBorderRadius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    word,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: state == null ? c.textA(0.6) : c.text,
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                  child: Text(emoji, key: ValueKey(emoji), style: const TextStyle(fontSize: 22)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
