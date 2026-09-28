import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';

// Motion constants ported from TAG/src/components/GamePlayCardStack.tsx.
const _swipeDistance = 100.0;
const _swipeVelocity = 500.0;
const _dragLimit = 280.0;
const _exitDistance = 250.0;
const _cardSpring = SpringDescription(mass: 1, stiffness: 300, damping: 20);
const _snapBackSpring = SpringDescription(mass: 1, stiffness: 400, damping: 30);
const _exitDuration = Duration(milliseconds: 200);

/// A card pose: `scale`, vertical offset `y` and `opacity`.
class _Pose {
  const _Pose(this.scale, this.y, this.opacity);

  final double scale;
  final double y;
  final double opacity;

  static const front = _Pose(1, 0, 1);
  static const back = _Pose(0.75, 30, 0.5);
  static const enter = _Pose(0, 105, 0);

  static _Pose lerp(_Pose a, _Pose b, double t) => _Pose(
        a.scale + (b.scale - a.scale) * t,
        a.y + (b.y - a.y) * t,
        (a.opacity + (b.opacity - a.opacity) * t).clamp(0.0, 1.0),
      );
}

class _Exiting {
  _Exiting(this.id, this.word, this.fromX, this.direction);

  final int id;
  final String word;
  final double fromX;
  final int direction; // +1 guessed (right), -1 skipped (left)
}

/// Two-card deck: the front card is draggable; the back card rises into place
/// when the front one is flung away.
class CardStack extends StatefulWidget {
  const CardStack({
    super.key,
    required this.index,
    required this.currentWord,
    required this.backWord,
    required this.locked,
    required this.overlay,
    required this.onSwipe,
  });

  final int index;
  final String? currentWord;
  final String? backWord;

  /// Ignore drags (card exiting, paused, cheating detected).
  final bool locked;

  /// Replaces the deck (paused / cheating placeholders).
  final Widget? overlay;

  /// Called when a drag passes the swipe threshold.
  final ValueChanged<bool> onSwipe;

  @override
  State<CardStack> createState() => CardStackState();
}

class CardStackState extends State<CardStack> with TickerProviderStateMixin {
  final _dragX = ValueNotifier<double>(0);
  bool _dragging = false;
  late final AnimationController _snapBack = AnimationController.unbounded(vsync: this)
    ..addListener(() => _dragX.value = _snapBack.value);

  final List<_Exiting> _exiting = [];
  int _exitSeq = 0;

  /// Key of the front card that has been flung; hidden until the parent
  /// advances to the next word.
  String? _flungKey;

  String _keyFor(int index, String word) => '$index-$word';

  /// Throws the current front card off-screen (button press or swipe).
  void fling(bool guessed) {
    final word = widget.currentWord;
    if (word == null) return;
    HapticFeedback.lightImpact();
    _snapBack.stop();
    setState(() {
      _exiting.add(_Exiting(_exitSeq++, word, _dragX.value, guessed ? 1 : -1));
      _flungKey = _keyFor(widget.index, word);
      _dragging = false;
    });
    _dragX.value = 0;
  }

  @override
  void didUpdateWidget(CardStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index || oldWidget.currentWord != widget.currentWord) {
      _flungKey = null;
    }
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (widget.locked) return;
    _snapBack.stop();
    if (!_dragging) setState(() => _dragging = true);
    // Elastic resistance beyond the drag limit (web: dragElastic 0.1).
    var x = _dragX.value + d.delta.dx;
    if (x.abs() > _dragLimit) {
      x = x.sign * (_dragLimit + (x.abs() - _dragLimit) * 0.1);
    }
    _dragX.value = x;
  }

  void _onDragEnd(DragEndDetails d) {
    if (widget.locked) return;
    final x = _dragX.value;
    final vx = d.velocity.pixelsPerSecond.dx;
    setState(() => _dragging = false);
    if (x > _swipeDistance || vx > _swipeVelocity) {
      widget.onSwipe(true);
    } else if (x < -_swipeDistance || vx < -_swipeVelocity) {
      widget.onSwipe(false);
    } else {
      _snapBack.animateWith(SpringSimulation(_snapBackSpring, x, 0, vx));
    }
  }

  @override
  void dispose() {
    _snapBack.dispose();
    _dragX.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final size = math.min(300.0, box.maxWidth - 32);
      final current = widget.currentWord;
      final back = widget.backWord;
      final showDeck = widget.overlay == null;

      final frontKey = current == null ? null : _keyFor(widget.index, current);

      // Keys go on the Positioned slots so the back card's state (and its
      // spring) carries over when it's promoted to the front.
      Widget slot(String key, Widget child) =>
          Positioned(key: ValueKey(key), top: 16, width: size, height: size, child: child);

      return SizedBox(
        height: size + 40,
        width: double.infinity,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            if (showDeck && back != null)
              slot(_keyFor(widget.index + 1, back), _DeckCard(word: back, isFront: false, size: size)),
            if (showDeck && current != null && frontKey != _flungKey)
              slot(
                frontKey!,
                _DeckCard(
                  word: current,
                  isFront: true,
                  size: size,
                  dragX: _dragX,
                  dragging: _dragging,
                  onDragUpdate: _onDragUpdate,
                  onDragEnd: _onDragEnd,
                ),
              ),
            for (final e in _exiting)
              slot(
                'exit-${e.id}',
                _ExitingCard(data: e, size: size, onDone: () => setState(() => _exiting.remove(e))),
              ),
            if (widget.overlay != null) slot('overlay', _OverlayCard(size: size, child: widget.overlay!)),
          ],
        ),
      );
    });
  }
}

class _DeckCard extends StatefulWidget {
  const _DeckCard({
    required this.word,
    required this.isFront,
    required this.size,
    this.dragX,
    this.dragging = false,
    this.onDragUpdate,
    this.onDragEnd,
  });

  final String word;
  final bool isFront;
  final double size;
  final ValueNotifier<double>? dragX;
  final bool dragging;
  final GestureDragUpdateCallback? onDragUpdate;
  final GestureDragEndCallback? onDragEnd;

  @override
  State<_DeckCard> createState() => _DeckCardState();
}

class _DeckCardState extends State<_DeckCard> with SingleTickerProviderStateMixin {
  late final AnimationController _spring = AnimationController.unbounded(vsync: this, value: 1);
  late _Pose _from;
  late _Pose _to;

  @override
  void initState() {
    super.initState();
    if (widget.isFront) {
      // First card of a round appears in place (web: AnimatePresence initial={false}).
      _from = _to = _Pose.front;
    } else {
      _from = _Pose.enter;
      _to = _Pose.back;
      _run();
    }
  }

  @override
  void didUpdateWidget(_DeckCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isFront && widget.isFront) {
      // Promoted from the back of the deck: spring up to the front pose.
      _from = _current;
      _to = _Pose.front;
      _run();
    }
  }

  _Pose get _current => _Pose.lerp(_from, _to, _spring.value);

  void _run() => _spring.animateWith(SpringSimulation(_cardSpring, 0, 1, 0));

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final face = _CardFace(word: widget.word);
    final animated = AnimatedBuilder(
      animation: Listenable.merge([_spring, ?widget.dragX]),
      child: face,
      builder: (context, child) {
        final p = _current;
        final x = widget.dragX?.value ?? 0;
        // web: rotate = transform(x, [-220, 220], [-14deg, 14deg])
        final rotation = (x / 220).clamp(-1.0, 1.0) * 14 * math.pi / 180;
        final dragScale = widget.dragging ? 1.02 : 1.0;
        return Opacity(
          opacity: p.opacity,
          child: Transform.translate(
            offset: Offset(x, p.y),
            child: Transform.rotate(
              angle: rotation,
              child: Transform.scale(scale: math.max(0, p.scale) * dragScale, child: child),
            ),
          ),
        );
      },
    );

    if (!widget.isFront) return IgnorePointer(child: animated);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: widget.onDragUpdate,
      onHorizontalDragEnd: widget.onDragEnd,
      child: animated,
    );
  }
}

class _ExitingCard extends StatefulWidget {
  const _ExitingCard({required this.data, required this.size, required this.onDone});

  final _Exiting data;
  final double size;
  final VoidCallback onDone;

  @override
  State<_ExitingCard> createState() => _ExitingCardState();
}

class _ExitingCardState extends State<_ExitingCard> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: _exitDuration)
    ..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final fromRotation = (d.fromX / 220).clamp(-1.0, 1.0) * 14;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        child: _CardFace(word: d.word),
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_c.value);
          final x = d.fromX + (d.direction * _exitDistance - d.fromX) * t;
          final deg = fromRotation + (d.direction * 15 - fromRotation) * t;
          return Opacity(
            opacity: 1 - t,
            child: Transform.translate(
              offset: Offset(x, 0),
              child: Transform.rotate(
                angle: deg * math.pi / 180,
                child: Transform.scale(scale: 1 - 0.5 * t, child: child),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OverlayCard extends StatefulWidget {
  const _OverlayCard({required this.size, required this.child});

  final double size;
  final Widget child;

  @override
  State<_OverlayCard> createState() => _OverlayCardState();
}

class _OverlayCardState extends State<_OverlayCard> with SingleTickerProviderStateMixin {
  late final AnimationController _spring = AnimationController.unbounded(vsync: this)
    ..animateWith(SpringSimulation(_cardSpring, 0, 1, 0));

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _spring,
        child: widget.child,
        builder: (context, child) => Opacity(
          opacity: _spring.value.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.9 + 0.1 * _spring.value, child: child),
        ),
      );
}

class _CardFace extends StatelessWidget {
  const _CardFace({required this.word});

  final String word;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: gameBorderRadius,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Text(
        _capitalize(word),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: c.text, height: 1.15),
      ),
    );
  }

  // web: CSS `capitalize` — first letter of each word.
  static String _capitalize(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

/// Placeholder shown in place of the deck (paused / cheating detected).
class DeckPlaceholder extends StatelessWidget {
  const DeckPlaceholder({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.danger = false,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: danger ? Color.alphaBlend(c.error.withValues(alpha: 0.10), c.card) : c.card,
        borderRadius: gameBorderRadius,
        border: Border.all(color: danger ? c.error.withValues(alpha: 0.3) : c.textA(0.15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: c.textA(0.7))),
        ],
      ),
    );
  }
}
