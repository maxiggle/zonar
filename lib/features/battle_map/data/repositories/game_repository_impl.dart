import 'dart:async';
import '../models/tile_model.dart';
import '../../domain/services/midnight_service.dart';
import 'game_repository.dart';

class GameRepositoryImpl implements GameRepository {
  final MidnightService _midnightService;
  final _stateStreamController =
      StreamController<Map<int, TileStatus>>.broadcast();
  final Map<int, TileStatus> _cachedBoardState = {};

  GameRepositoryImpl(this._midnightService) {
    _midnightService.onZKPayloadReceived.listen((payload) {
      if (payload['status'] == 'SUCCESS') {
        final int index = payload['tile'] as int;
        final int resultType = payload['result'] as int;
        _cachedBoardState[index] =
            resultType == 2 ? TileStatus.hit : TileStatus.miss;
        _stateStreamController.add(Map.unmodifiable(_cachedBoardState));
      }
    });
  }

  @override
  Stream<Map<int, TileStatus>> get ledgerStateStream =>
      _stateStreamController.stream;

  @override
  Future<TileStatus> fireTorpedo(int tileIndex) async {
    final completer = Completer<TileStatus>();

    late StreamSubscription<Map<String, dynamic>> subscription;
    subscription = _midnightService.onZKPayloadReceived.listen((payload) {
      if (payload['tile'] == tileIndex) {
        subscription.cancel();
        if (payload['status'] == 'SUCCESS') {
          completer.complete(
            (payload['result'] as int) == 2 ? TileStatus.hit : TileStatus.miss,
          );
        } else {
          completer.completeError(
            Exception(payload['message'] ?? 'ZK proof failure'),
          );
        }
      }
    });

    await _midnightService.evaluateMoveOnChain(tileIndex);
    return completer.future;
  }

  @override
  void dispose() {
    _stateStreamController.close();
  }
}
