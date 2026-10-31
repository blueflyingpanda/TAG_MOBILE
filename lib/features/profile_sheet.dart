import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/providers.dart';
import '../ui/widgets.dart';

/// Guests are sent to the sign-in screen. Returns true when signed in.
bool requireLogin(BuildContext context, WidgetRef ref) {
  if (ref.read(authProvider) != null) return true;
  context.push('/login');
  return false;
}

/// Avatar in the app bar; opens account + preferences (web: header bar).
class ProfileButton extends ConsumerWidget {
  const ProfileButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final t = ref.watch(tProvider);
    return IconButton(
      tooltip: t.nav_profileAlt,
      onPressed: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => const ProfileSheet(),
      ),
      icon: user == null
          ? const Icon(Icons.account_circle_outlined, size: 32)
          : Avatar(user: user, size: 32),
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
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: size * 0.45,
      ),
    );
    final picture = user.picture;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: c.primary),
      // Border is painted over the photo so the image fills the whole circle.
      foregroundDecoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: c.textA(0.15), width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: picture == null || picture.isEmpty
          ? initial
          : Image.network(
              picture,
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

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final t = ref.read(tProvider);
    final c = context.colors;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.nav_deleteAccountTitle),
        content: Text(t.nav_deleteAccountBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.ct_cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: c.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.nav_deleteAccountConfirm),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    Navigator.pop(context);
    try {
      await ref.read(authProvider.notifier).deleteAccount();
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(t.nav_deleteAccountFailed),
          backgroundColor: c.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final t = ref.watch(tProvider);
    final c = context.colors;
    final locale = ref.watch(localeProvider);
    final mode = ref.watch(themeModeProvider);
    final platformDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final isDark =
        mode == ThemeMode.dark || (mode == ThemeMode.system && platformDark);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (user != null) ...[
              Avatar(user: user, size: 64),
              const SizedBox(height: 10),
              Text(
                user.username,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (user.email != null)
                Text(user.email!, style: TextStyle(color: c.textA(0.7))),
              const SizedBox(height: 20),
            ],
            Tile(
              color: c.card,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.translate_rounded),
                    title: Text(
                      locale == 'en' ? t.ts_langEnglish : t.ts_langRussian,
                    ),
                    trailing: SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 'en', label: Text('🇬🇧')),
                        ButtonSegment(value: 'ru', label: Text('🇷🇺')),
                      ],
                      selected: {locale},
                      onSelectionChanged: (s) =>
                          ref.read(localeProvider.notifier).set(s.first),
                    ),
                  ),
                  Divider(height: 1, color: c.textA(0.08)),
                  SwitchListTile.adaptive(
                    secondary: Icon(
                      isDark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                    ),
                    title: Text(t.nav_toggleDark),
                    value: isDark,
                    onChanged: (v) => ref
                        .read(themeModeProvider.notifier)
                        .set(v ? ThemeMode.dark : ThemeMode.light),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (user == null)
              GameButton(
                label: t.nav_login,
                icon: Icons.login_rounded,
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/login');
                },
              )
            else
              GameButton(
                label: t.nav_logout,
                variant: ButtonVariant.error,
                icon: Icons.logout_rounded,
                onPressed: () {
                  Navigator.pop(context);
                  ref.read(authProvider.notifier).logout();
                },
              ),
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                  onPressed: () => launchUrl(
                    Uri.parse(privacyPolicyUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Text(
                    t.nav_privacyPolicy,
                    style: TextStyle(color: c.textA(0.7)),
                  ),
                ),
                if (user != null) ...[
                  Text('•', style: TextStyle(color: c.textA(0.4))),
                  TextButton(
                    onPressed: () => _confirmDelete(context, ref),
                    child: Text(
                      t.nav_deleteAccount,
                      style: TextStyle(color: c.error),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
