part of 'battle_map_bloc.dart';

abstract class BattleMapEvent {}

/// Dispatched by the UI when the player taps a grid tile.
class StrikeCoordinate extends BattleMapEvent {
  final int index;
  StrikeCoordinate(this.index);
}

/// Internal event fired by the ledger stream subscription.
class _LedgerUpdated extends BattleMapEvent {
  final Map<int, TileStatus> ledgerMap;
  _LedgerUpdated(this.ledgerMap);
}
