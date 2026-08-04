import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:file_selector/file_selector.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'long_term_report_service.dart';

class LongTermReportImportResult {
  final int successCount;
  final int failedCount;
  final List<String> failedFiles;

  const LongTermReportImportResult({
    required this.successCount,
    required this.failedCount,
    required this.failedFiles,
  });
}

class LongTermReportImportService {
  LongTermReportImportService._();

  static final LongTermReportImportService instance =
      LongTermReportImportService._();

  static const String bucketName = 'long-term-reports';

  SupabaseClient get _client => Supabase.instance.client;

  String _requireUserId() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Supabase 로그인 사용자가 없습니다.');
    }
    return user.id;
  }

  Future<List<XFile>> pickReportFiles() async {
    const reportFiles = XTypeGroup(
      label: '장기투자 리포트',
      extensions: <String>[
        'pdf',
        'doc',
        'docx',
        'txt',
        'md',
      ],
    );

    return openFiles(
      acceptedTypeGroups: const <XTypeGroup>[reportFiles],
    );
  }

  Future<LongTermReportImportResult> importFiles({
    required int projectLocalId,
    required List<XFile> files,
    void Function(int completed, int total, String fileName)? onProgress,
  }) async {
    final userId = _requireUserId();

    var successCount = 0;
    final failedFiles = <String>[];

    for (var index = 0; index < files.length; index++) {
      final file = files[index];
      String? uploadedPath;

      try {
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) {
          throw StateError('빈 파일입니다.');
        }

        final extension = _extensionOf(file.name);
        final stamp = DateTime.now().microsecondsSinceEpoch;

        // Storage에는 ASCII 기반의 안전한 object key만 사용합니다.
        // 원본 파일명은 아래 DB title에 그대로 보존됩니다.
        final storageFileName =
            extension.isEmpty ? '$stamp.bin' : '$stamp.$extension';

        uploadedPath = '$userId/$projectLocalId/$storageFileName';

        await _client.storage.from(bucketName).uploadBinary(
              uploadedPath,
              bytes,
              fileOptions: FileOptions(
                upsert: false,
                contentType: _contentType(extension),
              ),
            );

        String? rawText;
        if (extension == 'txt' || extension == 'md') {
          rawText = _decodeText(bytes);
        } else if (extension == 'docx') {
          rawText = _extractDocxText(bytes);
        } else if (extension == 'pdf') {
          rawText = _extractPdfText(bytes);
        }

        final createdReport = await LongTermReportService.instance.createReport(
          projectLocalId: projectLocalId,
          title: _titleFromFileName(file.name),
          sourceType: 'USER_REPORT',
          storagePath: uploadedPath,
          rawText: rawText,
        );

        // 원본 저장 성공이 최우선입니다.
        // AI 분석 실패가 업로드 전체 실패로 이어지지 않도록 별도 try/catch로 분리합니다.
        if (createdReport.id != null &&
            rawText != null &&
            rawText.trim().isNotEmpty) {
          try {
            final response = await _client.functions.invoke(
              'long-term-report-analyze',
              body: <String, dynamic>{
                'report_id': createdReport.id,
              },
            );

            debugPrint('[LONG TERM REPORT AI ANALYZE SUCCESS]');
            debugPrint('reportId: ${createdReport.id}');
            debugPrint('response: ${response.data}');
          } catch (analysisError, analysisStackTrace) {
            debugPrint('========================================');
            debugPrint('[LONG TERM REPORT AI ANALYZE FAILED]');
            debugPrint('fileName: ${file.name}');
            debugPrint('reportId: ${createdReport.id}');
            debugPrint('error: $analysisError');
            debugPrint('stackTrace: $analysisStackTrace');
            debugPrint('원본 리포트 저장은 유지됩니다.');
            debugPrint('========================================');
          }
        }

        successCount++;
      } catch (error, stackTrace) {
        final errorText = error.toString();

        debugPrint('========================================');
        debugPrint('[LONG TERM REPORT IMPORT FAILED]');
        debugPrint('fileName: ${file.name}');
        debugPrint('projectLocalId: $projectLocalId');
        debugPrint('uploadedPath: $uploadedPath');
        debugPrint('errorType: ${error.runtimeType}');
        debugPrint('error: $errorText');
        debugPrint('stackTrace: $stackTrace');
        debugPrint('========================================');

        // 화면에서도 실제 Supabase 오류를 확인할 수 있도록
        // 파일명과 오류 내용을 함께 전달합니다.
        failedFiles.add('${file.name}\n$errorText');

        if (uploadedPath != null) {
          try {
            await _client.storage
                .from(bucketName)
                .remove(<String>[uploadedPath]);
          } catch (cleanupError, cleanupStackTrace) {
            debugPrint('[REPORT CLEANUP FAILED]');
            debugPrint('path: $uploadedPath');
            debugPrint('error: $cleanupError');
            debugPrint('stackTrace: $cleanupStackTrace');
          }
        }
      }

      onProgress?.call(index + 1, files.length, file.name);
    }

    return LongTermReportImportResult(
      successCount: successCount,
      failedCount: failedFiles.length,
      failedFiles: failedFiles,
    );
  }

  String _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  String _titleFromFileName(String name) {
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }


  String _extractPdfText(List<int> bytes) {
    final document = PdfDocument(inputBytes: bytes);

    try {
      final text = PdfTextExtractor(document).extractText().trim();

      if (text.isEmpty) {
        throw const FormatException(
          'PDF에서 추출된 본문이 없습니다. 스캔 이미지 PDF라면 OCR 처리가 필요합니다.',
        );
      }

      return text;
    } finally {
      document.dispose();
    }
  }

  String _extractDocxText(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    ArchiveFile? documentFile;
    for (final file in archive.files) {
      if (file.name == 'word/document.xml') {
        documentFile = file;
        break;
      }
    }

    if (documentFile == null) {
      throw const FormatException(
        'DOCX 내부에서 word/document.xml을 찾을 수 없습니다.',
      );
    }

    final content = documentFile.content;
    if (content is! List<int>) {
      throw const FormatException('DOCX document.xml을 읽을 수 없습니다.');
    }

    final xmlText = utf8.decode(content);
    final document = XmlDocument.parse(xmlText);

    final buffer = StringBuffer();

    // 문단 단위로 텍스트를 합쳐 원문 구조를 최대한 유지합니다.
    for (final paragraph in document.descendants.whereType<XmlElement>()) {
      if (paragraph.name.local != 'p') continue;

      final parts = paragraph.descendants
          .whereType<XmlElement>()
          .where((element) => element.name.local == 't')
          .map((element) => element.innerText)
          .where((text) => text.isNotEmpty)
          .toList();

      if (parts.isNotEmpty) {
        buffer.writeln(parts.join());
      }
    }

    final text = buffer.toString().trim();
    if (text.isEmpty) {
      throw const FormatException('DOCX에서 추출된 본문이 없습니다.');
    }

    return text;
  }

  String _contentType(String extension) {
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'md':
        return 'text/markdown';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  String _decodeText(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes);
    }
  }
}
