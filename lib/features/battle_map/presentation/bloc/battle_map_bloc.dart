import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/tile_model.dart';
import '../../data/repositories/game_repository.dart';

part 'battle_map_event.dart';
part 'battle_map_state.dart';

class BattleMapBloc extends Bloc<BattleMapEvent, BattleMapState> {
  final GameRepository _repository;
  late final StreamSubscription<Map<int, TileStatus>> _subscription;

  BattleMapBloc(this._repository) : super(const BattleMapState.initial()) {
    on<StrikeCoordinate>(_onStrikeCoordinate);
    on<_LedgerUpdated>(_onLedgerUpdated);

    _subscription = _repository.ledgerStateStream.listen(
      (map) => add(_LedgerUpdated(map)),
    );
  }

  Future<void> _onStrikeCoordinate(
    StrikeCoordinate event,
    Emitter<BattleMapState> emit,
  ) async {
    final index = event.index;
    if (state.confirmedTiles.containsKey(index) ||
        state.pendingTiles.containsKey(index)) {
      return;
    }

    final newPending = Map<int, TileDisplayState>.from(state.pendingTiles)
      ..[index] = TileDisplayState.processing;

    emit(state.copyWith(
      pendingTiles: newPending,
      status: GameTurnStatus.generatingProof,
      logMessage: 'Computing zero-knowledge state proof locally…',
    ));

    try {
      // Await only to surface ZK errors; the stream is the state authority.
      await _repository.fireTorpedo(index);
    } catch (e) {
      final reverted = Map<int, TileDisplayState>.from(state.pendingTiles)
        ..remove(index);
      emit(state.copyWith(
        pendingTiles: reverted,
        status: GameTurnStatus.idle,
        logMessage: 'Transaction aborted: ${e.toString()}',
      ));
      return;
    }

    emit(state.copyWith(status: GameTurnStatus.idle));
  }

  void _onLedgerUpdated(
    _LedgerUpdated event,
    Emitter<BattleMapState> emit,
  ) {
    final newConfirmed = Map<int, TileDisplayState>.from(state.confirmedTiles);
    final newPending = Map<int, TileDisplayState>.from(state.pendingTiles);
    String? latestLog;

    for (final entry in event.ledgerMap.entries) {
      newConfirmed[entry.key] = _mapStatus(entry.value);
      newPending.remove(entry.key);
      latestLog = entry.value == TileStatus.hit
          ? 'Direct Hit — submarine position verified on-chain.'
          : 'Sector clear — zero presence confirmed by ZK proof.';
    }

    emit(state.copyWith(
      confirmedTiles: newConfirmed,
      pendingTiles: newPending,
      logMessage: latestLog ?? state.logMessage,
    ));
  }

  TileDisplayState _mapStatus(TileStatus s) =>
      s == TileStatus.hit ? TileDisplayState.hit : TileDisplayState.miss;

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
