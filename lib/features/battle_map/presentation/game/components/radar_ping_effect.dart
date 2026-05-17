import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class _SonarRing {
  final Color color;
  final double maxRadius;
  final double speed;
  double radius = 0;
  double opacity = 0.8;
  double _delay;

  _SonarRing({
    required this.color,
    required this.maxRadius,
    required this.speed,
    double delay = 0,
  }) : _delay = delay;

  bool get isDone => _delay <= 0 && opacity <= 0.01;
  bool get isActive => _delay <= 0;

  void advance(double dt) {
    if (_delay > 0) {
      _delay = (_delay - dt).clamp(0, double.infinity);
      return;
    }
    radius += speed * dt;
    opacity = ((1.0 - radius / maxRadius) * 0.8).clamp(0.0, 0.8);
  }
}

/// Standalone Flame component that emits 3 staggered sonar rings and removes
/// itself once all rings have fully faded. Position should be the world-space
/// centre of the tile that triggered it.
class RadarPingEffect extends PositionComponent {
  final List<_SonarRing> _rings = [];

  RadarPingEffect({
    required Vector2 position,
    required Color ringColor,
    double maxRadius = 40.0,
    double speed = 80.0,
  }) : super(position: position, anchor: Anchor.center) {
    for (int i = 0; i < 3; i++) {
      _rings.add(
        _SonarRing(
          color: ringColor,
          maxRadius: maxRadius,
          speed: speed,
          delay: i * 0.18,
        ),
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    for (final ring in _rings) {
      ring.advance(dt);
    }
    _rings.removeWhere((r) => r.isDone);
    if (_rings.isEmpty) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    for (final ring in _rings) {
      if (!ring.isActive) continue;
      canvas.drawCircle(
        Offset.zero,
        ring.radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = ring.color.withValues(alpha:ring.opacity),
      );
    }
  }
}
