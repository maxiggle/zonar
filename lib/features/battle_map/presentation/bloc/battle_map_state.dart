part of 'battle_map_bloc.dart';

enum TileDisplayState { unrevealed, processing, miss, hit }

enum GameTurnStatus { idle, generatingProof }

class BattleMapState {
  final Map<int, TileDisplayState> pendingTiles;
  final Map<int, TileDisplayState> confirmedTiles;
  final GameTurnStatus status;
  final String logMessage;

  const BattleMapState({
    required this.pendingTiles,
    required this.confirmedTiles,
    required this.status,
    required this.logMessage,
  });

  const BattleMapState.initial()
      : pendingTiles = const {},
        confirmedTiles = const {},
        status = GameTurnStatus.idle,
        logMessage = 'Select a coordinate to deploy an unshielded strike.';

  /// Merged view: pending first, confirmed overlays and wins on conflict.
  Map<int, TileDisplayState> get revealedTiles {
    final merged = Map<int, TileDisplayState>.from(pendingTiles);
    merged.addAll(confirmedTiles);
    return Map.unmodifiable(merged);
  }

  int get hitCount =>
      confirmedTiles.values.where((s) => s == TileDisplayState.hit).length;

  int get missCount =>
      confirmedTiles.values.where((s) => s == TileDisplayState.miss).length;

  BattleMapState copyWith({
    Map<int, TileDisplayState>? pendingTiles,
    Map<int, TileDisplayState>? confirmedTiles,
    GameTurnStatus? status,
    String? logMessage,
  }) {
    return BattleMapState(
      pendingTiles: pendingTiles ?? this.pendingTiles,
      confirmedTiles: confirmedTiles ?? this.confirmedTiles,
      status: status ?? this.status,
      logMessage: logMessage ?? this.logMessage,
    );
  }
}
