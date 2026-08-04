import 'package:flutter/material.dart';

import '../models/trade.dart';
import '../services/trade_database.dart';
import '../widgets/app_text_field.dart';

class TradeJournalScreen extends StatefulWidget {
  const TradeJournalScreen({super.key});

  @override
  State<TradeJournalScreen> createState() => _TradeJournalScreenState();
}

class _TradeJournalScreenState extends State<TradeJournalScreen> {
  final _formKey = GlobalKey<FormState>();

  final _symbolController = TextEditingController(text: 'BTCUSDT');
  final _exchangeController = TextEditingController(text: 'Binance');
  final _entryController = TextEditingController();
  final _stopController = TextEditingController();
  final _targetController = TextEditingController();
  final _leverageController = TextEditingController(text: '10');
  final _marginController = TextEditingController();
  final _reasonController = TextEditingController();
  final _memoController = TextEditingController();

  String _direction = 'LONG';
  String _timeframe = '15m';
  String _marginMode = 'ISOLATED';
  bool _saving = false;

  List<Trade> _trades = const [];
  bool _loadingTrades = true;

  @override
  void initState() {
    super.initState();
    _loadTrades();
  }

  @override
  void dispose() {
    _symbolController.dispose();
    _exchangeController.dispose();
    _entryController.dispose();
    _stopController.dispose();
    _targetController.dispose();
    _leverageController.dispose();
    _marginController.dispose();
    _reasonController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _loadTrades() async {
    try {
      final trades = await TradeDatabase.instance.getTrades();

      if (!mounted) return;

      setState(() {
        _trades = trades;
        _loadingTrades = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => _loadingTrades = false);
      _showMessage('저장된 기록을 불러오지 못했습니다: $error');
    }
  }

  double? _parseDouble(String value) {
    return double.tryParse(value.trim().replaceAll(',', ''));
  }

  int? _parseInt(String value) {
    return int.tryParse(value.trim());
  }

  Future<void> _saveTrade() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final entry = _parseDouble(_entryController.text);
    final stop = _parseDouble(_stopController.text);
    final target = _parseDouble(_targetController.text);
    final leverage = _parseInt(_leverageController.text);
    final margin = _parseDouble(_marginController.text);

    if (entry == null ||
        stop == null ||
        target == null ||
        leverage == null ||
        margin == null) {
      _showMessage('숫자 입력값을 확인해주세요.');
      return;
    }

    setState(() => _saving = true);

    final trade = Trade(
      symbol: _symbolController.text.trim().toUpperCase(),
      exchange: _exchangeController.text.trim(),
      timeframe: _timeframe,
      direction: _direction,
      entry: entry,
      stop: stop,
      target: target,
      leverage: leverage,
      marginMode: _marginMode,
      margin: margin,
      entryNote: _reasonController.text.trim(),
      reviewNote: _memoController.text.trim(),
      createdAt: DateTime.now(),
    );

    try {
      await TradeDatabase.instance.insertTrade(trade);
      await _loadTrades();
      _clearAfterSave();

      if (!mounted) return;
      _showMessage('매매 기록이 이 기기에 안전하게 저장되었습니다.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('저장에 실패했습니다: $error');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _clearAfterSave() {
    _entryController.clear();
    _stopController.clear();
    _targetController.clear();
    _marginController.clear();
    _reasonController.clear();
    _memoController.clear();
  }

  Future<void> _deleteTrade(Trade trade) async {
    final id = trade.id;
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('매매 기록 삭제'),
          content: Text('${trade.symbol} 기록을 삭제할까요?'),
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
        );
      },
    );

    if (confirmed != true) return;

    await TradeDatabase.instance.deleteTrade(id);
    await _loadTrades();
  }

  void _showMessage(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildForm(),
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 16),
        _buildSavedTrades(),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '새 매매 기록',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            '입력한 내용은 우선 기기 내부 SQLite에 저장됩니다.',
            style: TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 24),

          AppTextField(
            controller: _symbolController,
            label: '종목',
            hint: '예: BTCUSDT',
            validator: requiredValidator,
          ),
          const SizedBox(height: 16),

          AppTextField(
            controller: _exchangeController,
            label: '거래소',
            hint: '예: Binance',
            validator: requiredValidator,
          ),
          const SizedBox(height: 16),

          const Text(
            '방향',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'LONG',
                label: Text('LONG'),
                icon: Icon(Icons.trending_up),
              ),
              ButtonSegment(
                value: 'SHORT',
                label: Text('SHORT'),
                icon: Icon(Icons.trending_down),
              ),
            ],
            selected: {_direction},
            onSelectionChanged: (selection) {
              setState(() => _direction = selection.first);
            },
          ),
          const SizedBox(height: 20),

          DropdownButtonFormField<String>(
            initialValue: _timeframe,
            decoration: appInputDecoration('시간봉'),
            items: const [
              DropdownMenuItem(value: '1m', child: Text('1분')),
              DropdownMenuItem(value: '5m', child: Text('5분')),
              DropdownMenuItem(value: '15m', child: Text('15분')),
              DropdownMenuItem(value: '1h', child: Text('1시간')),
              DropdownMenuItem(value: '4h', child: Text('4시간')),
              DropdownMenuItem(value: '1d', child: Text('1일')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _timeframe = value);
            },
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            initialValue: _marginMode,
            decoration: appInputDecoration('마진 모드'),
            items: const [
              DropdownMenuItem(
                value: 'ISOLATED',
                child: Text('Isolated'),
              ),
              DropdownMenuItem(
                value: 'CROSS',
                child: Text('Cross'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _marginMode = value);
            },
          ),
          const SizedBox(height: 16),

          AppTextField(
            controller: _entryController,
            label: '진입가',
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            validator: numberValidator,
          ),
          const SizedBox(height: 16),

          AppTextField(
            controller: _stopController,
            label: '손절가',
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            validator: numberValidator,
          ),
          const SizedBox(height: 16),

          AppTextField(
            controller: _targetController,
            label: '목표가',
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            validator: numberValidator,
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _leverageController,
                  label: '레버리지',
                  hint: '예: 10',
                  keyboardType: TextInputType.number,
                  validator: integerValidator,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  controller: _marginController,
                  label: '증거금',
                  hint: 'USDT',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: numberValidator,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          AppTextField(
            controller: _reasonController,
            label: '진입 이유',
            hint: '예: 상승채널 하단 지지',
            maxLines: 3,
          ),
          const SizedBox(height: 16),

          AppTextField(
            controller: _memoController,
            label: '메모',
            hint: '현재 시장 상태나 주의할 점',
            maxLines: 4,
          ),
          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: _saving ? null : _saveTrade,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(_saving ? '저장 중...' : '매매 기록 저장'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedTrades() {
    if (_loadingTrades) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '저장된 매매 기록 (${_trades.length})',
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        if (_trades.isEmpty)
          const Text(
            '아직 저장된 기록이 없습니다.',
            style: TextStyle(color: Colors.white60),
          ),

        ..._trades.map(_buildTradeCard),
      ],
    );
  }

  Widget _buildTradeCard(Trade trade) {
    final created =
        '${trade.createdAt.year}-${two(trade.createdAt.month)}-${two(trade.createdAt.day)} '
        '${two(trade.createdAt.hour)}:${two(trade.createdAt.minute)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${trade.symbol} · ${trade.direction}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${trade.exchange} · ${trade.timeframe} · '
                    '${trade.leverage}x · ${trade.marginMode}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '진입 ${trade.entry} / 손절 ${trade.stop} / 목표 ${trade.target}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$created · 동기화 대기',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '삭제',
              onPressed: () => _deleteTrade(trade),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

String two(int value) => value.toString().padLeft(2, '0');
