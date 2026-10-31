import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tag/features/themes/word_editor.dart';

void main() {
  for (final ok in [true, false]) {
    testWidgets('prompt dialog closes cleanly (ok=$ok)', (tester) async {
      String? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  result = await promptForText(context, message: 'm', ok: 'Import', cancel: 'Cancel'),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'a\nb');
      await tester.tap(find.text(ok ? 'Import' : 'Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(result, ok ? 'a\nb' : null);
    });
  }
}
