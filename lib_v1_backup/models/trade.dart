class Trade {
  final int? id;
  final String symbol;
  final String exchange;
  final String timeframe;
  final String direction;
  final double entry;
  final double stop;
  final double target;
  final double? exit;
  final int leverage;
  final String marginMode;
  final double margin;
  final double fee;
  final double fundingFee;
  final double? realPnl;
  final double? leveragedPercent;
  final double? netPnl;
  final String entryNote;
  final String exitNote;
  final String reviewNote;
  final String status;
  final DateTime createdAt;
  final DateTime? closedAt;
  final String syncStatus;

  const Trade({
    this.id,
    required this.symbol,
    required this.exchange,
    required this.timeframe,
    required this.direction,
    required this.entry,
    required this.stop,
    required this.target,
    this.exit,
    required this.leverage,
    required this.marginMode,
    required this.margin,
    this.fee = 0,
    this.fundingFee = 0,
    this.realPnl,
    this.leveragedPercent,
    this.netPnl,
    this.entryNote = '',
    this.exitNote = '',
    this.reviewNote = '',
    this.status = 'OPEN',
    required this.createdAt,
    this.closedAt,
    this.syncStatus = 'LOCAL_PENDING',
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'symbol': symbol,
      'exchange': exchange,
      'timeframe': timeframe,
      'direction': direction,
      'entry': entry,
      'stop': stop,
      'target': target,
      'exit': exit,
      'leverage': leverage,
      'margin_mode': marginMode,
      'margin': margin,
      'fee': fee,
      'funding_fee': fundingFee,
      'real_pnl': realPnl,
      'leveraged_percent': leveragedPercent,
      'net_pnl': netPnl,
      'entry_note': entryNote,
      'exit_note': exitNote,
      'review_note': reviewNote,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'closed_at': closedAt?.toIso8601String(),
      'sync_status': syncStatus,
    };
  }

  factory Trade.fromMap(Map<String, Object?> map) {
    double toDouble(Object? value) =>
        value == null ? 0 : (value as num).toDouble();

    double? toNullableDouble(Object? value) =>
        value == null ? null : (value as num).toDouble();

    return Trade(
      id: map['id'] as int?,
      symbol: map['symbol'] as String,
      exchange: map['exchange'] as String,
      timeframe: map['timeframe'] as String,
      direction: map['direction'] as String,
      entry: toDouble(map['entry']),
      stop: toDouble(map['stop']),
      target: toDouble(map['target']),
      exit: toNullableDouble(map['exit']),
      leverage: map['leverage'] as int,
      marginMode: map['margin_mode'] as String,
      margin: toDouble(map['margin']),
      fee: toDouble(map['fee']),
      fundingFee: toDouble(map['funding_fee']),
      realPnl: toNullableDouble(map['real_pnl']),
      leveragedPercent: toNullableDouble(map['leveraged_percent']),
      netPnl: toNullableDouble(map['net_pnl']),
      entryNote: map['entry_note'] as String? ?? '',
      exitNote: map['exit_note'] as String? ?? '',
      reviewNote: map['review_note'] as String? ?? '',
      status: map['status'] as String? ?? 'OPEN',
      createdAt: DateTime.parse(map['created_at'] as String),
      closedAt: map['closed_at'] == null
          ? null
          : DateTime.parse(map['closed_at'] as String),
      syncStatus: map['sync_status'] as String? ?? 'LOCAL_PENDING',
    );
  }
}
