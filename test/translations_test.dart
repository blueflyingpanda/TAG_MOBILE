import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tag/i18n/translations.dart';

void main() {
  test('generated translations render real characters, not escape codes', () {
    expect(ru.td_language('EN'), 'Язык: EN');
    expect(ru.td_visibility(true), 'Видимость: Публичная');
    expect(en.ct_nameCounter(3, 1), '3/64 characters • 1/10 words');
    expect(ru.gp_round(2), 'Раунд 2');
  });

  test('generated file contains no leftover \\u escapes', () {
    final src = File('lib/i18n/translations.dart').readAsStringSync();
    expect(RegExp(r'\\u[0-9A-Fa-f]{4}').hasMatch(src), isFalse);
  });
}
