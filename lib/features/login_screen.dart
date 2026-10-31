import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../data/auth.dart';
import '../state/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _loading = false;
  bool _closed = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).signInWithGoogle();
    } on SignInCancelled {
      // User backed out of the account picker — not an error.
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _close() {
    if (_closed) return;
    _closed = true;
    context.canPop() ? context.pop() : context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final c = context.colors;

    // Leave as soon as a session exists, even if this screen was rebuilt mid sign-in.
    if (ref.watch(authProvider) != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _close();
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutBack,
              builder: (context, v, child) => Opacity(
                opacity: v.clamp(0.0, 1.0),
                child: Transform.scale(scale: 0.92 + 0.08 * v, child: child),
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 340),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: gameBorderRadius,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset('assets/tag.jpeg', width: 88, height: 88, fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 16),
                    const Text('T.A.G.', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(t.login_subtitle, style: TextStyle(color: c.textA(0.7))),
                    const SizedBox(height: 16),
                    Text(
                      t.login_required,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.textA(0.7), fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    _GoogleButton(label: _loading ? t.login_loading : t.login_google, loading: _loading, onTap: _signIn),
                    const SizedBox(height: 8),
                    TextButton(onPressed: _loading ? null : _close, child: Text(t.login_guest)),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: c.error, fontSize: 13)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.label, required this.loading, required this.onTap});

  final String label;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: gameBorderRadius,
        side: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: loading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF222222)),
                )
              else
                const Text('G',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF4285F4))),
              const SizedBox(width: 12),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF222222))),
            ],
          ),
        ),
      ),
    );
  }
}
