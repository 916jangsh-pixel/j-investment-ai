import 'package:flutter/material.dart';

import '../models/trade.dart';
import '../services/trade_database.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() =>
      _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  List<Trade> _trades = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final trades = await TradeDatabase.instance.getTrades();

    if (!mounted) return;

    setState(() {
      _trades = trades.where((trade) => trade.isClosed).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final total = _trades.length;
    final wins =
        _trades.where((trade) => (trade.netPnl ?? 0) > 0).length;
    final losses =
        _trades.where((trade) => (trade.netPnl ?? 0) < 0).length;

    final net = _trades.fold<double>(
      0,
      (sum, trade) => sum + (trade.netPnl ?? 0),
    );

    final winRate = total == 0 ? 0.0 : wins / total * 100;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _stat('종료 거래', '$total회'),
          _stat('승리 / 패배', '$wins / $losses'),
          _stat('승률', '${winRate.toStringAsFixed(1)}%'),
          _stat(
            '누적 순손익',
            '${net.toStringAsFixed(2)} USDT',
          ),
          const SizedBox(height: 16),
          const Text(
            '프로젝트별·LONG/SHORT·시간봉별 상세 통계는 다음 버전에서 확장합니다.',
            style: TextStyle(color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _stat(String title, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
