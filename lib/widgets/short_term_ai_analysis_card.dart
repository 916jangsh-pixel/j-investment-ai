import 'package:flutter/material.dart';

import '../services/short_term_ai_service.dart';

class ShortTermAiAnalysisCard extends StatefulWidget {
  final int tradeLocalId;

  const ShortTermAiAnalysisCard({
    super.key,
    required this.tradeLocalId,
  });

  @override
  State<ShortTermAiAnalysisCard> createState() =>
      _ShortTermAiAnalysisCardState();
}

class _ShortTermAiAnalysisCardState extends State<ShortTermAiAnalysisCard> {
  bool _loading = true;
  bool _runningAnalysis = false;
  String? _error;
  ShortTermAiAnalysis? _analysis;

  @override
  void initState() {
    super.initState();
    _loadLatestSavedAnalysis();
  }

  @override
  void didUpdateWidget(covariant ShortTermAiAnalysisCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.tradeLocalId != widget.tradeLocalId) {
      _loadLatestSavedAnalysis();
    }
  }

  Future<void> _loadLatestSavedAnalysis() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final row = await ShortTermAiService.instance.getLatestTradeAnalysis(
        tradeLocalId: widget.tradeLocalId,
      );

      if (!mounted) return;

      if (row == null) {
        setState(() {
          _analysis = null;
          _loading = false;
        });
        return;
      }

      final rawResult = _asMap(row['raw_result']);

      final wrappedJson = <String, dynamic>{
        'analysis_id': row['id'],
        'memory_id': null,
        'trade_local_id': row['trade_local_id'] ?? widget.tradeLocalId,
        'project_local_id':
            row['project_local_id'] ??
            rawResult['project_local_id'] ??
            0,
        'result': <String, dynamic>{
          'direction_advice':
              row['direction_advice'] ??
              rawResult['direction_advice'] ??
              'WAIT',
          'confidence':
              row['confidence'] ??
              rawResult['confidence'] ??
              0,
          'summary':
              row['summary'] ??
              rawResult['summary'] ??
              '',
          'reasons':
              row['reasons'] ??
              rawResult['reasons'] ??
              const <String>[],
          'risks':
              row['risks'] ??
              rawResult['risks'] ??
              const <String>[],
          'confirmation_conditions':
              row['confirmation_conditions'] ??
              rawResult['confirmation_conditions'] ??
              const <String>[],
          'invalidation_conditions':
              row['invalidation_conditions'] ??
              rawResult['invalidation_conditions'] ??
              const <String>[],
          'suggested_prices':
              row['suggested_prices'] ??
              rawResult['suggested_prices'] ??
              const <String, dynamic>{},
          'similar_trade_ids':
              row['similar_trades'] ??
              rawResult['similar_trade_ids'] ??
              const <int>[],
        },
      };

      setState(() {
        _analysis = ShortTermAiAnalysis.fromJson(wrappedJson);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = '저장된 AI 분석을 불러오지 못했습니다.\n$e';
      });
    }
  }

  Future<void> _runAnalysis() async {
    if (_runningAnalysis) return;

    setState(() {
      _runningAnalysis = true;
      _error = null;
    });

    try {
      final result = await ShortTermAiService.instance.analyzeTrade(
        tradeLocalId: widget.tradeLocalId,
      );

      if (!mounted) return;

      setState(() {
        _analysis = result;
        _runningAnalysis = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _runningAnalysis = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final analysis = _analysis;

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI 단기 분석',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '저장된 최신 분석을 유지합니다. 다시 분석을 눌렀을 때만 갱신됩니다.',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed:
                      (_loading || _runningAnalysis) ? null : _runAnalysis,
                  icon: _runningAnalysis
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(
                    analysis == null ? 'AI 분석' : '다시 분석',
                  ),
                ),
              ],
            ),
            if (_loading) ...[
              const SizedBox(height: 18),
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              _ErrorBox(message: _error!),
            ],
            if (!_loading && analysis == null && _error == null) ...[
              const SizedBox(height: 18),
              const _EmptyAnalysisBox(),
            ],
            if (!_loading && analysis != null) ...[
              const SizedBox(height: 18),
              _DecisionHeader(analysis: analysis),
              const SizedBox(height: 14),
              Text(
                analysis.summary.isEmpty ? '요약 없음' : analysis.summary,
                style: const TextStyle(
                  height: 1.5,
                  fontSize: 14,
                ),
              ),
              if (analysis.reasons.isNotEmpty) ...[
                const SizedBox(height: 18),
                _StringListSection(
                  title: '판단 근거',
                  icon: Icons.check_circle_outline,
                  items: analysis.reasons,
                ),
              ],
              if (analysis.risks.isNotEmpty) ...[
                const SizedBox(height: 16),
                _StringListSection(
                  title: '리스크',
                  icon: Icons.warning_amber_rounded,
                  items: analysis.risks,
                ),
              ],
              if (analysis.confirmationConditions.isNotEmpty) ...[
                const SizedBox(height: 16),
                _StringListSection(
                  title: '확인 조건',
                  icon: Icons.fact_check_outlined,
                  items: analysis.confirmationConditions,
                ),
              ],
              if (analysis.invalidationConditions.isNotEmpty) ...[
                const SizedBox(height: 16),
                _StringListSection(
                  title: '판단 무효 조건',
                  icon: Icons.block_outlined,
                  items: analysis.invalidationConditions,
                ),
              ],
              if (analysis.similarTradeIds.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  '참고한 과거 매매 ID: ${analysis.similarTradeIds.join(', ')}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'Vision · OKX 멀티타임프레임 시장데이터 · 과거 매매 Memory를 함께 반영합니다.',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;

    if (value is Map) {
      return value.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }

    return <String, dynamic>{};
  }
}

class _EmptyAnalysisBox extends StatelessWidget {
  const _EmptyAnalysisBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: const Text(
        '아직 저장된 AI 분석이 없습니다.\nAI 분석 버튼을 누르면 첫 분석을 생성합니다.',
        style: TextStyle(
          color: Colors.white60,
          height: 1.5,
        ),
      ),
    );
  }
}

class _DecisionHeader extends StatelessWidget {
  final ShortTermAiAnalysis analysis;

  const _DecisionHeader({
    required this.analysis,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;

    switch (analysis.directionAdvice) {
      case 'LONG':
        icon = Icons.trending_up;
        break;
      case 'SHORT':
        icon = Icons.trending_down;
        break;
      case 'AVOID':
        icon = Icons.block;
        break;
      default:
        icon = Icons.pause_circle_outline;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              analysis.directionLabel,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                '신뢰도',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
              Text(
                '${analysis.confidencePercent}%',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StringListSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;

  const _StringListSection({
    required this.title,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 7),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 7),
                  child: SizedBox(
                    width: 5,
                    height: 5,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;

  const _ErrorBox({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.error,
        ),
      ),
      child: Text(
        'AI 분석 오류\n$message',
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          height: 1.4,
        ),
      ),
    );
  }
}
