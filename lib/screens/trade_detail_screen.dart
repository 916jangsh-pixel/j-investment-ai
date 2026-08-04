import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart' as fs;
import 'package:image_picker/image_picker.dart';

import '../models/trade.dart';
import '../models/trade_image.dart';
import '../services/image_storage_service.dart';
import '../services/trade_calculator.dart';
import '../services/trade_database.dart';
import '../widgets/app_text_field.dart';
import '../widgets/short_term_ai_analysis_card.dart';

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

  final ImagePicker _picker = ImagePicker();
  List<TradeImage> _images = const [];

  TradeResult? _preview;
  bool _saving = false;
  bool _loadingImages = true;

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
    _loadImages();
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

  Future<void> _loadImages() async {
    final id = widget.trade.id;

    if (id == null) {
      if (mounted) {
        setState(() => _loadingImages = false);
      }
      return;
    }

    final images = await TradeDatabase.instance.getTradeImages(id);

    if (!mounted) return;

    setState(() {
      _images = images;
      _loadingImages = false;
    });
  }

  Future<void> _addGalleryImages(String stage) async {
    final tradeId = widget.trade.id;
    if (tradeId == null) return;

    try {
      // Android 13+의 제한된 사진 권한/Photo Picker 문제를 피하기 위해
      // 시스템 파일 선택기(SAF)를 사용합니다.
      const imageTypes = fs.XTypeGroup(
        label: 'images',
        extensions: <String>[
          'jpg',
          'jpeg',
          'png',
          'webp',
          'heic',
          'heif',
        ],
      );

      final picked = await fs.openFiles(
        acceptedTypeGroups: const <fs.XTypeGroup>[imageTypes],
      );

      if (picked.isEmpty) return;

      for (final image in picked) {
        final savedPath = await ImageStorageService.instance.persistImage(
          sourcePath: image.path,
          tradeId: tradeId,
          stage: stage,
        );

        await TradeDatabase.instance.insertTradeImage(
          TradeImage(
            tradeId: tradeId,
            localPath: savedPath,
            stage: stage,
            createdAt: DateTime.now(),
          ),
        );
      }

      await _loadImages();

      if (mounted) {
        _message('${picked.length}장의 차트 이미지를 추가했습니다.');
      }
    } catch (e) {
      _message('이미지를 추가하지 못했습니다: $e');
    }
  }

  Future<void> _addCameraImage(String stage) async {
    final tradeId = widget.trade.id;
    if (tradeId == null) return;

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 88,
        maxWidth: 2000,
      );

      if (picked == null) return;

      final savedPath = await ImageStorageService.instance.persistImage(
        sourcePath: picked.path,
        tradeId: tradeId,
        stage: stage,
      );

      await TradeDatabase.instance.insertTradeImage(
        TradeImage(
          tradeId: tradeId,
          localPath: savedPath,
          stage: stage,
          createdAt: DateTime.now(),
        ),
      );

      await _loadImages();
    } catch (e) {
      _message('카메라 이미지를 추가하지 못했습니다: $e');
    }
  }

  Future<void> _deleteImage(TradeImage image) async {
    final id = image.id;
    if (id == null) return;

    await ImageStorageService.instance.deleteImage(image.localPath);
    await TradeDatabase.instance.deleteTradeImage(id);
    await _loadImages();
  }

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
          _imageSection(trade),
          const SizedBox(height: 18),
          if (trade.id != null) ...[
            ShortTermAiAnalysisCard(
              tradeLocalId: trade.id!,
            ),
            const SizedBox(height: 18),
          ],
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

  Widget _imageSection(Trade trade) {
    final entryImages =
        _images.where((image) => image.stage == 'ENTRY').toList();
    final exitImages =
        _images.where((image) => image.stage == 'EXIT').toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '차트 캡처',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'AI가 나중에 진입·청산 위치와 반복 패턴을 분석할 때 사용하는 자료입니다.',
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 14),
            if (_loadingImages)
              const Center(child: CircularProgressIndicator())
            else ...[
              _imageGroup('진입 차트', entryImages),
              const SizedBox(height: 14),
              _imageGroup('청산/복기 차트', exitImages),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _addGalleryImages('EXIT'),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('청산 차트 추가'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _addCameraImage('EXIT'),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('카메라'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageGroup(String title, List<TradeImage> images) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title (${images.length})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (images.isEmpty)
          const Text(
            '첨부 이미지 없음',
            style: TextStyle(color: Colors.white38),
          )
        else
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final image = images[index];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(image.localPath),
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 120,
                          height: 120,
                          alignment: Alignment.center,
                          color: Colors.white10,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
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
                          onTap: () => _deleteImage(image),
                          child: const Padding(
                            padding: EdgeInsets.all(5),
                            child: Icon(
                              Icons.delete_outline,
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
