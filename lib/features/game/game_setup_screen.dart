import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../ui/widgets.dart';

class GameSetupScreen extends ConsumerStatefulWidget {
  const GameSetupScreen({super.key, required this.theme});

  final GameTheme theme;

  @override
  ConsumerState<GameSetupScreen> createState() => _GameSetupScreenState();
}

class _GameSetupScreenState extends ConsumerState<GameSetupScreen> {
  late final List<String> _teams = widget.theme.description.teams;
  late final Set<String> _selected = {
    ?_teams.firstOrNull,
    if (_teams.length > 1) _teams[1],
  };
  int _difficulty = 3;
  double _points = 50;
  double _timer = 60;
  bool _skipPenalty = true;
  bool _starting = false;

  void _toggleTeam(String team) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selected.contains(team)) {
        if (_selected.length > 2) _selected.remove(team);
      } else if (_selected.length < 10) {
        _selected.add(team);
      }
    });
  }

  Future<void> _start() async {
    if (_selected.length < 2 || _starting) return;
    setState(() => _starting = true);
    // Play order = selection order (the set is insertion-ordered), as on web.
    final teams = _selected.toList();
    await ref.read(gameProvider.notifier).start(GameSettings(
          theme: widget.theme,
          selectedTeams: teams,
          difficulty: _difficulty.clamp(1, 5),
          pointsRequired: _points.round(),
          roundTimer: _timer.round().clamp(15, 120),
          skipPenalty: _skipPenalty,
        ));
    if (mounted) context.go('/play');
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.colors;
    final theme = widget.theme;

    return Scaffold(
      appBar: AppBar(title: Text(theme.name)),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                children: [
                  Text(
                    '${theme.description.words.length} words • ${theme.description.teams.length} teams available',
                    style: TextStyle(color: c.textA(0.6)),
                  ),
                  const SizedBox(height: 16),
                  GameCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionLabel(t.gs_selectTeams),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final team in _teams)
                              _TeamChip(
                                label: team,
                                selected: _selected.contains(team),
                                onTap: () => _toggleTeam(team),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(t.gs_selectedTeams(_selected.length, _teams.length),
                            style: TextStyle(fontSize: 13, color: c.textA(0.6))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GameCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionLabel(t.gs_difficulty),
                        StarRating(value: _difficulty, onChanged: (v) => setState(() => _difficulty = v)),
                        Text(t.gs_difficultyHint(_difficulty), style: TextStyle(fontSize: 13, color: c.textA(0.6))),
                        const SizedBox(height: 20),
                        SectionLabel(t.gs_pointsRequired(_points.round())),
                        _StepSlider(
                          value: _points,
                          min: 10,
                          max: 100,
                          divisions: 9,
                          minLabel: '10',
                          maxLabel: '100',
                          onChanged: (v) => setState(() => _points = v),
                        ),
                        const SizedBox(height: 12),
                        SectionLabel(t.gs_roundTimer(_timer.round())),
                        _StepSlider(
                          value: _timer,
                          min: 15,
                          max: 120,
                          divisions: 7,
                          minLabel: '15s',
                          maxLabel: '120s',
                          onChanged: (v) => setState(() => _timer = v),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(t.gs_skipPenalty, style: const TextStyle(fontWeight: FontWeight.w600)),
                          value: _skipPenalty,
                          onChanged: (v) => setState(() => _skipPenalty = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: GameButton(
                label: t.gs_startGame,
                loading: _starting,
                onPressed: _selected.length < 2 ? null : _start,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamChip extends StatelessWidget {
  const _TeamChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected ? c.success : c.textA(0.06),
        borderRadius: gameBorderRadius,
        border: Border.all(color: selected ? c.success : c.textA(0.15)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: gameBorderRadius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600, color: selected ? Colors.white : c.text),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepSlider extends StatelessWidget {
  const _StepSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.minLabel,
    required this.maxLabel,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final int divisions;
  final String minLabel;
  final String maxLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(fontSize: 13, color: context.colors.textA(0.6));
    return Column(
      children: [
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: value.round().toString(),
          onChanged: (v) {
            if (v != value) HapticFeedback.selectionClick();
            onChanged(v);
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(minLabel, style: muted), Text(maxLabel, style: muted)],
          ),
        ),
      ],
    );
  }
}
