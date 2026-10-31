import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/api.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../ui/widgets.dart';
import 'cover_picker.dart';
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
  final _summary = TextEditingController();
  bool _public = false;
  final List<EditableEntry> _newWords = [EditableEntry()];
  bool _saving = false;
  bool _togglingVisibility = false;
  bool _coverBusy = false;
  Uint8List? _pendingCover;
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
    _summary.dispose();
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
        _summary.text = theme.summary;
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

  /// Uploads right away, like visibility; the preview shows the picked image meanwhile.
  Future<void> _changeCover() async {
    final theme = _theme;
    if (theme == null || _coverBusy) return;
    final t = ref.read(tProvider);
    final picked = await pickCover(context, t);
    if (picked == null || !mounted) return;
    setState(() {
      _coverBusy = true;
      _pendingCover = picked.bytes;
    });
    try {
      final updated = await ref.read(apiProvider).uploadCoverImage(theme.id, picked.bytes, picked.filename);
      if (mounted) setState(() => _theme = updated);
    } catch (e) {
      if (mounted) showToast(context, coverErrorMessage(t, e), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _coverBusy = false;
          _pendingCover = null;
        });
      }
    }
  }

  Future<void> _removeCover() async {
    final theme = _theme;
    if (theme == null || _coverBusy) return;
    final t = ref.read(tProvider);
    setState(() => _coverBusy = true);
    try {
      final api = ref.read(apiProvider);
      await api.deleteCoverImage(theme.id);
      final updated = await api.getTheme(theme.id);
      if (mounted) setState(() => _theme = updated);
    } catch (_) {
      if (mounted) showToast(context, t.ct_coverUploadFailed, error: true);
    } finally {
      if (mounted) setState(() => _coverBusy = false);
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
            summary: _summary.text.trim(),
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
                                  CoverPicker(
                                    t: t,
                                    url: theme.coverImageUrl,
                                    bytes: _pendingCover,
                                    busy: _coverBusy,
                                    onPick: _changeCover,
                                    onRemove: _removeCover,
                                  ),
                                  const SizedBox(height: 16),
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
                                  const SizedBox(height: 16),
                                  SectionLabel(t.ct_summaryLabel),
                                  TextField(
                                    controller: _summary,
                                    maxLength: 255,
                                    minLines: 1,
                                    maxLines: 3,
                                    decoration: InputDecoration(hintText: t.ct_summaryPlaceholder),
                                  ),
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
                            _CollapsibleChips(title: t.et_teamsLabel, items: theme.description.teams),
                            const SizedBox(height: 12),
                            _CollapsibleChips(
                              title: t.et_existingWords(theme.description.words.length),
                              items: theme.description.words.keys.toList(),
                            ),
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

class _CollapsibleChips extends StatelessWidget {
  const _CollapsibleChips({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tile(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          children: [
            Align(
              alignment: Alignment.centerLeft,
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
          ],
        ),
      ),
    );
  }
}
