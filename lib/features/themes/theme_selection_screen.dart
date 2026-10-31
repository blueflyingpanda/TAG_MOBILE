import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../i18n/translations.dart';
import '../../state/providers.dart';
import '../../ui/widgets.dart';
import '../profile_sheet.dart';
import 'import_theme_sheet.dart';

class ThemeFilters {
  const ThemeFilters({
    this.search = '',
    this.order = 'id',
    this.descending = false,
    this.mine = false,
    this.favourites = false,
    this.unverified = false,
    this.defaultOrder = 'id',
    this.defaultDescending = false,
  });

  /// Guests land on the most liked themes; signed-in users keep the old default.
  factory ThemeFilters.defaults({required bool guest}) => guest
      ? const ThemeFilters(
          order: 'likes',
          descending: true,
          defaultOrder: 'likes',
          defaultDescending: true,
        )
      : const ThemeFilters();

  final String search;
  final String order; // id | name | likes
  final bool descending;
  final bool mine;
  final bool favourites;
  final bool unverified;
  final String defaultOrder;
  final bool defaultDescending;

  bool get sortChanged =>
      order != defaultOrder || descending != defaultDescending;

  int get activeCount =>
      (sortChanged ? 1 : 0) +
      (mine ? 1 : 0) +
      (favourites ? 1 : 0) +
      (unverified ? 1 : 0);

  ThemeFilters reset() => ThemeFilters(
    order: defaultOrder,
    descending: defaultDescending,
    defaultOrder: defaultOrder,
    defaultDescending: defaultDescending,
  );

  ThemeFilters copyWith({
    String? search,
    String? order,
    bool? descending,
    bool? mine,
    bool? favourites,
    bool? unverified,
  }) => ThemeFilters(
    search: search ?? this.search,
    order: order ?? this.order,
    descending: descending ?? this.descending,
    mine: mine ?? this.mine,
    favourites: favourites ?? this.favourites,
    unverified: unverified ?? this.unverified,
    defaultOrder: defaultOrder,
    defaultDescending: defaultDescending,
  );
}

/// Kept app-wide so filters survive navigating into a theme and back
/// (the web app keeps them in the URL).
class ThemeFiltersNotifier extends Notifier<ThemeFilters> {
  @override
  ThemeFilters build() =>
      ThemeFilters.defaults(guest: ref.watch(authProvider) == null);

  void update(ThemeFilters f) => state = f;
}

final themeFiltersProvider =
    NotifierProvider<ThemeFiltersNotifier, ThemeFilters>(
      ThemeFiltersNotifier.new,
    );

class ThemeSelectionScreen extends ConsumerStatefulWidget {
  const ThemeSelectionScreen({super.key});

  @override
  ConsumerState<ThemeSelectionScreen> createState() =>
      _ThemeSelectionScreenState();
}

class _ThemeSelectionScreenState extends ConsumerState<ThemeSelectionScreen> {
  final _scroll = ScrollController();
  late final _searchCtrl = TextEditingController(
    text: ref.read(themeFiltersProvider).search,
  );
  Timer? _debounce;

  final List<ThemeListItem> _items = [];
  int _page = 0;
  int _pages = 1;
  bool _loading = false;
  String? _error;
  int _requestSeq = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) _loadMore();
    });
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    _items.clear();
    _page = 0;
    _pages = 1;
    _error = null;
    await _loadMore(force: true);
  }

  Future<void> _loadMore({bool force = false}) async {
    if (!force && (_loading || _page >= _pages)) return;
    final seq = ++_requestSeq;
    final f = ref.read(themeFiltersProvider);
    final signedIn = ref.read(authProvider) != null;
    setState(() => _loading = true);
    try {
      final res = await ref
          .read(apiProvider)
          .getThemes(
            page: _page + 1,
            language: ref.read(localeProvider),
            name: f.search.isEmpty ? null : f.search,
            mine: f.mine && signedIn,
            verified: f.unverified ? false : null,
            favourites: f.favourites && signedIn,
            order: f.order,
            descending: f.descending,
          );
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _items.addAll(res.items);
        _page += 1;
        _pages = res.pages;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _error = friendlyError(e, ref.read(tProvider));
        _loading = false;
      });
    }
  }

  Widget _emptyState(ThemeFilters filters) {
    final t = ref.read(tProvider);
    Widget button(String label, VoidCallback onPressed) =>
        GameButton(label: label, expand: false, onPressed: onPressed);

    if (filters.mine) {
      return StatusView(
        icon: Icons.edit_note_rounded,
        message: t.ts_emptyMine,
        action: button(t.ts_create, () {
          if (requireLogin(context, ref)) context.push('/create');
        }),
      );
    }
    if (filters.favourites) {
      return StatusView(
        icon: Icons.favorite_border_rounded,
        message: t.ts_emptyFavorites,
        action: button(
          t.ts_browseThemes,
          () => _setFilters(filters.copyWith(favourites: false)),
        ),
      );
    }
    if (filters.search.isNotEmpty || filters.activeCount > 0) {
      return StatusView(
        icon: Icons.search_off_rounded,
        message: t.ts_emptySearch,
        action: button(t.ts_clearFilters, () {
          _searchCtrl.clear();
          _setFilters(filters.reset());
        }),
      );
    }
    return StatusView(icon: Icons.style_outlined, message: t.ts_noThemes);
  }

  /// One removable chip per active filter, so users can see why the list looks as it does.
  List<Widget> _chips(ThemeFilters f, Translations t) {
    final signedIn = ref.read(authProvider) != null;
    Widget chip(String label, VoidCallback onRemove) => InputChip(
      label: Text(label),
      onDeleted: onRemove,
      deleteIcon: const Icon(Icons.close_rounded, size: 18),
      visualDensity: VisualDensity.compact,
    );
    final orderLabel = switch (f.order) {
      'name' => t.ts_orderByName,
      'likes' => t.ts_orderByLikes,
      _ => t.ts_orderByDate,
    };
    return [
      if (f.search.isNotEmpty)
        chip('“${f.search}”', () {
          _searchCtrl.clear();
          _setFilters(f.copyWith(search: ''));
        }),
      if (f.sortChanged)
        chip(
          '$orderLabel ${f.descending ? '↓' : '↑'}',
          () => _setFilters(
            f.copyWith(order: f.defaultOrder, descending: f.defaultDescending),
          ),
        ),
      if (f.mine && signedIn)
        chip(t.ts_onlyMine, () => _setFilters(f.copyWith(mine: false))),
      if (f.favourites && signedIn)
        chip(
          t.ts_onlyFavorites,
          () => _setFilters(f.copyWith(favourites: false)),
        ),
      if (f.unverified)
        chip(
          t.ts_showUnverified,
          () => _setFilters(f.copyWith(unverified: false)),
        ),
    ];
  }

  void _setFilters(ThemeFilters f) {
    ref.read(themeFiltersProvider.notifier).update(f);
    _reload();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _setFilters(
        ref.read(themeFiltersProvider).copyWith(search: value.trim()),
      );
    });
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<ThemeFilters>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(initial: ref.read(themeFiltersProvider)),
    );
    if (result != null) _setFilters(result);
  }

  Future<void> _openImport() async {
    if (!requireLogin(context, ref)) return;
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ImportThemeSheet(),
    );
    if (created == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.colors;
    final filters = ref.watch(themeFiltersProvider);
    final game = ref.watch(gameProvider);
    ref.listen(authProvider, (_, _) {
      _searchCtrl.clear();
      _reload();
    });
    ref.listen(localeProvider, (_, _) => _reload());

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'create-theme',
        backgroundColor: c.success,
        foregroundColor: Colors.white,
        onPressed: () async {
          if (!requireLogin(context, ref)) return;
          final created = await context.push<bool>('/create');
          if (created == true) _reload();
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(
          t.ts_create,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        edgeOffset: 120,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar.medium(
              title: Text(t.ts_title),
              actions: [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (_) => _openImport(),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'import',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.file_download_outlined),
                        title: Text(t.ts_import),
                      ),
                    ),
                  ],
                ),
                const ProfileButton(),
                const SizedBox(width: 8),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: _onSearchChanged,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (v) {
                          _debounce?.cancel();
                          _setFilters(filters.copyWith(search: v.trim()));
                        },
                        decoration: InputDecoration(
                          hintText: t.ts_searchPlaceholder,
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchCtrl.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    _setFilters(filters.copyWith(search: ''));
                                  },
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Badge(
                      isLabelVisible: filters.activeCount > 0,
                      label: Text('${filters.activeCount}'),
                      backgroundColor: c.success,
                      child: IconButton.filledTonal(
                        onPressed: _openFilters,
                        icon: const Icon(Icons.tune_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_chips(filters, t).isNotEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    itemCount: _chips(filters, t).length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => _chips(filters, t)[i],
                  ),
                ),
              ),
            if (game != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Tile(
                    color: c.success.withValues(alpha: 0.12),
                    onTap: () => context.go(
                      game.hasPendingResults ? '/results' : '/play',
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.play_circle_fill_rounded,
                          color: c.success,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.home_resumeTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${game.settings.theme.name} • ${t.gp_round(game.currentRound)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: c.textA(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => context.go(
                            game.hasPendingResults ? '/results' : '/play',
                          ),
                          child: Text(t.home_resumeAction),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (filters.unverified)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Tile(
                    color: c.card,
                    child: Text(
                      t.ts_unverifiedWarning,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ),
            if (_error != null && _items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: StatusView(
                  message: _error!,
                  isError: true,
                  action: GameButton(
                    label: t.err_retry,
                    expand: false,
                    icon: Icons.refresh_rounded,
                    onPressed: _reload,
                  ),
                ),
              )
            else if (_items.isEmpty && _loading)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                sliver: SliverList.separated(
                  itemCount: 3,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, _) => const ThemeTileSkeleton(),
                ),
              )
            else if (_items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _emptyState(filters),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                sliver: SliverList.separated(
                  itemCount: _items.length + (_loading ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    if (i >= _items.length) return const ThemeTileSkeleton();
                    final item = _items[i];
                    return _ThemeTile(
                      item: item,
                      onTap: () => context.push('/theme/${item.id}'),
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

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.item, required this.onTap});

  final ThemeListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tile(
      color: c.card,
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              CoverImage(url: item.coverImageUrl),
              // Bottom gradient keeps the like count readable on any cover.
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.center,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 10,
                top: 10,
                child: _VerifiedChip(verified: item.verified),
              ),
              Positioned(
                right: 10,
                bottom: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${item.likesCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: c.textA(0.4)),
                  ],
                ),
                const SizedBox(height: 6),
                // Fixed height (2 lines) so tiles match with or without a summary.
                SizedBox(
                  height: 36,
                  child: Text(
                    item.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.textA(0.7),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VerifiedChip extends ConsumerWidget {
  const _VerifiedChip({required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: verified ? c.success : Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        verified ? t.ts_verifiedChip : t.ts_unverifiedChip,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.initial});

  final ThemeFilters initial;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late ThemeFilters _f = widget.initial;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final signedIn = ref.watch(authProvider) != null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(t.ts_orderBy),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'id', label: Text(t.ts_orderByDate)),
                ButtonSegment(value: 'name', label: Text(t.ts_orderByName)),
                ButtonSegment(value: 'likes', label: Text(t.ts_orderByLikes)),
              ],
              selected: {_f.order},
              onSelectionChanged: (s) =>
                  setState(() => _f = _f.copyWith(order: s.first)),
            ),
            const SizedBox(height: 16),
            SectionLabel(t.ts_orderDirection),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(t.ts_ascending),
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(t.ts_descending),
                  icon: const Icon(Icons.arrow_downward_rounded),
                ),
              ],
              selected: {_f.descending},
              onSelectionChanged: (s) =>
                  setState(() => _f = _f.copyWith(descending: s.first)),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(t.ts_showUnverified),
              value: _f.unverified,
              onChanged: (v) => setState(() => _f = _f.copyWith(unverified: v)),
            ),
            if (signedIn) ...[
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(t.ts_onlyMine),
                value: _f.mine,
                onChanged: (v) => setState(() => _f = _f.copyWith(mine: v)),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(t.ts_onlyFavorites),
                value: _f.favourites,
                onChanged: (v) =>
                    setState(() => _f = _f.copyWith(favourites: v)),
              ),
            ],
            const SizedBox(height: 12),
            GameButton(
              label: t.ts_search,
              onPressed: () => Navigator.pop(context, _f),
            ),
          ],
        ),
      ),
    );
  }
}
