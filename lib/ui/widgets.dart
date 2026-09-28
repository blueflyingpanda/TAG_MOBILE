import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

enum ButtonVariant { success, error, muted, neutral }

/// Brand button with a springy press-scale (web: framer `whileTap: 0.95`).
class GameButton extends StatefulWidget {
  const GameButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = ButtonVariant.success,
    this.expand = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    this.icon,
    this.loading = false,
    this.fontSize = 16,
  });

  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final bool expand;
  final EdgeInsets padding;
  final IconData? icon;
  final bool loading;
  final double fontSize;

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (bg, fg, border) = switch (widget.variant) {
      ButtonVariant.success => (c.success, Colors.white, null),
      ButtonVariant.error => (c.error, Colors.white, null),
      ButtonVariant.neutral => (c.text, c.card, null),
      ButtonVariant.muted => (c.textA(0.06), c.text, c.textA(0.15)),
    };

    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        else if (widget.icon != null)
          Icon(widget.icon, size: 20, color: fg),
        if (widget.loading || widget.icon != null) const SizedBox(width: 8),
        Flexible(
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: widget.fontSize,
            ),
          ),
        ),
      ],
    );

    return AnimatedScale(
      scale: _pressed ? 0.95 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        opacity: _enabled || widget.loading ? 1 : 0.5,
        duration: const Duration(milliseconds: 150),
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: gameBorderRadius,
            side: border == null ? BorderSide.none : BorderSide(color: border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _enabled
                ? () {
                    HapticFeedback.selectionClick();
                    widget.onPressed!();
                  }
                : null,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            child: Padding(padding: widget.padding, child: content),
          ),
        ),
      ),
    );
  }
}

/// Rounded brand card surface (web: `rounded-game bg-card p-6 shadow-sm`).
class GameCard extends StatelessWidget {
  const GameCard({super.key, required this.child, this.padding = const EdgeInsets.all(20)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: gameBorderRadius,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }
}

/// Subtle inset tile (web: `border border-text/10 bg-text/[0.04]`).
class Tile extends StatelessWidget {
  const Tile({super.key, required this.child, this.padding = const EdgeInsets.all(12), this.onTap, this.color});

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: color ?? c.textA(0.04),
      shape: RoundedRectangleBorder(
        borderRadius: gameBorderRadius,
        side: BorderSide(color: c.textA(0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      );
}

/// 1–5 star picker (web: ★ buttons).
class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.value, required this.onChanged, this.size = 30});

  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(i);
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: size * 0.12, vertical: 4),
              child: AnimatedScale(
                scale: i <= value ? 1 : 0.9,
                duration: const Duration(milliseconds: 150),
                child: Text(
                  '★',
                  style: TextStyle(fontSize: size, color: i <= value ? c.success : c.textA(0.35)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Seconds display with a quick flip per tick (web: ui/Countdown.tsx).
class Countdown extends StatelessWidget {
  const Countdown({super.key, required this.seconds, this.warning = false});

  final int seconds;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 40,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 120),
        switchInCurve: Curves.easeOut,
        transitionBuilder: (child, anim) {
          final incoming = child.key == ValueKey(seconds);
          final slide = Tween<Offset>(
            begin: Offset(0, incoming ? 0.15 : -0.15),
            end: Offset.zero,
          ).animate(anim);
          return FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: slide,
              child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(anim), child: child),
            ),
          );
        },
        child: Text(
          '${seconds}s',
          key: ValueKey(seconds),
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: warning ? c.error : c.text,
          ),
        ),
      ),
    );
  }
}

/// Rolling counter: new value drops in from above, old one falls out below
/// (web: ui/Counter.tsx).
class RollingCounter extends StatelessWidget {
  const RollingCounter({super.key, required this.value, required this.color, this.fontSize = 32});

  final int value;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        height: fontSize * 1.1,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeIn,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.center,
            children: [...previous, ?current],
          ),
          transitionBuilder: (child, anim) {
            final incoming = child.key == ValueKey(value);
            return SlideTransition(
              position: Tween<Offset>(
                begin: Offset(0, incoming ? -1 : 1),
                end: Offset.zero,
              ).animate(anim),
              child: FadeTransition(opacity: anim, child: child),
            );
          },
          child: Text(
            '$value',
            key: ValueKey(value),
            style: TextStyle(
              fontSize: fontSize,
              height: 1,
              fontWeight: FontWeight.w600,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

/// Centered message + optional action, for loading/error/empty states.
class StatusView extends StatelessWidget {
  const StatusView({super.key, required this.message, this.isError = false, this.action});

  final String message;
  final bool isError;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: isError ? c.error : c.textA(0.7), fontSize: 16),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

void showToast(BuildContext context, String message, {bool error = false}) {
  final c = context.colors;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? c.error : c.text,
    ));
}
