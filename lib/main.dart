import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/storage.dart';
import 'core/theme.dart';
import 'router.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final (storage, _) = await (AppStorage.init(), initializeDateFormatting()).wait;

  runApp(ProviderScope(
    overrides: [storageProvider.overrideWithValue(storage)],
    child: const TagApp(),
  ));
}

class TagApp extends ConsumerWidget {
  const TagApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'T.A.G.',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      locale: Locale(ref.watch(localeProvider)),
      supportedLocales: const [Locale('en'), Locale('ru')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider),
      // Transparent, edge-to-edge system bars on every screen (not just ones with an AppBar).
      builder: (context, child) => AnnotatedRegion(
        value: systemBarsStyle(Theme.of(context).brightness),
        child: child!,
      ),
    );
  }
}
