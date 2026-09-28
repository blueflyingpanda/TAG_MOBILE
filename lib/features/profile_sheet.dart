import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../data/models.dart';
import '../state/providers.dart';
import '../ui/widgets.dart';

/// Avatar in the app bar; opens account + preferences (web: header bar).
class ProfileButton extends ConsumerWidget {
  const ProfileButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final t = ref.watch(tProvider);
    if (user == null) return const SizedBox.shrink();
    return IconButton(
      tooltip: t.nav_profileAlt,
      onPressed: () => showModalBottomSheet(context: context, builder: (_) => const ProfileSheet()),
      icon: Avatar(user: user, size: 32),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.user, required this.size});

  final User user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final initial = Text(
      user.username.isEmpty ? '?' : user.username[0].toUpperCase(),
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * 0.45),
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.primary,
        border: Border.all(color: c.textA(0.15), width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: user.picture == null
          ? initial
          : Image.network(
              user.picture!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => initial,
            ),
    );
  }
}

class ProfileSheet extends ConsumerWidget {
  const ProfileSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final t = ref.watch(tProvider);
    final c = context.colors;
    final locale = ref.watch(localeProvider);
    final mode = ref.watch(themeModeProvider);
    final platformDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final isDark = mode == ThemeMode.dark || (mode == ThemeMode.system && platformDark);
    if (user == null) return const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Avatar(user: user, size: 64),
            const SizedBox(height: 10),
            Text(user.username, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            if (user.email != null) Text(user.email!, style: TextStyle(color: c.textA(0.7))),
            const SizedBox(height: 20),
            Tile(
              color: c.card,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.translate_rounded),
                    title: Text(locale == 'en' ? t.ts_langEnglish : t.ts_langRussian),
                    trailing: SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 'en', label: Text('🇬🇧')),
                        ButtonSegment(value: 'ru', label: Text('🇷🇺')),
                      ],
                      selected: {locale},
                      onSelectionChanged: (s) => ref.read(localeProvider.notifier).set(s.first),
                    ),
                  ),
                  Divider(height: 1, color: c.textA(0.08)),
                  SwitchListTile.adaptive(
                    secondary: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded),
                    title: Text(t.nav_toggleDark),
                    value: isDark,
                    onChanged: (v) => ref.read(themeModeProvider.notifier).set(v ? ThemeMode.dark : ThemeMode.light),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GameButton(
              label: t.nav_logout,
              variant: ButtonVariant.error,
              icon: Icons.logout_rounded,
              onPressed: () {
                Navigator.pop(context);
                ref.read(authProvider.notifier).logout();
              },
            ),
          ],
        ),
      ),
    );
  }
}
