import '../models/tile_model.dart';

abstract class GameRepository {
  /// Real-time stream of confirmed tile states from the Midnight ZK ledger.
  Stream<Map<int, TileStatus>> get ledgerStateStream;

  /// Dispatches a torpedo to the given tile index through the ZK execution engine.
  Future<TileStatus> fireTorpedo(int tileIndex);

  void dispose();
}
