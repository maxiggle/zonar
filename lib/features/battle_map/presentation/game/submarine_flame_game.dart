import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'components/tile_component.dart';
import 'components/radar_ping_effect.dart';
import '../bloc/battle_map_bloc.dart';

class SubmarineFlameGame extends FlameGame {
  final void Function(int index) onTileSelected;
  final List<TileComponent> _tiles = [];

  static const int _gridSize = 10;
  static const double _sidePadding = 0.06;
  static const double _topReserve = 0.18; // reserve top 18% for HUD

  SubmarineFlameGame({required this.onTileSelected});

  @override
  Color backgroundColor() => const Color(0xFF0D1B2A);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final sw = size.x;
    final sh = size.y;

    final availableW = sw * (1 - _sidePadding * 2);
    final tileSize = availableW / _gridSize;
    final offsetX = sw * _sidePadding;
    final gridHeight = tileSize * _gridSize;
    final topMargin = sh * _topReserve;
    final offsetY = topMargin + (sh - topMargin - gridHeight) / 2;

    // Subtle animated scan-line
    add(_ScanLineComponent(gameSize: size));

    // Grid coordinate labels
    _addLabels(offsetX, offsetY, tileSize);

    // 10×10 tile grid
    for (int row = 0; row < _gridSize; row++) {
      for (int col = 0; col < _gridSize; col++) {
        final idx = row * _gridSize + col;
        final tile = TileComponent(
          index: idx,
          onSelected: onTileSelected,
          position: Vector2(offsetX + col * tileSize + 1, offsetY + row * tileSize + 1),
          size: Vector2.all(tileSize - 2),
        );
        _tiles.add(tile);
        add(tile);
      }
    }
  }

  void _addLabels(double offsetX, double offsetY, double tileSize) {
    const cols = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10'];
    const rows = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J'];
    final labelStyle = TextPaint(
      style: const TextStyle(
        color: Color(0xFF4A6E8A),
        fontSize: 9,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );

    for (int i = 0; i < _gridSize; i++) {
      // Row letter labels (left side)
      add(TextComponent(
        text: rows[i],
        position: Vector2(offsetX - tileSize * 0.55, offsetY + i * tileSize + tileSize * 0.32),
        textRenderer: labelStyle,
      ));
      // Column number labels (top)
      add(TextComponent(
        text: cols[i],
        position: Vector2(
          offsetX + i * tileSize + (i < 9 ? tileSize * 0.38 : tileSize * 0.28),
          offsetY - tileSize * 0.55,
        ),
        textRenderer: labelStyle,
      ));
    }
  }

  // Called by BattleMapScreen._synchronizeGameEngine
  void updateTile(int index, TileDisplayState state) {
    if (index < 0 || index >= _tiles.length) return;
    _tiles[index].displayState = state;

    // Standalone world-space ping for extra visual weight
    final tilePos = _tiles[index].position;
    final tileSize = _tiles[index].size;
    add(RadarPingEffect(
      position: tilePos + tileSize / 2,
      ringColor: state == TileDisplayState.hit
          ? const Color(0xFFFF4444)
          : const Color(0xFF2A4A6B),
      maxRadius: tileSize.x * 1.6,
      speed: tileSize.x * 2.2,
    ));
  }

  void setTileProcessing(int index) {
    if (index < 0 || index >= _tiles.length) return;
    _tiles[index].displayState = TileDisplayState.processing;
  }

  // Fix #3 — camera micro-shake on hit via MoveEffect on viewfinder
  void triggerImpactShake() {
    camera.viewfinder.add(
      MoveEffect.by(
        Vector2(4, -4),
        EffectController(duration: 0.08, alternate: true, repeatCount: 3),
      ),
    );
  }

  // Fix #4 — hot-reload / disposal safety
  @override
  void onRemove() {
    _tiles.clear();
    super.onRemove();
  }
}

/// Slow horizontal scan-line that drifts down the board for atmosphere.
class _ScanLineComponent extends Component {
  final Vector2 gameSize;
  double _y = 0;
  final _rng = Random();
  double _glitchTimer = 0;
  double _glitchOpacity = 0;

  _ScanLineComponent({required this.gameSize});

  @override
  void update(double dt) {
    _y += gameSize.y * 0.06 * dt;
    if (_y > gameSize.y) _y = 0;

    // Occasional brief glitch flicker
    _glitchTimer += dt;
    if (_glitchTimer > 4 + _rng.nextDouble() * 6) {
      _glitchTimer = 0;
      _glitchOpacity = 0.04 + _rng.nextDouble() * 0.04;
    } else if (_glitchOpacity > 0) {
      _glitchOpacity = (_glitchOpacity - dt * 0.8).clamp(0.0, 0.1);
    }
  }

  @override
  void render(Canvas canvas) {
    // Primary scan stripe
    canvas.drawRect(
      Rect.fromLTWH(0, _y - 20, gameSize.x, 40),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFE0F4FF).withValues(alpha:0),
            const Color(0xFFE0F4FF).withValues(alpha:0.025),
            const Color(0xFFE0F4FF).withValues(alpha:0),
          ],
        ).createShader(Rect.fromLTWH(0, _y - 20, gameSize.x, 40)),
    );

    // Glitch overlay
    if (_glitchOpacity > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, gameSize.x, gameSize.y),
        Paint()..color = const Color(0xFF00FFD1).withValues(alpha:_glitchOpacity),
      );
    }
  }
}
