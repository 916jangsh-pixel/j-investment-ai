import 'package:flutter/material.dart';

import '../models/trade.dart';
import '../services/trade_calculator.dart';
import '../services/trade_database.dart';
import '../widgets/app_text_field.dart';

class TradeDetailScreen extends StatefulWidget {
  final Trade trade;

  const TradeDetailScreen({
    super.key,
    required this.trade,
  });

  @override
  State<TradeDetailScreen> createState() =>
      _TradeDetailScreenState();
}

class _TradeDetailScreenState extends State<TradeDetailScreen> {
  final _exit = TextEditingController();
  final _fee = TextEditingController(text: '0');
  final _funding = TextEditingController(text: '0');
  final _exitNote = TextEditingController();
  final _review = TextEditingController();

  TradeResult? _preview;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    final trade = widget.trade;

    if (trade.exit != null) {
      _exit.text = trade.exit.toString();
    }

    _fee.text = trade.fee.toString();
    _funding.text = trade.fundingFee.toString();
    _exitNote.text = trade.exitNote;
    _review.text = trade.reviewNote;

    _calculatePreview();
  }

  @override
  void dispose() {
    _exit.dispose();
    _fee.dispose();
    _funding.dispose();
    _exitNote.dispose();
    _review.dispose();
    super.dispose();
  }

  double? _parseDouble(String value) =>
      double.tryParse(value.trim().replaceAll(',', ''));

  void _calculatePreview() {
    final exit = _parseDouble(_exit.text);
    final fee = _parseDouble(_fee.text) ?? 0;
    final funding = _parseDouble(_funding.text) ?? 0;

    if (exit == null || exit <= 0) {
      setState(() => _preview = null);
      return;
    }

    setState(() {
      _preview = TradeCalculator.calculate(
        direction: widget.trade.direction,
        entry: widget.trade.entry,
        exit: exit,
        leverage: widget.trade.leverage,
        margin: widget.trade.margin,
        fee: fee,
        fundingFee: funding,
      );
    });
  }

  Future<void> _closeTrade() async {
    final exit = _parseDouble(_exit.text);
    final fee = _parseDouble(_fee.text) ?? 0;
    final funding = _parseDouble(_funding.text) ?? 0;

    if (exit == null || exit <= 0) {
      _message('올바른 청산가를 입력해주세요.');
      return;
    }

    setState(() => _saving = true);

    try {
      await TradeDatabase.instance.closeTrade(
        trade: widget.trade,
        exit: exit,
        fee: fee,
        fundingFee: funding,
        exitNote: _exitNote.text.trim(),
        reviewNote: _review.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete() async {
    final id = widget.trade.id;
    if (id == null) return;

    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('기록 삭제'),
        content: const Text('이 매매 기록을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (yes != true) return;

    await TradeDatabase.instance.deleteTrade(id);

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trade = widget.trade;

    return Scaffold(
      appBar: AppBar(
        title: Text('${trade.symbol} 상세'),
        actions: [
          IconButton(
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${trade.direction} · '
                    '${trade.timeframe} · '
                    '${trade.leverage}x',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('진입가: ${trade.entry}'),
                  Text('손절가: ${trade.stop}'),
                  Text('목표가: ${trade.target}'),
                  Text(
                    '증거금: '
                    '${trade.margin.toStringAsFixed(2)} USDT',
                  ),
                  Text('상태: ${trade.status}'),
                  if (trade.entryNote.isNotEmpty)
                    Text('진입 이유: ${trade.entryNote}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (trade.isClosed)
            _closedResult(trade)
          else ...[
            const Text(
              '거래 종료',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _exit,
              label: '청산가',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _calculatePreview(),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _fee,
              label: '수수료 (USDT)',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _calculatePreview(),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _funding,
              label: '펀딩비 (USDT)',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _calculatePreview(),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _exitNote,
              label: '청산 메모',
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _review,
              label: '복기 메모',
              maxLines: 4,
            ),
            const SizedBox(height: 18),
            if (_preview != null) _previewCard(_preview!),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving ? null : _closeTrade,
              icon: const Icon(Icons.check_circle_outline),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  _saving
                      ? '처리 중...'
                      : '거래 종료 및 복리 반영',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _previewCard(TradeResult result) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '자동 계산 미리보기',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              '가격 변동률: '
              '${result.priceReturnPercent.toStringAsFixed(2)}%',
            ),
            Text(
              '레버리지 반영: '
              '${result.leveragedReturnPercent.toStringAsFixed(2)}%',
            ),
            Text(
              '실현손익: '
              '${result.grossPnl.toStringAsFixed(2)} USDT',
            ),
            Text(
              '순손익: '
              '${result.netPnl.toStringAsFixed(2)} USDT',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: result.netPnl >= 0
                    ? Colors.greenAccent
                    : Colors.redAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _closedResult(Trade trade) {
    final pnl = trade.netPnl ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '거래 종료 결과',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text('청산가: ${trade.exit}'),
            Text(
              '가격 변동률: '
              '${trade.priceReturnPercent?.toStringAsFixed(2)}%',
            ),
            Text(
              '레버리지 반영 수익률: '
              '${trade.leveragedReturnPercent?.toStringAsFixed(2)}%',
            ),
            Text(
              '수수료: ${trade.fee.toStringAsFixed(2)} USDT',
            ),
            Text(
              '펀딩비: '
              '${trade.fundingFee.toStringAsFixed(2)} USDT',
            ),
            Text(
              '순손익: ${pnl.toStringAsFixed(2)} USDT',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: pnl >= 0
                    ? Colors.greenAccent
                    : Colors.redAccent,
              ),
            ),
            if (trade.exitNote.isNotEmpty)
              Text('청산 메모: ${trade.exitNote}'),
            if (trade.reviewNote.isNotEmpty)
              Text('복기: ${trade.reviewNote}'),
          ],
        ),
      ),
    );
  }
}
