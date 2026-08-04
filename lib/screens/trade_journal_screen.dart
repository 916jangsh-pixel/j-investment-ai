import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/project.dart';
import '../models/trade.dart';
import '../models/trade_image.dart';
import '../models/shadow_trade.dart';
import '../services/image_storage_service.dart';
import '../services/okx_market_service.dart';
import '../services/short_term_ai_service.dart';
import '../services/shadow_trade_service.dart';
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

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _pendingImages = [];

  List<Project> _projects = const [];
  List<Trade> _trades = const [];
  List<ShadowTrade> _shadowTrades = const [];

  int? _projectId;
  String _direction = 'LONG';
  String _timeframe = '15m';
  String _marginMode = 'ISOLATED';

  bool _loading = true;
  bool _saving = false;

  bool _entryAiLoading = false;
  bool _shadowStarting = false;
  String? _entryAiError;
  ShortTermAiAnalysis? _entryAiAnalysis;
  double? _entryAiCurrentPrice;

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

    List<ShadowTrade> shadowTrades = const [];
    try {
      shadowTrades = await ShadowTradeService.instance.getAll(limit: 20);
    } catch (_) {
      // Shadow Trading 테이블/로그인 문제 때문에 기존 매매일지 화면이
      // 막히지 않도록 별도로 처리합니다.
    }

    if (!mounted) return;

    final selected = active?.id ??
        (projects.isNotEmpty ? projects.first.id : null);

    setState(() {
      _projects = projects;
      _trades = trades;
      _shadowTrades = shadowTrades;
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

  Future<void> _pickGalleryImages() async {
    try {
      final images = await _picker.pickMultiImage(
        imageQuality: 88,
        maxWidth: 2000,
      );
      if (images.isEmpty || !mounted) return;

      setState(() {
        _pendingImages.addAll(images);
      });
    } catch (e) {
      _message('이미지를 불러오지 못했습니다: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 88,
        maxWidth: 2000,
      );
      if (image == null || !mounted) return;

      setState(() {
        _pendingImages.add(image);
      });
    } catch (e) {
      _message('카메라를 열지 못했습니다: $e');
    }
  }

  void _removePendingImage(int index) {
    setState(() {
      _pendingImages.removeAt(index);
    });
  }

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
      final tradeId = await TradeDatabase.instance.insertTrade(trade);

      var imageFailures = 0;

      for (final image in _pendingImages) {
        try {
          final savedPath = await ImageStorageService.instance.persistImage(
            sourcePath: image.path,
            tradeId: tradeId,
            stage: 'ENTRY',
          );

          await TradeDatabase.instance.insertTradeImage(
            TradeImage(
              tradeId: tradeId,
              localPath: savedPath,
              stage: 'ENTRY',
              createdAt: DateTime.now(),
            ),
          );
        } catch (_) {
          imageFailures++;
        }
      }

      _entry.clear();
      _stop.clear();
      _target.clear();
      _reason.clear();
      _memo.clear();
      _pendingImages.clear();

      await _load();
      widget.onDataChanged?.call();
      _message(
        imageFailures == 0
            ? '매매 기록과 차트 이미지가 저장되었습니다.'
            : '매매 기록은 저장됐지만 이미지 $imageFailures장은 저장하지 못했습니다.',
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _openTrade(Trade trade) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TradeDetailScreen(trade: trade),
      ),
    );

    if (changed == true) {
      await _load();
      widget.onDataChanged?.call();
    }
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

  String get _okxInstrument {
    final raw = _symbol.text.trim().toUpperCase();
    if (raw.contains('-')) return raw;
    if (raw.endsWith('USDT')) {
      final base = raw.substring(0, raw.length - 4);
      return '$base-USDT-SWAP';
    }
    return '$raw-USDT-SWAP';
  }

  Future<void> _runEntryAiAnalysis() async {
    if (_entryAiLoading) return;

    setState(() {
      _entryAiLoading = true;
      _entryAiError = null;
    });

    try {
      // Use the same OKX market service already used by the project.
      final ticker = await OkxMarketService.instance.getTicker(
        symbol: _symbol.text.trim().toUpperCase(),
      );
      final price = ticker.last;

      final projectId = _projectId;
      if (projectId == null) {
        throw StateError('먼저 프로젝트를 선택해주세요.');
      }

      final result = await ShortTermAiService.instance.analyzePreEntry(
        projectLocalId: projectId,
        symbol: _symbol.text.trim().toUpperCase(),
      );

      if (!mounted) return;
      setState(() {
        _entryAiCurrentPrice = price;
        _entryAiAnalysis = result;
        _entryAiLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _entryAiLoading = false;
        _entryAiError = e.toString();
      });
    }
  }

  void _applyAiToTradeForm() {
    final analysis = _entryAiAnalysis;
    if (analysis == null) return;

    if (analysis.directionAdvice == 'LONG' ||
        analysis.directionAdvice == 'SHORT') {
      setState(() => _direction = analysis.directionAdvice);
    }

    double? number(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '');
    }

    final suggested = analysis.suggestedPrices;
    final aiEntry = number(suggested['entry']);
    final aiStop = number(suggested['stop']);
    final aiTarget = number(suggested['target']);
    final aiLeverage = number(suggested['recommended_leverage']);

    if (aiEntry != null && aiEntry > 0) {
      _entry.text = aiEntry.toStringAsFixed(2);
    } else if (_entryAiCurrentPrice != null) {
      _entry.text = _entryAiCurrentPrice!.toStringAsFixed(2);
    }

    if (aiStop != null && aiStop > 0) {
      _stop.text = aiStop.toStringAsFixed(2);
    }

    if (aiTarget != null && aiTarget > 0) {
      _target.text = aiTarget.toStringAsFixed(2);
    }

    if (aiLeverage != null && aiLeverage >= 1) {
      final projectMax = _selectedProject?.maxLeverage ?? aiLeverage.round();
      final safeLeverage = aiLeverage.round().clamp(1, projectMax);
      _leverage.text = safeLeverage.toString();
    }

    _reason.text = [
      'AI 진입 전 분석: ${analysis.directionLabel}',
      '신뢰도 ${analysis.confidencePercent}%',
      if (analysis.summary.isNotEmpty) analysis.summary,
    ].join('\n');

    _message('AI 추천값을 새 매매 기록에 반영했습니다. 실제 주문 전 가격과 리스크를 다시 확인해주세요.');
  }

  Future<void> _startShadowTrade() async {
    if (_shadowStarting) return;

    final analysis = _entryAiAnalysis;
    if (analysis == null) {
      _message('먼저 AI 진입 분석을 실행해주세요.');
      return;
    }

    if (analysis.directionAdvice != 'LONG' &&
        analysis.directionAdvice != 'SHORT') {
      _message('WAIT/AVOID 판단은 가상매매를 시작하지 않습니다.');
      return;
    }

    double? number(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '');
    }

    final suggested = analysis.suggestedPrices;
    final entry = number(suggested['entry']) ?? _entryAiCurrentPrice;
    final stop = number(suggested['stop']);
    final target = number(suggested['target']);
    final requestedLeverage =
        number(suggested['recommended_leverage']) ?? 1;

    if (entry == null || entry <= 0 || stop == null || stop <= 0 ||
        target == null || target <= 0) {
      _message(
        'AI가 유효한 진입가·손절가·목표가를 모두 제시한 경우에만 '
        '가상매매를 시작합니다.',
      );
      return;
    }

    final isLong = analysis.directionAdvice == 'LONG';
    final validStructure = isLong
        ? (stop < entry && target > entry)
        : (stop > entry && target < entry);

    if (!validStructure) {
      _message('AI 추천 가격 구조가 올바르지 않아 가상매매를 시작하지 않았습니다.');
      return;
    }

    final projectMax = _selectedProject?.maxLeverage ?? 20;
    final leverage = requestedLeverage.clamp(1, projectMax).toDouble();

    setState(() => _shadowStarting = true);

    try {
      final created = await ShadowTradeService.instance.create(
        symbol: _symbol.text.trim().toUpperCase(),
        instrument: OkxMarketService.instance.toSwapInstId(
          _symbol.text.trim().toUpperCase(),
        ),
        timeframe: 'MTF',
        direction: analysis.directionAdvice,
        entryPrice: entry,
        stopPrice: stop,
        targetPrice: target,
        leverage: leverage,
        virtualMargin: 100,
        sourceAnalysisId: analysis.analysisId,
        aiConfidence: analysis.confidence,
        entryReason: analysis.summary,
        entrySnapshot: <String, dynamic>{
          'analysis_id': analysis.analysisId,
          'direction_advice': analysis.directionAdvice,
          'confidence': analysis.confidence,
          'summary': analysis.summary,
          'reasons': analysis.reasons,
          'risks': analysis.risks,
          'confirmation_conditions': analysis.confirmationConditions,
          'invalidation_conditions': analysis.invalidationConditions,
          'suggested_prices': analysis.suggestedPrices,
          'current_price_at_start': _entryAiCurrentPrice,
        },
      );

      final recent = await ShadowTradeService.instance.getAll(limit: 20);

      if (!mounted) return;
      setState(() {
        _shadowTrades = recent;
        _shadowStarting = false;
      });

      _message(
        '가상매매 #${created.id ?? '-'} 시작 완료 · '
        '${created.direction} ${created.entryPrice.toStringAsFixed(2)}',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _shadowStarting = false);
      _message('가상매매 시작 실패: $e');
    }
  }

  Widget _buildShadowHistory() {
    if (_shadowTrades.isEmpty) {
      return const SizedBox.shrink();
    }

    final recent = _shadowTrades.take(5).toList(growable: false);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'AI 가상매매 이력',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${_shadowTrades.length}건',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...recent.map(
              (trade) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${trade.symbol} · ${trade.direction}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '진입 ${trade.entryPrice.toStringAsFixed(2)} · '
                              'SL ${trade.stopPrice.toStringAsFixed(2)} · '
                              'TP ${trade.targetPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            trade.status,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (trade.status != 'OPEN')
                            Text(
                              '${trade.returnPercent.toStringAsFixed(2)}%',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Text(
              '현재 단계에서는 OPEN 포지션 생성까지 연결되었습니다. '
              '다음 단계에서 서버 24시간 감시와 자동 청산을 연결합니다.',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryAiPanel() {
    final analysis = _entryAiAnalysis;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt, size: 24),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI 실시간 단타 판단',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        '실제 진입 전에 현재 시장과 학습 데이터를 확인합니다.',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _symbol.text.trim().isEmpty
                        ? 'BTCUSDT'
                        : _symbol.text.trim().toUpperCase(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_entryAiCurrentPrice != null)
                  Text(
                    _entryAiCurrentPrice!.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _TimeframeChip('5m'),
                _TimeframeChip('15m'),
                _TimeframeChip('1H'),
                _TimeframeChip('4H'),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _entryAiLoading ? null : _runEntryAiAnalysis,
              icon: _entryAiLoading
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  analysis == null ? 'AI에게 지금 진입 분석' : '현재 시장 다시 분석',
                ),
              ),
            ),
            if (_entryAiError != null) ...[
              const SizedBox(height: 12),
              Text(
                '분석 실패: $_entryAiError',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
            if (analysis != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        analysis.directionLabel,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          '신뢰도',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                        Text(
                          '${analysis.confidencePercent}%',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (analysis.summary.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  analysis.summary,
                  style: const TextStyle(height: 1.45),
                ),
              ],
              if (analysis.reasons.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  '판단 근거',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                ...analysis.reasons.take(3).map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text('• $e'),
                      ),
                    ),
              ],
              if (analysis.risks.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text(
                  '리스크',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                ...analysis.risks.take(2).map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text('• $e'),
                      ),
                    ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _shadowStarting ? null : _startShadowTrade,
                      icon: _shadowStarting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.science_outlined),
                      label: Text(
                        _shadowStarting ? '시작 중' : '가상매매 시작',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _applyAiToTradeForm,
                      icon: const Icon(Icons.edit_note),
                      label: const Text('실제 매매로 기록'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
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
          _buildEntryAiPanel(),
          const SizedBox(height: 16),
          _buildShadowHistory(),
          if (_shadowTrades.isNotEmpty) const SizedBox(height: 24),
          if (_shadowTrades.isEmpty) const SizedBox(height: 24),
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
          const SizedBox(height: 18),
          const Text(
            '진입 차트 캡처',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'AI 분석에 사용할 진입 전/진입 시점 차트를 여러 장 첨부할 수 있습니다.',
            style: TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickGalleryImages,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('갤러리 여러 장'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _takePhoto,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('카메라'),
                ),
              ),
            ],
          ),
          if (_pendingImages.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _pendingImages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final image = _pendingImages[index];
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(image.path),
                          width: 118,
                          height: 118,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _removePendingImage(index),
                            child: const Padding(
                              padding: EdgeInsets.all(5),
                              child: Icon(
                                Icons.close,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
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


class _TimeframeChip extends StatelessWidget {
  final String label;

  const _TimeframeChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String money(double value) => value.toStringAsFixed(2);
