import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../ui/widgets.dart';

/// Validates and normalizes pasted theme JSON (API format), mirroring
/// ThemeSelection.tsx `handleImport`. Throws [FormatException] with a
/// user-facing message.
Map<String, dynamic> parseImportedTheme(String raw, {required bool isPublic}) {
  final dynamic data;
  try {
    data = jsonDecode(raw);
  } catch (_) {
    throw const FormatException('Invalid JSON');
  }
  final desc = data is Map ? data['description'] : null;
  if (data is! Map ||
      data['name'] == null ||
      data['language'] == null ||
      desc is! Map ||
      desc['teams'] is! List ||
      (desc['words'] is! List && desc['words'] is! Map)) {
    throw const FormatException(
        'Invalid theme format. Expected API format with name, language, and description object');
  }

  final rawWords = desc['words'];
  final words = <String, Map<String, int>>{};
  final wordKeys = <String>[];
  if (rawWords is List) {
    for (final w in rawWords) {
      final key = w.toString().trim();
      wordKeys.add(key);
      words[key] = {'difficulty': 1};
    }
  } else {
    for (final e in (rawWords as Map).entries) {
      final key = e.key.toString().trim();
      wordKeys.add(key);
      final d = e.value is Map ? (e.value as Map)['difficulty'] : null;
      words[key] = {'difficulty': d is num ? d.toInt() : 1};
    }
  }
  if (words.length < 30) throw const FormatException('Theme must have at least 30 words');

  final teams = [for (final t in desc['teams'] as List) t.toString().trim()];
  if (teams.length != 10) throw const FormatException('Theme must contain exactly 10 teams');

  final teamLower = [for (final t in teams) t.toLowerCase()];
  final dupTeams = [
    for (var i = 0; i < teams.length; i++)
      if (teamLower.indexOf(teamLower[i]) != i) '"${teams[i]}"',
  ];
  if (dupTeams.isNotEmpty) {
    throw FormatException('Team names must be unique. Duplicates found: ${dupTeams.join(', ')}');
  }

  final wordLower = [for (final w in wordKeys) w.toLowerCase()];
  final dupWords = <String>{
    for (var i = 0; i < wordLower.length; i++)
      if (wordLower.indexOf(wordLower[i]) != i) wordLower[i],
  };
  if (dupWords.isNotEmpty) {
    final shown = dupWords.take(5).map((w) => '"$w"').join(', ');
    throw FormatException(
        'Words must be unique within a theme. Duplicates found: $shown${dupWords.length > 5 ? '...' : ''}');
  }

  return {
    ...Map<String, dynamic>.from(data),
    'public': isPublic,
    'description': {'teams': teams, 'words': words},
  };
}

class ImportThemeSheet extends ConsumerStatefulWidget {
  const ImportThemeSheet({super.key});

  @override
  ConsumerState<ImportThemeSheet> createState() => _ImportThemeSheetState();
}

class _ImportThemeSheetState extends ConsumerState<ImportThemeSheet> {
  final _ctrl = TextEditingController();
  bool _public = true;
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _ctrl.text = data!.text!;
      setState(() => _error = null);
    }
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final Map<String, dynamic> payload;
    try {
      payload = parseImportedTheme(_ctrl.text, isPublic: _public);
    } on FormatException catch (e) {
      setState(() => _error = e.message);
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(apiProvider).createTheme(payload);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(t.ts_importTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(onPressed: _paste, icon: const Icon(Icons.content_paste_rounded)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ctrl,
                minLines: 8,
                maxLines: 12,
                onChanged: (_) => setState(() => _error = null),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: InputDecoration(hintText: t.ts_importPlaceholder),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(t.ts_public),
                value: _public,
                onChanged: (v) => setState(() => _public = v),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!, style: TextStyle(color: c.error, fontSize: 13)),
                ),
              Row(
                children: [
                  Expanded(
                    child: GameButton(
                      label: t.ts_cancel,
                      variant: ButtonVariant.muted,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: GameButton(label: t.ts_importBtn, loading: _submitting, onPressed: _submit)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
