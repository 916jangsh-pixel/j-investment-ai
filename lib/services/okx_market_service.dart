import 'dart:convert';

import 'package:http/http.dart' as http;

/// OKX 공개 Market API 전용 서비스.
///
/// - API Key 불필요
/// - 실제 주문 기능 없음
/// - 현재가 / 24시간 정보 / OHLCV 조회용
/// - 추후 Shadow Trading, RSI/MACD/EMA/ATR 계산의 기반으로 사용
class OkxMarketService {
  OkxMarketService._();

  static final OkxMarketService instance = OkxMarketService._();

  static const String _baseUrl = 'https://www.okx.com';

  /// 앱의 BTCUSDT / ETHUSDT / SOLUSDT 형식을
  /// OKX 무기한 선물 형식(BTC-USDT-SWAP 등)으로 변환합니다.
  String toSwapInstId(String symbol) {
    final cleaned = symbol
        .trim()
        .toUpperCase()
        .replaceAll('-', '')
        .replaceAll('_', '')
        .replaceAll('/', '');

    if (cleaned.endsWith('USDT')) {
      final base = cleaned.substring(0, cleaned.length - 4);
      if (base.isNotEmpty) {
        return '$base-USDT-SWAP';
      }
    }

    throw ArgumentError.value(
      symbol,
      'symbol',
      '현재는 USDT 무기한 선물 종목만 지원합니다. 예: BTCUSDT',
    );
  }

  /// OKX 단일 종목 Ticker 조회.
  Future<OkxTicker> getTicker({
    required String symbol,
  }) async {
    final instId = toSwapInstId(symbol);

    final uri = Uri.parse(
      '$_baseUrl/api/v5/market/ticker',
    ).replace(
      queryParameters: <String, String>{
        'instId': instId,
      },
    );

    final response = await http
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 10));

    final json = _decodeResponse(response);
    final data = json['data'];

    if (data is! List || data.isEmpty || data.first is! Map) {
      throw StateError('OKX Ticker 데이터가 비어 있습니다.');
    }

    return OkxTicker.fromJson(
      Map<String, dynamic>.from(data.first as Map),
    );
  }

  /// OKX 최근 캔들 조회.
  ///
  /// bar 예:
  /// 5m, 15m, 1H, 4H
  ///
  /// OKX 응답은 최신 캔들부터 오므로 앱에서 사용하기 편하도록
  /// 오래된 캔들 -> 최신 캔들 순으로 정렬해서 반환합니다.
  Future<List<OkxCandle>> getCandles({
    required String symbol,
    required String bar,
    int limit = 100,
  }) async {
    final safeLimit = limit.clamp(1, 300);
    final instId = toSwapInstId(symbol);

    final uri = Uri.parse(
      '$_baseUrl/api/v5/market/candles',
    ).replace(
      queryParameters: <String, String>{
        'instId': instId,
        'bar': bar,
        'limit': safeLimit.toString(),
      },
    );

    final response = await http
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 10));

    final json = _decodeResponse(response);
    final data = json['data'];

    if (data is! List) {
      throw StateError('OKX Candle 응답 형식이 올바르지 않습니다.');
    }

    final candles = data
        .whereType<List>()
        .map(OkxCandle.fromList)
        .toList(growable: false);

    return candles.reversed.toList(growable: false);
  }

  /// 단기 AI 기본 멀티 타임프레임.
  ///
  /// 이후 여기 결과에 RSI / MACD / EMA / ATR을 붙입니다.
  Future<Map<String, List<OkxCandle>>> getMultiTimeframeCandles({
    required String symbol,
    int limit = 100,
  }) async {
    const timeframes = <String>['5m', '15m', '1H', '4H'];

    final results = await Future.wait(
      timeframes.map(
        (bar) => getCandles(
          symbol: symbol,
          bar: bar,
          limit: limit,
        ),
      ),
    );

    return <String, List<OkxCandle>>{
      for (var i = 0; i < timeframes.length; i++)
        timeframes[i]: results[i],
    };
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'OKX HTTP 오류 ${response.statusCode}: '
        '${response.body.substring(0, response.body.length.clamp(0, 500))}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map) {
      throw StateError('OKX 응답 JSON 형식이 올바르지 않습니다.');
    }

    final json = Map<String, dynamic>.from(decoded);

    final code = json['code']?.toString() ?? '';
    if (code != '0') {
      throw StateError(
        'OKX API 오류 [$code] ${json['msg'] ?? '알 수 없는 오류'}',
      );
    }

    return json;
  }
}

class OkxTicker {
  final String instId;
  final double last;
  final double bid;
  final double ask;
  final double open24h;
  final double high24h;
  final double low24h;
  final double volume24h;
  final double volumeQuote24h;
  final DateTime timestamp;

  const OkxTicker({
    required this.instId,
    required this.last,
    required this.bid,
    required this.ask,
    required this.open24h,
    required this.high24h,
    required this.low24h,
    required this.volume24h,
    required this.volumeQuote24h,
    required this.timestamp,
  });

  factory OkxTicker.fromJson(Map<String, dynamic> json) {
    return OkxTicker(
      instId: json['instId']?.toString() ?? '',
      last: _toDouble(json['last']),
      bid: _toDouble(json['bidPx']),
      ask: _toDouble(json['askPx']),
      open24h: _toDouble(json['open24h']),
      high24h: _toDouble(json['high24h']),
      low24h: _toDouble(json['low24h']),
      volume24h: _toDouble(json['vol24h']),
      volumeQuote24h: _toDouble(json['volCcy24h']),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        _toInt(json['ts']),
        isUtc: true,
      ),
    );
  }

  double get change24hPercent {
    if (open24h <= 0) return 0;
    return ((last - open24h) / open24h) * 100;
  }
}

class OkxCandle {
  final DateTime timestamp;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
  final double volumeCurrency;
  final double volumeQuote;
  final bool confirmed;

  const OkxCandle({
    required this.timestamp,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    required this.volumeCurrency,
    required this.volumeQuote,
    required this.confirmed,
  });

  factory OkxCandle.fromList(List<dynamic> row) {
    if (row.length < 9) {
      throw StateError(
        'OKX Candle 데이터 길이가 올바르지 않습니다: ${row.length}',
      );
    }

    return OkxCandle(
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        _toInt(row[0]),
        isUtc: true,
      ),
      open: _toDouble(row[1]),
      high: _toDouble(row[2]),
      low: _toDouble(row[3]),
      close: _toDouble(row[4]),
      volume: _toDouble(row[5]),
      volumeCurrency: _toDouble(row[6]),
      volumeQuote: _toDouble(row[7]),
      confirmed: row[8]?.toString() == '1',
    );
  }
}

double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
