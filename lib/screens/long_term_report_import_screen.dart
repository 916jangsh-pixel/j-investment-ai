import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../services/long_term_report_import_service.dart';

class LongTermReportImportScreen extends StatefulWidget {
  final int projectLocalId;

  const LongTermReportImportScreen({
    super.key,
    required this.projectLocalId,
  });

  @override
  State<LongTermReportImportScreen> createState() =>
      _LongTermReportImportScreenState();
}

class _LongTermReportImportScreenState
    extends State<LongTermReportImportScreen> {
  final List<XFile> _selectedFiles = <XFile>[];

  bool _isPicking = false;
  bool _isImporting = false;
  int _completed = 0;
  String? _currentFile;

  Future<void> _pickFiles() async {
    if (_isPicking || _isImporting) return;

    setState(() => _isPicking = true);

    try {
      final files =
          await LongTermReportImportService.instance.pickReportFiles();

      if (!mounted) return;

      if (files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('선택된 파일이 없습니다.')),
        );
        return;
      }

      setState(() {
        for (final file in files) {
          final exists =
              _selectedFiles.any((item) => item.path == file.path);

          if (!exists) {
            _selectedFiles.add(file);
          }
        }
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('파일 선택 중 오류가 발생했습니다.\n$e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      }
    }
  }

  Future<void> _importSelectedFiles() async {
    if (_selectedFiles.isEmpty || _isImporting) return;

    setState(() {
      _isImporting = true;
      _completed = 0;
      _currentFile = null;
    });

    try {
      final result =
          await LongTermReportImportService.instance.importFiles(
        projectLocalId: widget.projectLocalId,
        files: List<XFile>.from(_selectedFiles),
        onProgress: (completed, total, fileName) {
          if (!mounted) return;

          setState(() {
            _completed = completed;
            _currentFile = fileName;
          });
        },
      );

      if (!mounted) return;

      if (result.successCount > 0) {
        final message = result.failedCount == 0
            ? '${result.successCount}개 리포트 저장 완료'
            : '${result.successCount}개 저장 / '
                '${result.failedCount}개 실패';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );

        // 부모 화면은 bool 결과를 기다리므로 true를 반환합니다.
        Navigator.of(context).pop(true);
        return;
      }

      final failedNames = result.failedFiles.join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failedNames.isEmpty
                ? '리포트 저장에 실패했습니다.'
                : '리포트 저장 실패: $failedNames',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('리포트 저장 중 오류가 발생했습니다.\n$e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  void _removeFile(int index) {
    if (_isImporting) return;
    setState(() => _selectedFiles.removeAt(index));
  }

  void _clearFiles() {
    if (_isImporting) return;
    setState(_selectedFiles.clear);
  }

  @override
  Widget build(BuildContext context) {
    final progress = _selectedFiles.isEmpty
        ? 0.0
        : _completed / _selectedFiles.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('장기 리포트 가져오기'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '리포트 파일 가져오기',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'PDF, DOC, DOCX, TXT, MD 파일을 여러 개 한 번에 선택할 수 있습니다.',
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed:
                    (_isPicking || _isImporting) ? null : _pickFiles,
                icon: _isPicking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file),
                label: Text(
                  _isPicking ? '파일 선택 중...' : '리포트 파일 선택',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '선택된 파일 ${_selectedFiles.length}개',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_selectedFiles.isNotEmpty)
                    TextButton(
                      onPressed: _isImporting ? null : _clearFiles,
                      child: const Text('전체 삭제'),
                    ),
                ],
              ),
              const Divider(),
              Expanded(
                child: _selectedFiles.isEmpty
                    ? const Center(
                        child: Text(
                          '아직 선택된 리포트가 없습니다.\n'
                          '위 버튼을 눌러 여러 파일을 선택하세요.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        itemCount: _selectedFiles.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final file = _selectedFiles[index];

                          return ListTile(
                            leading:
                                const Icon(Icons.description_outlined),
                            title: Text(
                              file.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              file.path,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              tooltip: '삭제',
                              onPressed: _isImporting
                                  ? null
                                  : () => _removeFile(index),
                              icon: const Icon(Icons.close),
                            ),
                          );
                        },
                      ),
              ),
              if (_isImporting) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 8),
                Text(
                  '$_completed / ${_selectedFiles.length}'
                  '${_currentFile == null ? '' : ' · $_currentFile'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: (_selectedFiles.isEmpty || _isImporting)
                    ? null
                    : _importSelectedFiles,
                icon: _isImporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(
                  _selectedFiles.isEmpty
                      ? '가져올 리포트를 선택하세요'
                      : _isImporting
                          ? '저장 중...'
                          : '선택한 리포트 ${_selectedFiles.length}개 저장',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
