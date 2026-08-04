class TradeImage {
  final int? id;
  final int tradeId;
  final String localPath;
  final String stage;
  final DateTime createdAt;

  const TradeImage({
    this.id,
    required this.tradeId,
    required this.localPath,
    required this.stage,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'trade_id': tradeId,
        'local_path': localPath,
        'stage': stage,
        'created_at': createdAt.toIso8601String(),
      };

  factory TradeImage.fromMap(Map<String, Object?> map) {
    return TradeImage(
      id: map['id'] as int?,
      tradeId: map['trade_id'] as int,
      localPath: map['local_path'] as String,
      stage: map['stage'] as String? ?? 'ENTRY',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
