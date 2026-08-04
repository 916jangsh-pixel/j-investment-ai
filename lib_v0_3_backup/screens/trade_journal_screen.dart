import 'package:flutter/material.dart';

import '../models/project.dart';
import '../models/trade.dart';
import '../services/trade_database.dart';
import '../widgets/app_text_field.dart';
import 'trade_detail_screen.dart';

class TradeJournalScreen extends StatefulWidget {
  final VoidCallback? onDataChanged;

  const TradeJournalScreen({
    super.key,
    this.onDataChanged,
  });

  @override
  State<TradeJournalScreen> createState() =>
      _TradeJournalScreenState();
}

class _TradeJournalScreenState extends State<TradeJournalScreen> {
  final _formKey = GlobalKey<FormState>();

  final _symbol = TextEditingController(text: 'BTCUSDT');
  final _exchange = TextEditingController(text: 'Binance');
  final _entry = TextEditingController();
  final _stop = TextEditingController();
  final _target = TextEditingController();
  final _leverage = TextEditingController(text: '10');
  final _margin = TextEditingController();
  final _reason = TextEditingController();
  final _memo = TextEditingController();

  List<Project> _projects = const [];
  List<Trade> _trades = const [];

  int? _projectId;
  String _direction = 'LONG';
  String _timeframe = '15m';
  String _marginMode = 'ISOLATED';

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _symbol.dispose();
    _exchange.dispose();
    _entry.dispose();
    _stop.dispose();
    _target.dispose();
    _leverage.dispose();
    _margin.dispose();
    _reason.dispose();
    _memo.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final projects = await TradeDatabase.instance.getProjects();
    final active = await TradeDatabase.instance.getActiveProject();
    final trades = await TradeDatabase.instance.getTrades();

    if (!mounted) return;

    final selected = active?.id ??
        (projects.isNotEmpty ? projects.first.id : null);

    setState(() {
      _projects = projects;
      _trades = trades;
      _projectId = selected;
      _loading = false;
    });

    _applyRecommendedMargin();
  }

  Project? get _selectedProject {
    for (final project in _projects) {
      if (project.id == _projectId) return project;
    }
    return null;
  }

  void _applyRecommendedMargin() {
    final project = _selectedProject;
    if (project == null) return;

    _margin.text = project.recommendedMargin.toStringAsFixed(2);

    final currentLeverage =
        int.tryParse(_leverage.text.trim()) ?? project.maxLeverage;

    if (currentLeverage > project.maxLeverage) {
      _leverage.text = project.maxLeverage.toString();
    }
  }

  double? _parseDouble(String value) =>
      double.tryParse(value.trim().replaceAll(',', ''));

  int? _parseInt(String value) =>
      int.tryParse(value.trim());

  Future<void> _save() async {
    if (_projectId == null) {
      _message('먼저 프로젝트 탭에서 프로젝트를 만들어주세요.');
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final project = _selectedProject!;
    final leverage = _parseInt(_leverage.text)!;
    final margin = _parseDouble(_margin.text)!;

    if (leverage > project.maxLeverage) {
      _message(
        '프로젝트 최대 레버리지는 ${project.maxLeverage}x 입니다.',
      );
      return;
    }

    final maxMargin =
        project.currentBalance * project.maxMarginPercent / 100;

    if (margin > maxMargin + 0.000001) {
      _message(
        '프로젝트 최대 증거금은 '
        '${maxMargin.toStringAsFixed(2)} USDT 입니다.',
      );
      return;
    }

    setState(() => _saving = true);

    final trade = Trade(
      projectId: _projectId!,
      symbol: _symbol.text.trim().toUpperCase(),
      exchange: _exchange.text.trim(),
      timeframe: _timeframe,
      direction: _direction,
      entry: _parseDouble(_entry.text)!,
      stop: _parseDouble(_stop.text)!,
      target: _parseDouble(_target.text)!,
      leverage: leverage,
      marginMode: _marginMode,
      margin: margin,
      entryNote: _reason.text.trim(),
      reviewNote: _memo.text.trim(),
      createdAt: DateTime.now(),
    );

    try {
      await TradeDatabase.instance.insertTrade(trade);

      _entry.clear();
      _stop.clear();
      _target.clear();
      _reason.clear();
      _memo.clear();

      await _load();
      widget.onDataChanged?.call();
      _message('매매 기록이 저장되었습니다.');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _openTrade(Trade trade) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TradeDetailScreen(trade: trade),
      ),
    );

    await _load();
  }

  String _projectName(int id) {
    for (final project in _projects) {
      if (project.id == id) return project.name;
    }
    return '프로젝트';
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_projects.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  '먼저 프로젝트 탭에서 복리 프로젝트를 만들어주세요.',
                ),
              ),
            )
          else
            _buildForm(),
          const SizedBox(height: 30),
          const Divider(),
          const SizedBox(height: 16),
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
            )
          else
            ..._trades.map(_tradeCard),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final project = _selectedProject;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '새 매매 기록',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _projectId,
            decoration: appInputDecoration('프로젝트'),
            items: _projects
                .map(
                  (project) => DropdownMenuItem(
                    value: project.id,
                    child: Text(project.isActive ? '★ ${project.name}' : project.name),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() => _projectId = value);
              _applyRecommendedMargin();
            },
          ),
          if (project != null) ...[
            const SizedBox(height: 10),
            Text(
              '현재 ${money(project.currentBalance)} USDT · '
              '다음 추천 증거금 '
              '${money(project.recommendedMargin)} USDT',
              style: const TextStyle(color: Colors.white60),
            ),
          ],
          const SizedBox(height: 16),
          AppTextField(
            controller: _symbol,
            label: '종목',
            validator: requiredValidator,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _exchange,
            label: '거래소',
            validator: requiredValidator,
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'LONG',
                label: Text('LONG'),
              ),
              ButtonSegment(
                value: 'SHORT',
                label: Text('SHORT'),
              ),
            ],
            selected: {_direction},
            onSelectionChanged: (value) {
              setState(() => _direction = value.first);
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _timeframe,
            decoration: appInputDecoration('시간봉'),
            items: const [
              DropdownMenuItem(
                value: '1m',
                child: Text('1분'),
              ),
              DropdownMenuItem(
                value: '5m',
                child: Text('5분'),
              ),
              DropdownMenuItem(
                value: '15m',
                child: Text('15분'),
              ),
              DropdownMenuItem(
                value: '1h',
                child: Text('1시간'),
              ),
              DropdownMenuItem(
                value: '4h',
                child: Text('4시간'),
              ),
              DropdownMenuItem(
                value: '1d',
                child: Text('1일'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _timeframe = value);
              }
            },
          ),
          const SizedBox(height: 12),
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
              if (value != null) {
                setState(() => _marginMode = value);
              }
            },
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _entry,
            label: '진입가',
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            validator: numberValidator,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _stop,
            label: '손절가',
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            validator: numberValidator,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _target,
            label: '목표가',
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            validator: numberValidator,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _leverage,
                  label: '레버리지',
                  keyboardType: TextInputType.number,
                  validator: integerValidator,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  controller: _margin,
                  label: '증거금',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: numberValidator,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _reason,
            label: '진입 이유',
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _memo,
            label: '메모',
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                _saving ? '저장 중...' : '매매 기록 저장',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tradeCard(Trade trade) {
    final pnl = trade.netPnl;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => _openTrade(trade),
        title: Text(
          '${trade.symbol} · ${trade.direction} · ${trade.status}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${_projectName(trade.projectId)}\n'
          '진입 ${trade.entry} · '
          '${trade.leverage}x · '
          '증거금 ${money(trade.margin)}',
        ),
        trailing: pnl == null
            ? const Icon(Icons.chevron_right)
            : Text(
                '${pnl >= 0 ? '+' : ''}${money(pnl)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: pnl >= 0
                      ? Colors.greenAccent
                      : Colors.redAccent,
                ),
              ),
      ),
    );
  }
}

String money(double value) => value.toStringAsFixed(2);
