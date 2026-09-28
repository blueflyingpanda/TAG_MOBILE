import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../ui/widgets.dart';

/// Editable row with its own controller; identity survives reordering/removal.
class EditableEntry {
  EditableEntry([String text = '', this.difficulty = 1]) : ctrl = TextEditingController(text: text);

  final TextEditingController ctrl;
  int difficulty;

  String get text => ctrl.text;
  String get trimmed => ctrl.text.trim();
}

int wordCount(String s) => s.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

/// Parses "one word per line" or `{"word": {"difficulty": n}}` JSON
/// (web: CreateTheme `importWords`).
List<EditableEntry> parseWordImport(String text) {
  try {
    final parsed = jsonDecode(text);
    if (parsed is Map) {
      return [
        for (final e in parsed.entries)
          EditableEntry(
            e.key.toString(),
            (e.value is Map && (e.value as Map)['difficulty'] is num)
                ? ((e.value as Map)['difficulty'] as num).toInt()
                : 1,
          ),
      ];
    }
  } catch (_) {}
  return [
    for (final line in text.split('\n'))
      if (line.trim().isNotEmpty) EditableEntry(line.trim()),
  ];
}

class WordRow extends StatelessWidget {
  const WordRow({
    super.key,
    required this.entry,
    required this.placeholder,
    required this.onChanged,
    this.onRemove,
    this.autofocus = false,
  });

  final EditableEntry entry;
  final String placeholder;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: entry.ctrl,
                  autofocus: autofocus,
                  maxLength: 64,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => onChanged(),
                  decoration: InputDecoration(hintText: placeholder, counterText: '', isDense: true),
                ),
              ),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  icon: Icon(Icons.remove_circle_outline_rounded, color: c.error),
                ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: StarRating(
              value: entry.difficulty,
              size: 20,
              onChanged: (v) {
                entry.difficulty = v;
                onChanged();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ErrorBox extends StatelessWidget {
  const ErrorBox(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.error.withValues(alpha: 0.1),
        borderRadius: gameBorderRadius,
        border: Border.all(color: c.error.withValues(alpha: 0.4)),
      ),
      child: Text(message, style: TextStyle(color: c.error, fontSize: 14)),
    );
  }
}

Future<String?> promptForText(BuildContext context, {required String message, required String ok, required String cancel}) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 12),
          TextField(controller: ctrl, minLines: 6, maxLines: 10, autofocus: true),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, ctrl.text), child: Text(ok)),
      ],
    ),
  ).whenComplete(ctrl.dispose);
}

GameButton addButton(String label, VoidCallback? onPressed) => GameButton(
      label: label,
      expand: false,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      fontSize: 14,
      onPressed: onPressed,
    );
