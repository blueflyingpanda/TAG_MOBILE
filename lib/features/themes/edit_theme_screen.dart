import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/api.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../ui/widgets.dart';
import 'word_editor.dart';

class EditThemeScreen extends ConsumerStatefulWidget {
  const EditThemeScreen({super.key, required this.themeId});

  final int themeId;

  @override
  ConsumerState<EditThemeScreen> createState() => _EditThemeScreenState();
}

class _EditThemeScreenState extends ConsumerState<EditThemeScreen> {
  GameTheme? _theme;
  bool _loading = true;
  final _name = TextEditingController();
  bool _public = false;
  final List<EditableEntry> _newWords = [EditableEntry()];
  bool _saving = false;
  bool _togglingVisibility = false;
  String? _error;
  String? _visibilityError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    for (final w in _newWords) {
      w.ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final theme = await ref.read(apiProvider).getTheme(widget.themeId);
      if (!mounted) return;
      setState(() {
        _theme = theme;
        _name.text = theme.name;
        _public = theme.isPublic;
      });
    } catch (_) {
      if (mounted) setState(() => _error = ref.read(tProvider).et_errFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// PATCHes immediately, as on web.
  Future<void> _toggleVisibility(bool next) async {
    final theme = _theme;
    if (theme == null || _togglingVisibility) return;
    final t = ref.read(tProvider);
    setState(() {
      _visibilityError = null;
      _togglingVisibility = true;
    });
    try {
      final updated = await ref.read(apiProvider).setThemeVisibility(theme.id, next);
      if (mounted) {
        setState(() {
          _public = updated.isPublic;
          _theme = updated;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _visibilityError = e.isForbidden ? t.et_errForbidden : t.et_errVisibility);
    } finally {
      if (mounted) setState(() => _togglingVisibility = false);
    }
  }

  Future<void> _save() async {
    final theme = _theme;
    if (theme == null) return;
    final t = ref.read(tProvider);
    String? err;

    final name = _name.text;
    final valid = [for (final w in _newWords) if (w.trimmed.isNotEmpty) w];
    final newLower = [for (final w in valid) w.trimmed.toLowerCase()];
    final existingLower = {for (final w in theme.description.words.keys) w.toLowerCase()};

    if (name.trim().isEmpty) {
      err = t.ct_errNameRequired;
    } else if (name.length > 64) {
      err = t.ct_errNameTooLong;
    } else if (wordCount(name) > 10) {
      err = t.ct_errNameTooManyWords;
    } else {
      for (final w in valid) {
        if (w.text.length > 64) {
          err = t.ct_errWordTooLong(w.text);
          break;
        }
        if (wordCount(w.text) > 10) {
          err = t.ct_errWordTooManyWords(w.text);
          break;
        }
      }
    }
    if (err == null && newLower.toSet().length != newLower.length) {
      final seen = <String>{};
      final dups = <String>{for (final w in newLower) if (!seen.add(w)) w};
      err = t.ct_errWordsDuplicate(dups.map((w) => '"$w"').join(', '));
    }
    if (err == null) {
      final clashes = valid.where((w) => existingLower.contains(w.trimmed.toLowerCase())).toList();
      if (clashes.isNotEmpty) {
        err = t.et_errWordDuplicate(clashes.take(3).map((w) => '"${w.trimmed}"').join(', '));
      }
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await ref.read(apiProvider).updateTheme(
            theme.id,
            name: name.trim(),
            description: ThemeDescription(
              words: {...theme.description.words, for (final w in valid) w.trimmed: w.difficulty},
              teams: theme.description.teams,
            ),
          );
      if (mounted) context.pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.isForbidden ? t.et_errForbidden : t.et_errFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.colors;
    final theme = _theme;

    return Scaffold(
      appBar: AppBar(title: Text(t.et_title)),
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
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          children: [
                            GameCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SectionLabel(t.et_nameLabel),
                                  TextField(
                                    controller: _name,
                                    maxLength: 64,
                                    onChanged: (_) => setState(() {}),
                                    decoration: const InputDecoration(counterText: ''),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(t.ct_nameCounter(_name.text.length, wordCount(_name.text)),
                                      style: TextStyle(fontSize: 12, color: c.textA(0.6))),
                                  const SizedBox(height: 8),
                                  SwitchListTile.adaptive(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(t.ct_makePublic),
                                    subtitle: _togglingVisibility ? Text(t.et_updatingVisibility) : null,
                                    value: _public,
                                    onChanged: _togglingVisibility ? null : _toggleVisibility,
                                  ),
                                  if (_visibilityError != null)
                                    Text(_visibilityError!, style: TextStyle(color: c.error, fontSize: 13)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            SectionLabel(t.et_teamsLabel),
                            _ReadOnlyChips(items: theme.description.teams),
                            const SizedBox(height: 12),
                            SectionLabel(t.et_existingWords(theme.description.words.length)),
                            _ReadOnlyChips(items: theme.description.words.keys.toList()),
                            const SizedBox(height: 12),
                            GameCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SectionLabel(t.et_addWordsLabel),
                                  Text(t.et_addWordsHint, style: TextStyle(fontSize: 13, color: c.textA(0.6))),
                                  const SizedBox(height: 12),
                                  for (var i = 0; i < _newWords.length; i++)
                                    WordRow(
                                      key: ObjectKey(_newWords[i]),
                                      entry: _newWords[i],
                                      placeholder: t.ct_wordPlaceholder(i + 1),
                                      onChanged: () => setState(() {}),
                                      onRemove: _newWords.length > 1
                                          ? () => setState(() => _newWords.removeAt(i).ctrl.dispose())
                                          : null,
                                    ),
                                  addButton(t.ct_addWord, () => setState(() => _newWords.add(EditableEntry()))),
                                  if (_error != null) ...[const SizedBox(height: 12), ErrorBox(_error!)],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: GameButton(
                          label: _saving ? t.et_saving : t.et_save,
                          loading: _saving,
                          onPressed: _save,
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _ReadOnlyChips extends StatelessWidget {
  const _ReadOnlyChips({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 200),
      child: Tile(
        child: SingleChildScrollView(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final item in items)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(10)),
                  child: Text(item, style: TextStyle(fontSize: 13, color: c.textA(0.75))),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
