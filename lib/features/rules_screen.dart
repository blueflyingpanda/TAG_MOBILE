import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../state/providers.dart';
import '../ui/widgets.dart';
import 'profile_sheet.dart';

class RulesScreen extends ConsumerWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final c = context.colors;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.medium(
            title: Text(t.rules_title),
            actions: const [ProfileButton(), SizedBox(width: 8)],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList.list(
              children: [
                _Section(
                  title: t.rules_basicGameplay,
                  children: [
                    // rules_intro already starts with "Alias"; bold that word rather than prefixing another.
                    Text.rich(TextSpan(children: [
                      if (t.rules_intro.startsWith('Alias')) ...[
                        const TextSpan(text: 'Alias', style: TextStyle(fontWeight: FontWeight.w700)),
                        TextSpan(text: t.rules_intro.substring('Alias'.length)),
                      ] else
                        TextSpan(text: t.rules_intro),
                    ])),
                    const SizedBox(height: 8),
                    for (final r in [t.rules_rule1, t.rules_rule2, t.rules_rule3, t.rules_rule4, t.rules_rule5, t.rules_rule6])
                      _Bullet(r),
                  ],
                ),
                _Section(
                  title: t.rules_scoring,
                  children: [for (final s in [t.rules_score1, t.rules_score2, t.rules_score3, t.rules_score4]) _BoldLead(s)],
                ),
                _Section(
                  title: t.rules_config,
                  children: [
                    _Labeled(t.rules_pointsRequired, t.rules_pointsDesc),
                    _Labeled(t.rules_roundTimer, t.rules_roundTimerDesc),
                    _Labeled(t.rules_skipPenalty, t.rules_skipPenaltyDesc),
                    _Labeled(t.rules_teamsLabel, t.rules_teamsDesc),
                  ],
                ),
                _Section(
                  title: t.rules_themeManagement,
                  children: [
                    for (final f in [t.rules_feat1, t.rules_feat2, t.rules_feat3, t.rules_feat4, t.rules_feat5]) _BoldLead(f),
                  ],
                ),
                _Section(
                  title: t.rules_gameFeatures,
                  children: [
                    _Labeled(t.rules_gameHistory, t.rules_gameHistoryDesc),
                    _Labeled(t.rules_gameResumption, t.rules_gameResumptionDesc),
                    _Labeled(t.rules_cheatingDetection, t.rules_cheatingDetectionDesc),
                    _Labeled(t.rules_resultConfirmation, t.rules_resultConfirmationDesc),
                  ],
                ),
                _Section(
                  title: t.rules_howToPlay,
                  children: [
                    for (final (i, s) in [t.rules_step1, t.rules_step2, t.rules_step3, t.rules_step4, t.rules_step5, t.rules_step6].indexed)
                      _Bullet(s, marker: '${i + 1}.'),
                  ],
                ),
                _Section(
                  title: t.rules_difficultyLevels,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Level(t.rules_veryEasy, c.success, 0.15),
                        _Level(t.rules_easy, c.success, 0.25),
                        _Level(t.rules_medium, c.text, 0.10),
                        _Level(t.rules_hard, c.error, 0.20),
                        _Level(t.rules_veryHard, c.error, 0.15),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GameCard(
          child: DefaultTextStyle.merge(
            style: TextStyle(color: context.colors.textA(0.85), height: 1.4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: context.colors.success)),
                const SizedBox(height: 10),
                ...children,
              ],
            ),
          ),
        ),
      );
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text, {this.marker = '•'});

  final String text;
  final String marker;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 22, child: Text(marker)),
            Expanded(child: Text(text)),
          ],
        ),
      );
}

/// "Label: rest" with the label in bold (web splits on the first colon).
class _BoldLead extends StatelessWidget {
  const _BoldLead(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final i = text.indexOf(':');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: i < 0
          ? Text(text)
          : Text.rich(TextSpan(children: [
              TextSpan(text: text.substring(0, i + 1), style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: text.substring(i + 1)),
            ])),
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled(this.label, this.desc);

  final String label;
  final String desc;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: context.colors.text)),
            const SizedBox(height: 2),
            Text(desc, style: const TextStyle(fontSize: 14)),
          ],
        ),
      );
}

class _Level extends StatelessWidget {
  const _Level(this.label, this.color, this.alpha);

  final String label;
  final Color color;
  final double alpha;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: color.withValues(alpha: alpha), borderRadius: gameBorderRadius),
        child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      );
}
