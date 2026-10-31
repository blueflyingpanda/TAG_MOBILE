import 'dart:math' as math;

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
  const GameCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

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
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Subtle inset tile (web: `border border-text/10 bg-text/[0.04]`).
class Tile extends StatelessWidget {
  const Tile({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.onTap,
    this.color,
  });

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
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// 16:9 theme cover. Always reserves its area, so cards keep the same size
/// with or without an image (placeholder when [url] is null or fails to load).
class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    this.url,
    this.bytes,
    this.borderRadius = BorderRadius.zero,
  });

  final String? url;
  final Uint8List? bytes;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final placeholder = ColoredBox(
      color: c.textA(0.06),
      child: Center(
        child: Icon(Icons.image_outlined, size: 32, color: c.textA(0.3)),
      ),
    );
    final Widget image;
    if (bytes != null) {
      image = Image.memory(bytes!, fit: BoxFit.cover, gaplessPlayback: true);
    } else if (url != null) {
      image = Stack(
        fit: StackFit.expand,
        children: [
          placeholder,
          Image.network(
            url!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
            frameBuilder: (_, child, frame, sync) => AnimatedOpacity(
              opacity: frame == null && !sync ? 0 : 1,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: child,
            ),
          ),
        ],
      );
    } else {
      image = placeholder;
    }
    return ClipRRect(
      borderRadius: borderRadius,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: SizedBox.expand(child: image),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
    ),
  );
}

/// 1–5 star picker (web: ★ buttons).
class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 30,
  });

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
              padding: EdgeInsets.symmetric(
                horizontal: size * 0.12,
                vertical: 4,
              ),
              child: AnimatedScale(
                scale: i <= value ? 1 : 0.9,
                duration: const Duration(milliseconds: 150),
                child: Text(
                  '★',
                  style: TextStyle(
                    fontSize: size,
                    color: i <= value ? c.success : c.textA(0.35),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Seconds display with a quick flip per tick (web: ui/Countdown.tsx).
class Countdown extends StatefulWidget {
  const Countdown({super.key, required this.seconds, this.warning = false});

  final int seconds;
  final bool warning;

  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(Countdown old) {
    super.didUpdateWidget(old);
    _syncPulse();
  }

  void _syncPulse() {
    final animate = widget.warning && !MediaQuery.disableAnimationsOf(context);
    if (animate && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!animate && _pulse.isAnimating) {
      _pulse.animateTo(0, duration: const Duration(milliseconds: 150));
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final seconds = widget.seconds;
    return SizedBox(
      height: 40,
      child: ScaleTransition(
        scale: Tween(
          begin: 1.0,
          end: 1.12,
        ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
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
                child: ScaleTransition(
                  scale: Tween(begin: 0.92, end: 1.0).animate(anim),
                  child: child,
                ),
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
              color: widget.warning ? c.error : c.text,
            ),
          ),
        ),
      ),
    );
  }
}

/// Rolling counter: new value drops in from above, old one falls out below
/// (web: ui/Counter.tsx).
class RollingCounter extends StatelessWidget {
  const RollingCounter({
    super.key,
    required this.value,
    required this.color,
    this.fontSize = 32,
  });

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
  const StatusView({
    super.key,
    required this.message,
    this.isError = false,
    this.action,
    this.icon,
  });

  final String message;
  final bool isError;
  final Widget? action;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 48, color: c.textA(0.3)),
              const SizedBox(height: 12),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isError ? c.error : c.textA(0.7),
                fontSize: 16,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Gently pulsing opacity for skeleton placeholders.
class Pulse extends StatefulWidget {
  const Pulse({super.key, required this.child});

  final Widget child;

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);
  late final Animation<double> _opacity = Tween(
    begin: 0.5,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _opacity, child: widget.child);
}

/// Rounded grey block used to build skeletons.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height, this.radius = 8});

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: context.colors.textA(0.08),
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// Same layout and size as the real theme tile (16:9 cover, title row, 2-line summary).
class ThemeTileSkeleton extends StatelessWidget {
  const ThemeTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pulse(
      child: Tile(
        color: c.card,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(color: c.textA(0.06)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 24,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SkeletonBox(width: 180, height: 16),
                    ),
                  ),
                  SizedBox(height: 6),
                  SizedBox(
                    height: 36,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(height: 12),
                        SizedBox(height: 8),
                        SkeletonBox(width: 140, height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? c.error : c.text,
      ),
    );
}

/// Small colour marker for a team in score lists.
class TeamDot extends StatelessWidget {
  const TeamDot({super.key, required this.color, this.size = 10});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// One-shot confetti burst (~3s) drawn with a CustomPainter; skipped when
/// the platform asks for reduced motion.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key});

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );
  late final List<_Particle> _particles = _makeParticles();
  bool _started = false;

  static List<_Particle> _makeParticles() {
    final rnd = math.Random();
    return [
      for (var i = 0; i < 90; i++)
        _Particle(
          x: rnd.nextDouble(),
          drift: (rnd.nextDouble() - 0.5) * 0.35,
          delay: rnd.nextDouble() * 0.35,
          speed: 0.55 + rnd.nextDouble() * 0.45,
          spin: rnd.nextDouble() * math.pi * 4,
          size: 6 + rnd.nextDouble() * 6,
          color: teamPalette[rnd.nextInt(teamPalette.length)],
        ),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && !MediaQuery.disableAnimationsOf(context)) {
      _started = true;
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_particles, _ctrl.value),
        ),
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.x,
    required this.drift,
    required this.delay,
    required this.speed,
    required this.spin,
    required this.size,
    required this.color,
  });

  final double x;
  final double drift;
  final double delay;
  final double speed;
  final double spin;
  final double size;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.particles, this.t);

  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final fall = Curves.easeIn.transform(local) * p.speed;
      final dx = (p.x + p.drift * local) * size.width;
      final dy = -p.size + fall * (size.height + p.size * 2);
      final opacity = local > 0.8 ? (1 - local) / 0.2 : 1.0;
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(p.spin * local);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: p.size,
          height: p.size * 0.5,
        ),
        Paint()..color = p.color.withValues(alpha: opacity),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
