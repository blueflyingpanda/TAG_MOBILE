import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../i18n/translations.dart';
import '../../state/providers.dart';
import '../../ui/widgets.dart';
import 'word_editor.dart';

class CreateThemeScreen extends ConsumerStatefulWidget {
  const CreateThemeScreen({super.key});

  @override
  ConsumerState<CreateThemeScreen> createState() => _CreateThemeScreenState();
}

class _CreateThemeScreenState extends ConsumerState<CreateThemeScreen> {
  final _scroll = ScrollController();
  final _name = TextEditingController();
  late String _lang = ref.read(localeProvider);
  bool _public = true;
  final List<EditableEntry> _teams = [EditableEntry()];
  final List<EditableEntry> _words = [EditableEntry()];
  bool _submitting = false;
  String? _error;
  int? _focusTeam;

  @override
  void dispose() {
    _scroll.dispose();
    _name.dispose();
    for (final e in [..._teams, ..._words]) {
      e.ctrl.dispose();
    }
    super.dispose();
  }

  /// Mirrors CreateTheme.tsx `validateTheme`.
  String? _validate(Translations t) {
    final name = _name.text;
    if (name.trim().isEmpty) return t.ct_errNameRequired;
    if (name.length > 64) return t.ct_errNameTooLong;
    if (wordCount(name) > 10) return t.ct_errNameTooManyWords;

    final teams = [for (final e in _teams) if (e.trimmed.isNotEmpty) e.trimmed];
    if (teams.length != 10) return t.ct_errTeamsCount;
    final dupTeams = _duplicates(teams);
    if (dupTeams.isNotEmpty) return t.ct_errTeamsDuplicate(dupTeams.map((d) => '"$d"').join(', '));
    for (final team in teams) {
      if (team.length > 64) return t.ct_errTeamNameTooLong(team);
      if (wordCount(team) > 10) return t.ct_errTeamNameTooManyWords(team);
    }

    final words = [for (final e in _words) if (e.trimmed.isNotEmpty) e];
    if (words.where((w) => w.difficulty == 1).length < 30) return t.ct_errWordsMin;
    final dupWords = _duplicates([for (final w in words) w.trimmed]);
    if (dupWords.isNotEmpty) return t.ct_errWordsDuplicate(dupWords.map((d) => '"$d"').join(', '));
    for (final w in words) {
      if (w.text.length > 64) return t.ct_errWordTooLong(w.text);
      if (wordCount(w.text) > 10) return t.ct_errWordTooManyWords(w.text);
      if (w.difficulty < 1 || w.difficulty > 5) return t.ct_errWordDifficulty(w.text);
    }
    return null;
  }

  /// First original spelling of each case-insensitive duplicate.
  List<String> _duplicates(List<String> values) {
    final seen = <String, String>{};
    final dups = <String>{};
    for (final v in values) {
      final key = v.toLowerCase();
      if (seen.containsKey(key)) {
        dups.add(seen[key]!);
      } else {
        seen[key] = v;
      }
    }
    return dups.toList();
  }

  Future<void> _submit() async {
    final t = ref.read(tProvider);
    final err = _validate(t);
    if (err != null) {
      setState(() => _error = err);
      _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      return;
    }
    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      await ref.read(apiProvider).createTheme({
        'name': _name.text.trim(),
        'language': _lang,
        'public': _public,
        'description': {
          'words': {
            for (final w in _words)
              if (w.trimmed.isNotEmpty) w.trimmed: {'difficulty': w.difficulty},
          },
          'teams': [for (final e in _teams) if (e.trimmed.isNotEmpty) e.trimmed],
        },
      });
      if (mounted) context.pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
        _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _importWords() async {
    final t = ref.read(tProvider);
    final text = await promptForText(context, message: t.ct_importPrompt, ok: t.ts_importBtn, cancel: t.ct_cancel);
    if (text == null || text.trim().isEmpty) return;
    setState(() {
      _words.removeWhere((w) => w.trimmed.isEmpty);
      _words.addAll(parseWordImport(text));
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.colors;
    final filledTeams = _teams.where((e) => e.trimmed.isNotEmpty).length;
    final easyWords = _words.where((w) => w.trimmed.isNotEmpty && w.difficulty == 1).length;
    final muted = TextStyle(fontSize: 12, color: c.textA(0.6));

    return Scaffold(
      appBar: AppBar(title: Text(t.ct_title)),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  Text(t.ct_unverifiedNote, style: TextStyle(fontSize: 13, color: c.textA(0.6))),
                  const SizedBox(height: 12),
                  if (_error != null) ...[ErrorBox(_error!), const SizedBox(height: 12)],
                  GameCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionLabel(t.ct_language),
                        SegmentedButton<String>(
                          segments: [
                            ButtonSegment(value: 'en', label: Text(t.ts_langEnglish)),
                            ButtonSegment(value: 'ru', label: Text(t.ts_langRussian)),
                          ],
                          selected: {_lang},
                          onSelectionChanged: (s) => setState(() => _lang = s.first),
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(t.ct_makePublic),
                          value: _public,
                          onChanged: (v) => setState(() => _public = v),
                        ),
                        const SizedBox(height: 4),
                        SectionLabel(t.ct_nameLabel),
                        TextField(
                          controller: _name,
                          maxLength: 64,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(hintText: t.ct_namePlaceholder, counterText: ''),
                        ),
                        const SizedBox(height: 4),
                        Text(t.ct_nameCounter(_name.text.length, wordCount(_name.text)), style: muted),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GameCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionLabel(t.ct_teamsLabel),
                        for (var i = 0; i < _teams.length; i++)
                          Padding(
                            key: ObjectKey(_teams[i]),
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _teams[i].ctrl,
                                    autofocus: _focusTeam == i,
                                    maxLength: 64,
                                    onChanged: (_) => setState(() {}),
                                    decoration: InputDecoration(
                                      hintText: t.ct_teamPlaceholder(i + 1),
                                      counterText: '',
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                if (_teams.length > 1)
                                  IconButton(
                                    tooltip: t.ct_removeTeam,
                                    onPressed: () => setState(() => _teams.removeAt(i).ctrl.dispose()),
                                    icon: Icon(Icons.remove_circle_outline_rounded, color: c.error),
                                  ),
                              ],
                            ),
                          ),
                        Row(
                          children: [
                            addButton(
                              t.ct_addTeam,
                              _teams.length >= 10
                                  ? null
                                  : () => setState(() {
                                        _teams.add(EditableEntry());
                                        _focusTeam = _teams.length - 1;
                                      }),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(t.ct_teamsCounter(filledTeams, _teams.length), style: muted)),
                          ],
                        ),
                        if (filledTeams != 10) ...[
                          const SizedBox(height: 8),
                          Text(t.ct_teamsError, style: TextStyle(fontSize: 13, color: c.error)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GameCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionLabel(t.ct_wordsLabel),
                        GameButton(
                          label: t.ct_importFromText,
                          variant: ButtonVariant.muted,
                          icon: Icons.playlist_add_rounded,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          fontSize: 14,
                          onPressed: _importWords,
                        ),
                        const SizedBox(height: 12),
                        for (var i = 0; i < _words.length; i++)
                          WordRow(
                            key: ObjectKey(_words[i]),
                            entry: _words[i],
                            placeholder: t.ct_wordPlaceholder(i + 1),
                            onChanged: () => setState(() {}),
                            onRemove: () => setState(() => _words.removeAt(i).ctrl.dispose()),
                          ),
                        Row(
                          children: [
                            addButton(t.ct_addWord, () => setState(() => _words.add(EditableEntry()))),
                            const SizedBox(width: 10),
                            Expanded(child: Text(t.ct_wordsCounter(easyWords), style: muted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: GameButton(
                label: _submitting ? t.ct_submitting : t.ct_submit,
                loading: _submitting,
                onPressed: _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
