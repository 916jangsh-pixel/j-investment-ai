import 'dart:math' as math;

import 'okx_market_service.dart';

class TechnicalIndicatorService {
  TechnicalIndicatorService._();

  static final TechnicalIndicatorService instance =
      TechnicalIndicatorService._();

  /// 단일 시간봉의 핵심 기술지표를 계산합니다.
  ///
  /// 기본값:
  /// - RSI 14
  /// - EMA 20 / 50
  /// - MACD 12 / 26 / 9
  /// - ATR 14
  TechnicalIndicatorSnapshot analyze(
    List<OkxCandle> candles, {
    int rsiPeriod = 14,
    int emaFastPeriod = 20,
    int emaSlowPeriod = 50,
    int macdFastPeriod = 12,
    int macdSlowPeriod = 26,
    int macdSignalPeriod = 9,
    int atrPeriod = 14,
  }) {
    if (candles.length < 60) {
      throw ArgumentError(
        '기술지표 계산에는 최소 60개의 캔들이 필요합니다. '
        '현재: ${candles.length}개',
      );
    }

    final closes = candles.map((c) => c.close).toList(growable: false);

    final rsi = _rsi(closes, rsiPeriod);
    final emaFast = _emaSeries(closes, emaFastPeriod);
    final emaSlow = _emaSeries(closes, emaSlowPeriod);

    final macd = _macd(
      closes,
      fastPeriod: macdFastPeriod,
      slowPeriod: macdSlowPeriod,
      signalPeriod: macdSignalPeriod,
    );

    final atr = _atr(candles, atrPeriod);

    final last = candles.last;
    final previous = candles[candles.length - 2];

    final recentVolumes = candles
        .skip(math.max(0, candles.length - 21))
        .take(20)
        .map((c) => c.volumeQuote > 0 ? c.volumeQuote : c.volume)
        .toList();

    final currentVolume =
        last.volumeQuote > 0 ? last.volumeQuote : last.volume;

    final averageVolume = recentVolumes.isEmpty
        ? 0.0
        : recentVolumes.reduce((a, b) => a + b) / recentVolumes.length;

    final volumeRatio =
        averageVolume > 0 ? currentVolume / averageVolume : 0.0;

    final ema20 = emaFast.last;
    final ema50 = emaSlow.last;

    return TechnicalIndicatorSnapshot(
      close: last.close,
      previousClose: previous.close,
      rsi14: rsi,
      ema20: ema20,
      ema50: ema50,
      macd: macd.macd,
      macdSignal: macd.signal,
      macdHistogram: macd.histogram,
      atr14: atr,
      atrPercent: last.close > 0 ? (atr / last.close) * 100 : 0,
      volumeRatio20: volumeRatio,
      trend: _trendLabel(
        close: last.close,
        emaFast: ema20,
        emaSlow: ema50,
      ),
      momentum: _momentumLabel(
        rsi: rsi,
        macdHistogram: macd.histogram,
      ),
      volatility: _volatilityLabel(
        atrPercent: last.close > 0 ? (atr / last.close) * 100 : 0,
      ),
      latestCandleConfirmed: last.confirmed,
      timestamp: last.timestamp,
    );
  }

  /// 5m / 15m / 1H / 4H 같은 멀티 타임프레임을 한 번에 분석합니다.
  Map<String, TechnicalIndicatorSnapshot> analyzeMultiTimeframe(
    Map<String, List<OkxCandle>> candlesByTimeframe,
  ) {
    final result = <String, TechnicalIndicatorSnapshot>{};

    for (final entry in candlesByTimeframe.entries) {
      if (entry.value.length < 60) continue;
      result[entry.key] = analyze(entry.value);
    }

    return result;
  }

  double _rsi(List<double> closes, int period) {
    if (closes.length <= period) {
      throw ArgumentError('RSI 계산 데이터가 부족합니다.');
    }

    double gains = 0;
    double losses = 0;

    for (var i = 1; i <= period; i++) {
      final change = closes[i] - closes[i - 1];
      if (change >= 0) {
        gains += change;
      } else {
        losses += -change;
      }
    }

    var averageGain = gains / period;
    var averageLoss = losses / period;

    for (var i = period + 1; i < closes.length; i++) {
      final change = closes[i] - closes[i - 1];
      final gain = change > 0 ? change : 0.0;
      final loss = change < 0 ? -change : 0.0;

      averageGain =
          ((averageGain * (period - 1)) + gain) / period;
      averageLoss =
          ((averageLoss * (period - 1)) + loss) / period;
    }

    if (averageLoss == 0) return 100;
    if (averageGain == 0) return 0;

    final rs = averageGain / averageLoss;
    return 100 - (100 / (1 + rs));
  }

  List<double> _emaSeries(List<double> values, int period) {
    if (values.length < period) {
      throw ArgumentError('EMA 계산 데이터가 부족합니다.');
    }

    final result = List<double>.filled(values.length, double.nan);
    final seed =
        values.take(period).reduce((a, b) => a + b) / period;

    result[period - 1] = seed;

    final multiplier = 2 / (period + 1);

    for (var i = period; i < values.length; i++) {
      result[i] =
          ((values[i] - result[i - 1]) * multiplier) + result[i - 1];
    }

    return result;
  }

  _MacdResult _macd(
    List<double> closes, {
    required int fastPeriod,
    required int slowPeriod,
    required int signalPeriod,
  }) {
    final fast = _emaSeries(closes, fastPeriod);
    final slow = _emaSeries(closes, slowPeriod);

    final macdValues = <double>[];

    for (var i = slowPeriod - 1; i < closes.length; i++) {
      if (fast[i].isNaN || slow[i].isNaN) continue;
      macdValues.add(fast[i] - slow[i]);
    }

    if (macdValues.length < signalPeriod) {
      throw ArgumentError('MACD Signal 계산 데이터가 부족합니다.');
    }

    final signalValues = _emaSeries(macdValues, signalPeriod);

    final macd = macdValues.last;
    final signal = signalValues.last;
    final histogram = macd - signal;

    return _MacdResult(
      macd: macd,
      signal: signal,
      histogram: histogram,
    );
  }

  double _atr(List<OkxCandle> candles, int period) {
    if (candles.length <= period) {
      throw ArgumentError('ATR 계산 데이터가 부족합니다.');
    }

    final trueRanges = <double>[];

    for (var i = 1; i < candles.length; i++) {
      final current = candles[i];
      final previous = candles[i - 1];

      final highLow = current.high - current.low;
      final highPrevClose = (current.high - previous.close).abs();
      final lowPrevClose = (current.low - previous.close).abs();

      trueRanges.add(
        math.max(
          highLow,
          math.max(highPrevClose, lowPrevClose),
        ),
      );
    }

    var atr =
        trueRanges.take(period).reduce((a, b) => a + b) / period;

    for (var i = period; i < trueRanges.length; i++) {
      atr = ((atr * (period - 1)) + trueRanges[i]) / period;
    }

    return atr;
  }

  String _trendLabel({
    required double close,
    required double emaFast,
    required double emaSlow,
  }) {
    if (close > emaFast && emaFast > emaSlow) {
      return 'BULLISH';
    }

    if (close < emaFast && emaFast < emaSlow) {
      return 'BEARISH';
    }

    return 'MIXED';
  }

  String _momentumLabel({
    required double rsi,
    required double macdHistogram,
  }) {
    if (rsi >= 55 && macdHistogram > 0) {
      return 'BULLISH';
    }

    if (rsi <= 45 && macdHistogram < 0) {
      return 'BEARISH';
    }

    return 'NEUTRAL';
  }

  String _volatilityLabel({
    required double atrPercent,
  }) {
    if (atrPercent >= 2.0) return 'HIGH';
    if (atrPercent >= 0.8) return 'MEDIUM';
    return 'LOW';
  }
}

class TechnicalIndicatorSnapshot {
  final double close;
  final double previousClose;

  final double rsi14;
  final double ema20;
  final double ema50;

  final double macd;
  final double macdSignal;
  final double macdHistogram;

  final double atr14;
  final double atrPercent;

  /// 현재 거래량 / 직전 20개 캔들 평균 거래량
  final double volumeRatio20;

  /// BULLISH / BEARISH / MIXED
  final String trend;

  /// BULLISH / BEARISH / NEUTRAL
  final String momentum;

  /// LOW / MEDIUM / HIGH
  final String volatility;

  final bool latestCandleConfirmed;
  final DateTime timestamp;

  const TechnicalIndicatorSnapshot({
    required this.close,
    required this.previousClose,
    required this.rsi14,
    required this.ema20,
    required this.ema50,
    required this.macd,
    required this.macdSignal,
    required this.macdHistogram,
    required this.atr14,
    required this.atrPercent,
    required this.volumeRatio20,
    required this.trend,
    required this.momentum,
    required this.volatility,
    required this.latestCandleConfirmed,
    required this.timestamp,
  });

  double get changePercent {
    if (previousClose <= 0) return 0;
    return ((close - previousClose) / previousClose) * 100;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'close': close,
      'previous_close': previousClose,
      'change_percent': changePercent,
      'rsi_14': rsi14,
      'ema_20': ema20,
      'ema_50': ema50,
      'macd': macd,
      'macd_signal': macdSignal,
      'macd_histogram': macdHistogram,
      'atr_14': atr14,
      'atr_percent': atrPercent,
      'volume_ratio_20': volumeRatio20,
      'trend': trend,
      'momentum': momentum,
      'volatility': volatility,
      'latest_candle_confirmed': latestCandleConfirmed,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class _MacdResult {
  final double macd;
  final double signal;
  final double histogram;

  const _MacdResult({
    required this.macd,
    required this.signal,
    required this.histogram,
  });
}
