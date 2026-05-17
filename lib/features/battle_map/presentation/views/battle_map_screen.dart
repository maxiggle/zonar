import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/battle_map_bloc.dart';
import '../game/submarine_flame_game.dart';
import 'widgets/game_controls_overlay.dart';
import 'widgets/status_hud.dart';

class BattleMapScreen extends StatefulWidget {
  const BattleMapScreen({super.key});

  @override
  State<BattleMapScreen> createState() => _BattleMapScreenState();
}

class _BattleMapScreenState extends State<BattleMapScreen> {
  late final SubmarineFlameGame _game;

  @override
  void initState() {
    super.initState();
    _game = SubmarineFlameGame(
      // context.read is safe in the lambda — it runs after the tree is built
      onTileSelected: (index) =>
          context.read<BattleMapBloc>().add(StrikeCoordinate(index)),
    );
  }

  /// Pushes every tile state from the BLoC into the Flame canvas.
  /// TileComponent.displayState setter is a no-op when the state is unchanged.
  void _synchronizeGameEngine(BattleMapState state) {
    for (final entry in state.revealedTiles.entries) {
      switch (entry.value) {
        case TileDisplayState.processing:
          _game.setTileProcessing(entry.key);
        case TileDisplayState.hit:
          _game.updateTile(entry.key, TileDisplayState.hit);
        case TileDisplayState.miss:
          _game.updateTile(entry.key, TileDisplayState.miss);
        case TileDisplayState.unrevealed:
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<BattleMapBloc, BattleMapState>(
      listener: (_, state) => _synchronizeGameEngine(state),
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1B2A),
        body: Stack(
          children: [
            // Full-screen Flame canvas — never rebuilt by Flutter
            GameWidget(game: _game),

            // Flutter HUD overlays — rebuilt by their own BlocBuilders
            SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [StatusHud(), GameControlsOverlay()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
