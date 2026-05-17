import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import '../submarine_flame_game.dart';
import '../../bloc/battle_map_bloc.dart';

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

class TileComponent extends PositionComponent
    with TapCallbacks, HasGameReference<SubmarineFlameGame> {
  final int index;
  final void Function(int) onSelected;

  TileDisplayState _displayState = TileDisplayState.unrevealed;

  // Idle breath — sine oscillation on fill opacity
  double _breathTime = 0;
  double _breathOpacity = 0.15;

  // Sonar rings
  final List<_SonarRing> _rings = [];
  bool _processingLoop = false;
  double _processingTimer = 0;

  // Hit white-flash decay
  double _flashOpacity = 0;

  TileComponent({
    required this.index,
    required this.onSelected,
    required Vector2 position,
    required Vector2 size,
  }) : super(position: position, size: size);

  TileDisplayState get displayState => _displayState;

  set displayState(TileDisplayState next) {
    if (_displayState == next) return;
    _displayState = next;
    _rings.clear();
    _processingLoop = false;
    _processingTimer = 0;

    switch (next) {
      case TileDisplayState.processing:
        _processingLoop = true;
        _spawnRings(const Color(0xFF00FFD1));
      case TileDisplayState.hit:
        _flashOpacity = 1.0;
        _spawnRings(const Color(0xFFFF4444));
        if (isMounted) game.triggerImpactShake();
      case TileDisplayState.miss:
        _spawnRings(const Color(0xFF2A4A6B));
      case TileDisplayState.unrevealed:
        break;
    }
  }

  void _spawnRings(Color color) {
    final maxR = size.x * 0.78;
    final speed = size.x * 1.4;
    for (int i = 0; i < 3; i++) {
      _rings.add(
        _SonarRing(color: color, maxRadius: maxR, speed: speed, delay: i * 0.16),
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_displayState == TileDisplayState.unrevealed) {
      _breathTime += dt;
      _breathOpacity =
          0.15 + 0.18 * ((sin(_breathTime * (2 * pi / 2.5)) + 1) / 2);
    }

    if (_processingLoop) {
      _processingTimer += dt;
      if (_processingTimer >= 1.3) {
        _processingTimer = 0;
        _spawnRings(const Color(0xFF00FFD1));
      }
    }

    for (final ring in _rings) {
      ring.advance(dt);
    }
    _rings.removeWhere((r) => r.isDone);

    if (_flashOpacity > 0) {
      _flashOpacity = (_flashOpacity - dt * 3.5).clamp(0.0, 1.0);
    }
  }

  @override
  void render(Canvas canvas) {
    final rect = size.toRect();
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(size.x * 0.09));

    // Tile fill
    canvas.drawRRect(rr, Paint()..color = _fillColor);

    // Hit flash overlay
    if (_flashOpacity > 0) {
      canvas.drawRRect(
        rr,
        Paint()..color = Colors.white.withValues(alpha:_flashOpacity * 0.55),
      );
    }

    // Border
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = const Color(0xFFE0F4FF).withValues(alpha:
          _displayState == TileDisplayState.unrevealed ? 0.18 : 0.40,
        ),
    );

    // Sonar rings (local tile coordinates, centred)
    final cx = size.x / 2;
    final cy = size.y / 2;
    for (final ring in _rings) {
      if (!ring.isActive) continue;
      canvas.drawCircle(
        Offset(cx, cy),
        ring.radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = ring.color.withValues(alpha:ring.opacity),
      );
    }

    // Hit cross / miss dot
    if (_displayState == TileDisplayState.hit) {
      _renderCross(canvas, cx, cy);
    } else if (_displayState == TileDisplayState.miss) {
      _renderDot(canvas, cx, cy);
    }
  }

  Color get _fillColor {
    switch (_displayState) {
      case TileDisplayState.unrevealed:
        return const Color(0xFF0D1B2A).withValues(alpha:_breathOpacity + 0.62);
      case TileDisplayState.processing:
        return const Color(0xFF0D1B2A).withValues(alpha:0.88);
      case TileDisplayState.miss:
        return const Color(0xFF2A4A6B).withValues(alpha:0.88);
      case TileDisplayState.hit:
        return const Color(0xFFFF4444).withValues(alpha:0.82);
    }
  }

  void _renderCross(Canvas canvas, double cx, double cy) {
    final r = size.x * 0.17;
    final p = Paint()
      ..color = Colors.white.withValues(alpha:0.72)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx - r, cy - r), Offset(cx + r, cy + r), p);
    canvas.drawLine(Offset(cx + r, cy - r), Offset(cx - r, cy + r), p);
  }

  void _renderDot(Canvas canvas, double cx, double cy) {
    canvas.drawCircle(
      Offset(cx, cy),
      size.x * 0.11,
      Paint()
        ..color = const Color(0xFFE0F4FF).withValues(alpha:0.38)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool onTapDown(TapDownEvent event) {
    if (_displayState == TileDisplayState.unrevealed) {
      onSelected(index);
    }
    return true;
  }
}
