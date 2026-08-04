class TradeResult {
  final double priceReturnPercent;
  final double leveragedReturnPercent;
  final double grossPnl;
  final double netPnl;

  const TradeResult({
    required this.priceReturnPercent,
    required this.leveragedReturnPercent,
    required this.grossPnl,
    required this.netPnl,
  });
}

class TradeCalculator {
  static TradeResult calculate({
    required String direction,
    required double entry,
    required double exit,
    required int leverage,
    required double margin,
    required double fee,
    required double fundingFee,
  }) {
    final priceReturn = direction == 'SHORT'
        ? (entry - exit) / entry
        : (exit - entry) / entry;

    final leveragedReturn = priceReturn * leverage;
    final grossPnl = margin * leveragedReturn;
    final netPnl = grossPnl - fee - fundingFee;

    return TradeResult(
      priceReturnPercent: priceReturn * 100,
      leveragedReturnPercent: leveragedReturn * 100,
      grossPnl: grossPnl,
      netPnl: netPnl,
    );
  }
}
