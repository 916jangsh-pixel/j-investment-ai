import 'package:flutter_test/flutter_test.dart';
import 'package:j_investment_ai/services/okx_market_service.dart';
import 'package:j_investment_ai/services/technical_indicator_service.dart';

void main() {
  test('OKX 멀티 타임프레임 기술지표 실제 데이터 테스트', () async {
    final okx = OkxMarketService.instance;
    final indicators = TechnicalIndicatorService.instance;

    final candles = await okx.getMultiTimeframeCandles(
      symbol: 'BTCUSDT',
      limit: 100,
    );

    final snapshots = indicators.analyzeMultiTimeframe(candles);

    print('==============================================');
    print('J.Investment OKX 기술지표 테스트');
    print('==============================================');

    for (final timeframe in const ['5m', '15m', '1H', '4H']) {
      final data = snapshots[timeframe];

      expect(data, isNotNull);

      print('');
      print('[$timeframe]');
      print('Close: ${data!.close}');
      print('RSI14: ${data.rsi14.toStringAsFixed(2)}');
      print('EMA20: ${data.ema20.toStringAsFixed(2)}');
      print('EMA50: ${data.ema50.toStringAsFixed(2)}');
      print('MACD: ${data.macd.toStringAsFixed(4)}');
      print('Signal: ${data.macdSignal.toStringAsFixed(4)}');
      print('Histogram: ${data.macdHistogram.toStringAsFixed(4)}');
      print('ATR14: ${data.atr14.toStringAsFixed(2)}');
      print('ATR%: ${data.atrPercent.toStringAsFixed(3)}%');
      print('Volume Ratio20: ${data.volumeRatio20.toStringAsFixed(2)}x');
      print('Trend: ${data.trend}');
      print('Momentum: ${data.momentum}');
      print('Volatility: ${data.volatility}');

      expect(data.close, greaterThan(0));
      expect(data.rsi14, inInclusiveRange(0, 100));
      expect(data.ema20, greaterThan(0));
      expect(data.ema50, greaterThan(0));
      expect(data.atr14, greaterThanOrEqualTo(0));
    }

    print('');
    print('==============================================');
    print('기술지표 계산 성공');
    print('==============================================');
  });
}
