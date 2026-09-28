import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../ui/widgets.dart';

class ThemeDetailsScreen extends ConsumerStatefulWidget {
  const ThemeDetailsScreen({super.key, required this.themeId});

  final int themeId;

  @override
  ConsumerState<ThemeDetailsScreen> createState() => _ThemeDetailsScreenState();
}

class _ThemeDetailsScreenState extends ConsumerState<ThemeDetailsScreen> {
  GameTheme? _theme;
  bool _loading = true;
  String? _error;
  bool _togglingFavourite = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final theme = await ref.read(apiProvider).getTheme(widget.themeId);
      if (mounted) setState(() => _theme = theme);
    } catch (e) {
      if (mounted) setState(() => _error = ref.read(tProvider).td_failedLoad);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFavourite() async {
    final theme = _theme;
    if (theme == null || _togglingFavourite) return;
    HapticFeedback.lightImpact();
    final next = !theme.isFavorited;
    // Optimistic update, reverted on failure.
    setState(() {
      _togglingFavourite = true;
      _theme = theme.copyWith(isFavorited: next, likesCount: theme.likesCount + (next ? 1 : -1));
    });
    try {
      await ref.read(apiProvider).setFavourite(theme.id, next);
    } catch (_) {
      if (mounted) {
        setState(() => _theme = theme);
        showToast(context, ref.read(tProvider).td_failedFavorite, error: true);
      }
    } finally {
      if (mounted) setState(() => _togglingFavourite = false);
    }
  }

  void _share() {
    final theme = _theme!;
    final box = context.findRenderObject() as RenderBox?;
    SharePlus.instance.share(ShareParams(
      uri: Uri.parse('$shareBaseUrl/${theme.id}/'),
      subject: theme.name,
      sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final user = ref.watch(authProvider);
    final c = context.colors;
    final theme = _theme;

    final canEdit = theme != null && user != null && (user.admin || user.email == theme.creator?.email);

    return Scaffold(
      appBar: AppBar(
        title: Text(theme?.name ?? ''),
        actions: [
          if (theme != null) ...[
            TextButton.icon(
              onPressed: _toggleFavourite,
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                child: Icon(
                  theme.isFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  key: ValueKey(theme.isFavorited),
                  color: theme.isFavorited ? c.error : c.text,
                ),
              ),
              label: Text('${theme.likesCount}', style: TextStyle(color: c.text)),
            ),
            IconButton(onPressed: _share, tooltip: t.td_share, icon: const Icon(Icons.share_rounded)),
            if (canEdit)
              IconButton(
                tooltip: t.et_edit,
                icon: const Icon(Icons.edit_rounded),
                onPressed: () async {
                  final saved = await context.push<bool>('/theme/${theme.id}/edit');
                  if (saved == true) _load();
                },
              ),
          ],
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : theme == null
                ? StatusView(
                    message: _error ?? t.td_notFound,
                    isError: true,
                    action: GameButton(label: t.td_back, expand: false, onPressed: () => context.pop()),
                  )
                : Column(
                    children: [
                      Expanded(child: _details(theme)),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: GameButton(
                          label: t.td_select,
                          icon: Icons.play_arrow_rounded,
                          onPressed: () => context.push('/setup', extra: theme),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _details(GameTheme theme) {
    final t = ref.watch(tProvider);
    final c = context.colors;
    final words = theme.description.words.keys.toList();
    final muted = TextStyle(color: c.textA(0.75));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(t.td_language(theme.language.toUpperCase())),
              _Pill(theme.verified ? t.td_verified : t.td_unverified),
              _Pill(t.td_visibility(theme.isPublic)),
            ],
          ),
          if (theme.creator != null) ...[
            const SizedBox(height: 10),
            Text(t.td_createdBy(theme.creator!.email ?? theme.creator!.username ?? ''), style: muted),
          ],
          const SizedBox(height: 20),
          SectionLabel(t.td_teams(theme.description.teams.length)),
          _ChipGrid(items: theme.description.teams),
          const SizedBox(height: 20),
          SectionLabel(t.td_words(words.length)),
          _ChipGrid(items: words),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.textA(0.12)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
    );
  }
}

class _ChipGrid extends StatelessWidget {
  const _ChipGrid({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tile(
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final item in items)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(10)),
              child: Text(item, style: TextStyle(fontSize: 13, color: c.textA(0.85))),
            ),
        ],
      ),
    );
  }
}
