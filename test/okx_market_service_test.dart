import 'package:flutter_test/flutter_test.dart';
import 'package:j_investment_ai/services/okx_market_service.dart';

void main() {
  test('OKX BTC-USDT-SWAP 실제 데이터 테스트', () async {
    final okx = OkxMarketService.instance;

    final ticker = await okx.getTicker(symbol: 'BTCUSDT');

    print('==============================');
    print('OKX 연결 성공');
    print('종목: ${ticker.instId}');
    print('현재가: ${ticker.last}');
    print('Bid: ${ticker.bid}');
    print('Ask: ${ticker.ask}');
    print('24H 고가: ${ticker.high24h}');
    print('24H 저가: ${ticker.low24h}');
    print('24H 변화율: ${ticker.change24hPercent}%');
    print('==============================');

    final candles = await okx.getMultiTimeframeCandles(
      symbol: 'BTCUSDT',
      limit: 100,
    );

    print('5m 캔들: ${candles['5m']?.length}');
    print('15m 캔들: ${candles['15m']?.length}');
    print('1H 캔들: ${candles['1H']?.length}');
    print('4H 캔들: ${candles['4H']?.length}');

    expect(ticker.last, greaterThan(0));
    expect(candles['5m'], isNotEmpty);
    expect(candles['15m'], isNotEmpty);
    expect(candles['1H'], isNotEmpty);
    expect(candles['4H'], isNotEmpty);
  });
}
