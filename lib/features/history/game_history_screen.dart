import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/errors.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../ui/widgets.dart';
import '../profile_sheet.dart';

String _formatDate(BuildContext context, DateTime d) =>
    DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
        .add_Hm()
        .format(d);

class GameHistoryScreen extends ConsumerStatefulWidget {
  const GameHistoryScreen({super.key});

  @override
  ConsumerState<GameHistoryScreen> createState() => _GameHistoryScreenState();
}

class _GameHistoryScreenState extends ConsumerState<GameHistoryScreen> {
  List<GameListItem>? _games;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (ref.read(authProvider) == null) return;
    try {
      final res = await ref.read(apiProvider).getGames();
      if (mounted) {
        setState(() {
          _games = res.items;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e, ref.read(tProvider)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.colors;
    final games = _games;
    final signedIn = ref.watch(authProvider) != null;
    ref.listen(authProvider, (_, user) {
      if (user != null) _load();
    });

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        edgeOffset: 120,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar.medium(
              title: Text(t.gh_title),
              actions: const [ProfileButton(), SizedBox(width: 8)],
            ),
            if (!signedIn)
              SliverFillRemaining(
                hasScrollBody: false,
                child: StatusView(
                  message: t.login_required,
                  action: GameButton(
                    label: t.nav_login,
                    expand: false,
                    icon: Icons.login_rounded,
                    onPressed: () => context.push('/login'),
                  ),
                ),
              )
            else if (_error != null && games == null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: StatusView(
                  message: _error!,
                  isError: true,
                  action: GameButton(
                    label: t.err_retry,
                    expand: false,
                    icon: Icons.refresh_rounded,
                    onPressed: _load,
                  ),
                ),
              )
            else if (games == null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.separated(
                  itemCount: 5,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, _) => const _GameRowSkeleton(),
                ),
              )
            else if (games.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: StatusView(
                  icon: Icons.history_toggle_off_rounded,
                  message: t.gh_noGames,
                  action: GameButton(
                    label: t.gh_emptyAction,
                    expand: false,
                    icon: Icons.style_rounded,
                    onPressed: () => context.go('/'),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.separated(
                  itemCount: games.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final g = games[i];
                    final done = g.endedAt != null;
                    final muted = TextStyle(fontSize: 13, color: c.textA(0.65));
                    return Tile(
                      color: c.card,
                      padding: const EdgeInsets.all(16),
                      onTap: () => context.push('/history/${g.id}'),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  g.themeName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  t.gh_language(g.themeLanguage.toUpperCase()),
                                  style: muted,
                                ),
                                Text(
                                  t.gh_started(
                                    _formatDate(context, g.startedAt),
                                  ),
                                  style: muted,
                                ),
                                if (g.endedAt != null)
                                  Text(
                                    t.gh_ended(
                                      _formatDate(context, g.endedAt!),
                                    ),
                                    style: muted,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _StatusChip(
                                done: done,
                                label: done ? t.gh_completed : t.gh_inProgress,
                              ),
                              const SizedBox(height: 6),
                              Text(t.gh_pointsRequired(g.points), style: muted),
                              Text(t.gh_roundTime(g.round), style: muted),
                              Text(
                                t.gh_skipPenalty(g.skipPenalty),
                                style: muted,
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.done, required this.label});

  final bool done;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = done ? c.success : c.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class GameDetailsScreen extends ConsumerStatefulWidget {
  const GameDetailsScreen({super.key, required this.gameId});

  final int gameId;

  @override
  ConsumerState<GameDetailsScreen> createState() => _GameDetailsScreenState();
}

class _GameDetailsScreenState extends ConsumerState<GameDetailsScreen> {
  GameDetails? _game;
  String? _error;
  bool _resuming = false;

  @override
  void initState() {
    super.initState();
    ref
        .read(apiProvider)
        .getGame(widget.gameId)
        .then(
          (g) => mounted ? setState(() => _game = g) : null,
          onError: (Object e) => mounted
              ? setState(() => _error = friendlyError(e, ref.read(tProvider)))
              : null,
        );
  }

  /// Rebuilds a local GameState from the server record (web: GameHistory `handleResumeGame`).
  Future<void> _resume(GameDetails g) async {
    if (g.info.teams.isEmpty) {
      setState(() => _error = 'Cannot resume game: missing teams data');
      return;
    }
    if (ref.read(gameProvider) != null) {
      final t = ref.read(tProvider);
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text('${t.gh_resumeGame}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t.ct_cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(t.gh_resumeGame),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _resuming = true);
    try {
      final theme = await ref.read(apiProvider).getTheme(g.themeId);
      final state = GameState(
        settings: GameSettings(
          theme: theme,
          selectedTeams: [for (final team in g.info.teams) team.name],
          difficulty: g.difficulty ?? 5,
          pointsRequired: g.points,
          roundTimer: g.round,
          skipPenalty: g.skipPenalty,
        ),
        currentTeamIndex: g.info.currentTeamIndex ?? 0,
        currentRound: (g.info.currentRound ?? 0) > 0 ? g.info.currentRound! : 1,
        teamScores: {for (final team in g.info.teams) team.name: team.score},
        wordsUsed: [...g.wordsGuessed, ...g.wordsSkipped],
      );
      ref.read(gameProvider.notifier).resume(state, g.id);
      if (mounted) context.go('/play');
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e, ref.read(tProvider)));
    } finally {
      if (mounted) setState(() => _resuming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.colors;
    final g = _game;
    final muted = TextStyle(color: c.textA(0.75));

    return Scaffold(
      appBar: AppBar(title: Text(t.gh_gameDetails)),
      body: SafeArea(
        top: false,
        child: g == null
            ? (_error != null
                  ? StatusView(message: _error!, isError: true)
                  : const Center(child: CircularProgressIndicator()))
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        GameCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                g.themeName,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                t.gh_language(g.themeLanguage.toUpperCase()),
                                style: muted,
                              ),
                              Text(t.gh_pointsRequired(g.points), style: muted),
                              Text(
                                t.gh_skipPenalty(g.skipPenalty),
                                style: muted,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                t.gh_started(_formatDate(context, g.startedAt)),
                                style: muted,
                              ),
                              if (g.endedAt != null)
                                Text(
                                  t.gh_ended(_formatDate(context, g.endedAt!)),
                                  style: muted,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        GameCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SectionLabel(t.gh_teams),
                              if (g.info.teams.isEmpty)
                                Text(t.gh_noTeams, style: muted)
                              else
                                for (final team in g.info.teams)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 3,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(child: Text(team.name)),
                                        Text(
                                          '${team.score}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: c.success,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        GameCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SectionLabel(t.gh_gameStatus),
                              Text(
                                t.gh_currentRound(
                                  g.info.currentRound ?? g.round,
                                ),
                                style: muted,
                              ),
                              Text(
                                t.gh_currentTeam(
                                  g.info.currentTeamIndex != null &&
                                          g.info.currentTeamIndex! <
                                              g.info.teams.length
                                      ? g
                                            .info
                                            .teams[g.info.currentTeamIndex!]
                                            .name
                                      : 'Unknown',
                                ),
                                style: muted,
                              ),
                              Text(
                                g.endedAt != null
                                    ? t.gh_completed
                                    : t.gh_inProgress,
                                style: muted,
                              ),
                            ],
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, style: TextStyle(color: c.error)),
                        ],
                      ],
                    ),
                  ),
                  if (g.endedAt == null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: GameButton(
                        label: t.gh_resumeGame,
                        icon: Icons.play_arrow_rounded,
                        loading: _resuming,
                        onPressed: () => _resume(g),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _GameRowSkeleton extends StatelessWidget {
  const _GameRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Pulse(
      child: Tile(
        color: context.colors.card,
        padding: const EdgeInsets.all(16),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 180, height: 16),
            SizedBox(height: 10),
            SkeletonBox(width: 120, height: 12),
            SizedBox(height: 8),
            SkeletonBox(width: 90, height: 12),
          ],
        ),
      ),
    );
  }
}
