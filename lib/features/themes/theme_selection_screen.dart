import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../ui/widgets.dart';
import '../profile_sheet.dart';
import 'import_theme_sheet.dart';

class ThemeFilters {
  const ThemeFilters({
    this.language = 'en',
    this.search = '',
    this.order = 'id',
    this.descending = false,
    this.mine = false,
    this.favourites = false,
    this.unverified = false,
  });

  final String language;
  final String search;
  final String order; // id | name | likes
  final bool descending;
  final bool mine;
  final bool favourites;
  final bool unverified;

  int get activeCount =>
      (order != 'id' ? 1 : 0) + (descending ? 1 : 0) + (mine ? 1 : 0) + (favourites ? 1 : 0) + (unverified ? 1 : 0);

  ThemeFilters copyWith({
    String? language,
    String? search,
    String? order,
    bool? descending,
    bool? mine,
    bool? favourites,
    bool? unverified,
  }) =>
      ThemeFilters(
        language: language ?? this.language,
        search: search ?? this.search,
        order: order ?? this.order,
        descending: descending ?? this.descending,
        mine: mine ?? this.mine,
        favourites: favourites ?? this.favourites,
        unverified: unverified ?? this.unverified,
      );
}

/// Kept app-wide so filters survive navigating into a theme and back
/// (the web app keeps them in the URL).
class ThemeFiltersNotifier extends Notifier<ThemeFilters> {
  @override
  ThemeFilters build() => ThemeFilters(language: ref.read(localeProvider));

  void update(ThemeFilters f) => state = f;
}

final themeFiltersProvider = NotifierProvider<ThemeFiltersNotifier, ThemeFilters>(ThemeFiltersNotifier.new);

class ThemeSelectionScreen extends ConsumerStatefulWidget {
  const ThemeSelectionScreen({super.key});

  @override
  ConsumerState<ThemeSelectionScreen> createState() => _ThemeSelectionScreenState();
}

class _ThemeSelectionScreenState extends ConsumerState<ThemeSelectionScreen> {
  final _scroll = ScrollController();
  late final _searchCtrl = TextEditingController(text: ref.read(themeFiltersProvider).search);
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
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiProvider).getThemes(
            page: _page + 1,
            language: f.language,
            name: f.search.isEmpty ? null : f.search,
            mine: f.mine,
            verified: f.unverified ? false : null,
            favourites: f.favourites,
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
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _setFilters(ThemeFilters f) {
    ref.read(themeFiltersProvider.notifier).update(f);
    _reload();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _setFilters(ref.read(themeFiltersProvider).copyWith(search: value.trim()));
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

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'create-theme',
        backgroundColor: c.success,
        foregroundColor: Colors.white,
        onPressed: () async {
          final created = await context.push<bool>('/create');
          if (created == true) _reload();
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(t.ts_create, style: const TextStyle(fontWeight: FontWeight.w700)),
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
                    _LanguageToggle(
                      value: filters.language,
                      onChanged: (v) => _setFilters(filters.copyWith(language: v)),
                    ),
                    const SizedBox(width: 4),
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
            if (game != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Tile(
                    color: c.success.withValues(alpha: 0.12),
                    onTap: () => context.go(game.hasPendingResults ? '/results' : '/play'),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.play_circle_fill_rounded, color: c.success, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.gh_resumeGame, style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(
                                '${game.settings.theme.name} • ${t.gp_round(game.currentRound)}',
                                style: TextStyle(fontSize: 13, color: c.textA(0.7)),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
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
                    child: Text(t.ts_unverifiedWarning, style: const TextStyle(fontSize: 13)),
                  ),
                ),
              ),
            if (_error != null && _items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: StatusView(
                  message: _error!,
                  isError: true,
                  action: GameButton(label: t.ts_search, expand: false, onPressed: _reload),
                ),
              )
            else if (_items.isEmpty && !_loading)
              SliverFillRemaining(hasScrollBody: false, child: StatusView(message: t.ts_noThemes))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                sliver: SliverList.separated(
                  itemCount: _items.length + (_loading ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    if (i >= _items.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final item = _items[i];
                    return _ThemeTile(item: item, onTap: () => context.push('/theme/${item.id}'));
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Text(item.verified ? '✅' : '❌', style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          ),
          if (item.likesCount > 0) ...[
            Icon(Icons.favorite_rounded, size: 16, color: c.error.withValues(alpha: 0.8)),
            const SizedBox(width: 4),
            Text('${item.likesCount}', style: TextStyle(color: c.textA(0.7), fontSize: 13)),
            const SizedBox(width: 4),
          ],
          Icon(Icons.chevron_right_rounded, color: c.textA(0.4)),
        ],
      ),
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.card,
      shape: RoundedRectangleBorder(borderRadius: gameBorderRadius, side: BorderSide(color: c.textA(0.15))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onChanged(value == 'en' ? 'ru' : 'en'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Text(value == 'en' ? '🇬🇧 EN' : '🇷🇺 RU', style: const TextStyle(fontWeight: FontWeight.w600)),
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(t.ts_language),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'en', label: Text(t.ts_langEnglish)),
                ButtonSegment(value: 'ru', label: Text(t.ts_langRussian)),
              ],
              selected: {_f.language},
              onSelectionChanged: (s) => setState(() => _f = _f.copyWith(language: s.first)),
            ),
            const SizedBox(height: 16),
            SectionLabel(t.ts_orderBy),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'id', label: Text(t.ts_orderByDate)),
                ButtonSegment(value: 'name', label: Text(t.ts_orderByName)),
                ButtonSegment(value: 'likes', label: Text(t.ts_orderByLikes)),
              ],
              selected: {_f.order},
              onSelectionChanged: (s) => setState(() => _f = _f.copyWith(order: s.first)),
            ),
            const SizedBox(height: 16),
            SectionLabel(t.ts_orderDirection),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(t.ts_ascending), icon: const Icon(Icons.arrow_upward_rounded)),
                ButtonSegment(value: true, label: Text(t.ts_descending), icon: const Icon(Icons.arrow_downward_rounded)),
              ],
              selected: {_f.descending},
              onSelectionChanged: (s) => setState(() => _f = _f.copyWith(descending: s.first)),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(t.ts_showUnverified),
              value: _f.unverified,
              onChanged: (v) => setState(() => _f = _f.copyWith(unverified: v)),
            ),
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
              onChanged: (v) => setState(() => _f = _f.copyWith(favourites: v)),
            ),
            const SizedBox(height: 12),
            GameButton(label: t.ts_search, onPressed: () => Navigator.pop(context, _f)),
          ],
        ),
      ),
    );
  }
}
