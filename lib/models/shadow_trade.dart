class ShadowTrade {
  final int? id;
  final String symbol;
  final String instrument;
  final String timeframe;
  final String direction;
  final double entryPrice;
  final double stopPrice;
  final double targetPrice;
  final double leverage;
  final double virtualMargin;
  final double feeRate;
  final String status;
  final double? currentPrice;
  final double? exitPrice;
  final double grossPnl;
  final double fee;
  final double netPnl;
  final double returnPercent;
  final double rMultiple;
  final double maePercent;
  final double mfePercent;
  final String? entryReason;
  final String? successReason;
  final String? failureReason;
  final String? lesson;
  final DateTime openedAt;
  final DateTime? closedAt;

  const ShadowTrade({
    required this.id,
    required this.symbol,
    required this.instrument,
    required this.timeframe,
    required this.direction,
    required this.entryPrice,
    required this.stopPrice,
    required this.targetPrice,
    required this.leverage,
    required this.virtualMargin,
    required this.feeRate,
    required this.status,
    required this.currentPrice,
    required this.exitPrice,
    required this.grossPnl,
    required this.fee,
    required this.netPnl,
    required this.returnPercent,
    required this.rMultiple,
    required this.maePercent,
    required this.mfePercent,
    required this.entryReason,
    required this.successReason,
    required this.failureReason,
    required this.lesson,
    required this.openedAt,
    required this.closedAt,
  });

  factory ShadowTrade.fromJson(Map<String, dynamic> json) {
    double d(dynamic v, [double f = 0]) =>
        v is num ? v.toDouble() : double.tryParse('$v') ?? f;

    int? i(dynamic v) =>
        v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));

    return ShadowTrade(
      id: i(json['id']),
      symbol: '${json['symbol'] ?? ''}',
      instrument: '${json['instrument'] ?? ''}',
      timeframe: '${json['timeframe'] ?? ''}',
      direction: '${json['direction'] ?? ''}',
      entryPrice: d(json['entry_price']),
      stopPrice: d(json['stop_price']),
      targetPrice: d(json['target_price']),
      leverage: d(json['leverage'], 1),
      virtualMargin: d(json['virtual_margin'], 100),
      feeRate: d(json['fee_rate'], 0.0005),
      status: '${json['status'] ?? 'OPEN'}',
      currentPrice: json['current_price'] == null ? null : d(json['current_price']),
      exitPrice: json['exit_price'] == null ? null : d(json['exit_price']),
      grossPnl: d(json['gross_pnl']),
      fee: d(json['fee']),
      netPnl: d(json['net_pnl']),
      returnPercent: d(json['return_percent']),
      rMultiple: d(json['r_multiple']),
      maePercent: d(json['mae_percent']),
      mfePercent: d(json['mfe_percent']),
      entryReason: json['entry_reason']?.toString(),
      successReason: json['success_reason']?.toString(),
      failureReason: json['failure_reason']?.toString(),
      lesson: json['lesson']?.toString(),
      openedAt: DateTime.parse(json['opened_at'].toString()),
      closedAt: json['closed_at'] == null
          ? null
          : DateTime.parse(json['closed_at'].toString()),
    );
  }
}
