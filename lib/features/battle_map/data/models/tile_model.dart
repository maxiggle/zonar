enum TileStatus { hidden, miss, hit }

class TileModel {
  final int index;
  final int coordinateX;
  final int coordinateY;
  final TileStatus status;

  const TileModel({
    required this.index,
    required this.coordinateX,
    required this.coordinateY,
    this.status = TileStatus.hidden,
  });

  TileModel copyWith({TileStatus? status}) {
    return TileModel(
      index: index,
      coordinateX: coordinateX,
      coordinateY: coordinateY,
      status: status ?? this.status,
    );
  }
}
