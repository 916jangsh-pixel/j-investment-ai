import 'package:flutter/material.dart';

import '../models/trade.dart';
import '../services/trade_database.dart';

class AiCoachScreen extends StatefulWidget {
  const AiCoachScreen({super.key});

  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachScreen> {
  bool _loading = true;
  String? _errorMessage;
  List<Trade> _trades = [];
  Trade? _selectedTrade;

  @override
  void initState() {
    super.initState();
    _loadTrades();
  }

  Future<void> _loadTrades() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final trades = await TradeDatabase.instance.getTrades();

      if (!mounted) return;

      setState(() {
        _trades = trades;
        _selectedTrade = trades.isNotEmpty ? trades.first : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage = '매매기록을 불러오지 못했습니다.\n$e';
      });
    }
  }

  String _formatNumber(double? value) {
    if (value == null) return '-';
    return value.toStringAsFixed(2);
  }

  String _tradeTitle(Trade trade) {
    return '${trade.symbol} · ${trade.timeframe} · ${trade.direction}';
  }

  String _tradeSubtitle(Trade trade) {
    final pnl = trade.netPnl;
    final pnlText = pnl == null ? '손익 미확정' : '순손익 ${_formatNumber(pnl)}';
    return '${trade.exchange} · $pnlText · ${trade.status}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadTrades,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'AI 코치',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '내 매매기록과 차트 캡처를 기반으로 분석할 거래를 선택합니다.',
              style: TextStyle(
                color: Colors.white60,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorMessage != null)
              _ErrorCard(
                message: _errorMessage!,
                onRetry: _loadTrades,
              )
            else if (_trades.isEmpty)
              const _EmptyCard()
            else ...[
              const Text(
                '분석할 매매 선택',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              ..._trades.map(
                (trade) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TradeSelectCard(
                    trade: trade,
                    selected: _selectedTrade?.id == trade.id,
                    title: _tradeTitle(trade),
                    subtitle: _tradeSubtitle(trade),
                    onTap: () {
                      setState(() {
                        _selectedTrade = trade;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 18),

              if (_selectedTrade != null)
                _SelectedTradeCard(
                  trade: _selectedTrade!,
                  formatNumber: _formatNumber,
                ),

              const SizedBox(height: 18),

              FilledButton.icon(
                onPressed: _selectedTrade == null
                    ? null
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '다음 단계에서 Supabase Edge Function과 실제 AI 분석을 연결합니다.',
                            ),
                          ),
                        );
                      },
                icon: const Icon(Icons.smart_toy_outlined),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('AI 분석 준비'),
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                '현재 단계: 거래 선택 UI 연결 완료\n다음 단계: 차트 이미지 + 매매 데이터 → 서버 AI 분석',
                style: TextStyle(
                  color: Colors.white54,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TradeSelectCard extends StatelessWidget {
  final Trade trade;
  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _TradeSelectCard({
    required this.trade,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: selected
                      ? theme.colorScheme.primary.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.05),
                ),
                child: Icon(
                  trade.direction == 'LONG'
                      ? Icons.trending_up
                      : Icons.trending_down,
                  color: selected
                      ? theme.colorScheme.primary
                      : Colors.white70,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: selected
                    ? theme.colorScheme.primary
                    : Colors.white38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedTradeCard extends StatelessWidget {
  final Trade trade;
  final String Function(double? value) formatNumber;

  const _SelectedTradeCard({
    required this.trade,
    required this.formatNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '선택된 매매',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            _InfoRow(label: '종목', value: trade.symbol),
            _InfoRow(label: '거래소', value: trade.exchange),
            _InfoRow(label: '시간봉', value: trade.timeframe),
            _InfoRow(label: '방향', value: trade.direction),
            _InfoRow(label: '진입가', value: formatNumber(trade.entry)),
            _InfoRow(label: '손절가', value: formatNumber(trade.stop)),
            _InfoRow(label: '목표가', value: formatNumber(trade.target)),
            _InfoRow(label: '청산가', value: formatNumber(trade.exit)),
            _InfoRow(label: '레버리지', value: '${trade.leverage}x'),
            _InfoRow(label: '증거금', value: formatNumber(trade.margin)),
            _InfoRow(label: '순손익', value: formatNumber(trade.netPnl)),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 10),
            _NoteBlock(label: '진입 메모', text: trade.entryNote),
            _NoteBlock(label: '청산 메모', text: trade.exitNote),
            _NoteBlock(label: '복기 메모', text: trade.reviewNote),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteBlock extends StatelessWidget {
  final String label;
  final String text;

  const _NoteBlock({
    required this.label,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final content = text.trim().isEmpty ? '기록 없음' : text.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            content,
            style: const TextStyle(
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 54,
            ),
            SizedBox(height: 14),
            Text(
              '분석할 매매기록이 없습니다.',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '먼저 매매일지에서 거래를 저장해주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorCard({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline,
              size: 50,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 불러오기'),
            ),
          ],
        ),
      ),
    );
  }
}
