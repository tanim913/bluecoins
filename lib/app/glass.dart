import 'dart:ui';

import 'package:flutter/material.dart';

import 'theme.dart';

/// The liquid-glass look. Dark: a deep navy ground with soft glows and frosted, lit-edge panels.
/// Light: white panels lifted off a pale ground by layered shadows.
class _Look {
  const _Look(this.fill, this.strongFill, this.edge, this.shadows);
  final List<Color> fill, strongFill, edge;
  final List<BoxShadow> shadows;

  static const dark = _Look(
    [Color(0x24FFFFFF), Color(0x0DFFFFFF)],
    [Color(0xE01C2652), Color(0xF0121A3A)],
    [Color(0x57FFFFFF), Color(0x0FFFFFFF), Color(0x26FFFFFF)],
    [
      BoxShadow(
        color: Color(0x59000000),
        blurRadius: 32,
        offset: Offset(0, 14),
      ),
    ],
  );
  static const light = _Look(
    [Color(0xFFFFFFFF), Color(0xF5FFFFFF)],
    [Color(0xF5FFFFFF), Color(0xEBFFFFFF)],
    [Color(0xFFFFFFFF), Color(0xCCD3DDF1)],
    [
      BoxShadow(
        color: Color(0x1A2B385A),
        blurRadius: 32,
        offset: Offset(0, 14),
      ),
      BoxShadow(color: Color(0x0F2B385A), blurRadius: 6, offset: Offset(0, 2)),
    ],
  );

  static _Look of(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? dark : light;
}

/// A glass surface. [blur] frosts whatever scrolls behind it (use it on bars and sheets only:
/// on a plain ground it adds cost and no look). [strong] is the denser fill for sheets.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = const BorderRadius.all(Radius.circular(24)),
    this.padding,
    this.blur = false,
    this.strong = false,
    this.shadow = true,
  });
  final Widget child;
  final BorderRadius radius;
  final EdgeInsetsGeometry? padding;
  final bool blur, strong, shadow;

  @override
  Widget build(BuildContext context) {
    final look = _Look.of(context);
    Widget box = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: strong ? look.strongFill : look.fill,
        ),
      ),
      // Ink splashes (list tiles) must paint above the glass fill, so give them their own Material.
      child: Material(
        type: MaterialType.transparency,
        child: padding == null
            ? child
            : Padding(padding: padding!, child: child),
      ),
    );
    if (blur) {
      box = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: box,
        ),
      );
    }
    return CustomPaint(
      painter: shadow ? _Shadow(radius, look.shadows) : null,
      foregroundPainter: _Edge(radius, look.edge),
      child: box,
    );
  }
}

/// Paints only outside the shape, so a translucent fill is not darkened by its own shadow.
class _Shadow extends CustomPainter {
  _Shadow(this.radius, this.shadows);
  final BorderRadius radius;
  final List<BoxShadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = radius.toRRect(Offset.zero & size);
    canvas.save();
    canvas.clipPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.largest),
        Path()..addRRect(rrect),
      ),
    );
    for (final s in shadows) {
      canvas.drawRRect(rrect.shift(s.offset), s.toPaint());
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Shadow old) =>
      old.radius != radius || old.shadows != shadows;
}

/// A 1px rim that is lit at the top-left and fades, like light catching a glass edge.
class _Edge extends CustomPainter {
  _Edge(this.radius, this.colors);
  final BorderRadius radius;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      radius.toRRect(rect).deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_Edge old) => old.radius != radius || old.colors != colors;
}

/// The page ground: a deep gradient with soft glows for the glass to sit on.
class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({super.key});

  static Widget _glow(Alignment at, double radius, Color c) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: at,
        radius: radius,
        colors: [c, c.withValues(alpha: 0)],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: Theme.of(context).colorScheme.surface),
            _glow(
              const Alignment(0.95, -0.95),
              1.0,
              dark
                  ? indigo.withValues(alpha: 0.7)
                  : sky.withValues(alpha: 0.38),
            ),
            _glow(
              const Alignment(-1.1, -0.15),
              0.8,
              sky.withValues(alpha: dark ? 0.13 : 0.2),
            ),
            _glow(
              const Alignment(0.7, 0.05),
              0.7,
              sky.withValues(alpha: dark ? 0.1 : 0.14),
            ),
            _glow(
              const Alignment(0.9, 1.0),
              1.0,
              dark
                  ? navy.withValues(alpha: 0.8)
                  : indigo.withValues(alpha: 0.12),
            ),
          ],
        ),
      ),
    );
  }
}

/// A Scaffold that paints the glass ground itself, so it travels with the page in route
/// transitions instead of showing two pages through each other.
class GlassScaffold extends StatelessWidget {
  const GlassScaffold({
    super.key,
    this.appBar,
    this.body,
    this.floatingActionButton,
  });
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const GlassBackdrop(),
      Scaffold(
        backgroundColor: Colors.transparent,
        appBar: appBar,
        body: body,
        floatingActionButton: floatingActionButton,
      ),
    ],
  );
}

/// Wraps bottom-sheet content: frosted, rounded at the top, with its own drag handle.
class GlassSheet extends StatelessWidget {
  const GlassSheet({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Glass(
    blur: true,
    strong: true,
    shadow: false,
    radius: const BorderRadius.vertical(top: Radius.circular(28)),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.only(top: 10, bottom: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Flexible(child: child),
      ],
    ),
  );
}
