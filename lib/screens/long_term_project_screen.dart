import 'package:flutter/material.dart';

import '../models/long_term_chat_message.dart';
import '../models/long_term_report.dart';
import '../services/long_term_ai_service.dart';
import '../services/long_term_candidate_service.dart';
import '../services/long_term_watchlist_service.dart';
import '../services/long_term_news_service.dart';
import '../services/long_term_report_service.dart';
import 'long_term_report_import_screen.dart';

class LongTermProjectScreen extends StatefulWidget {
  final int projectLocalId;
  final String projectName;

  const LongTermProjectScreen({
    super.key,
    required this.projectLocalId,
    required this.projectName,
  });

  @override
  State<LongTermProjectScreen> createState() => _LongTermProjectScreenState();
}

class _LongTermProjectScreenState extends State<LongTermProjectScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _ReportsTab(projectLocalId: widget.projectLocalId),
      _ChatTab(projectLocalId: widget.projectLocalId),
      _NewsTab(projectLocalId: widget.projectLocalId),
      _CandidatesTab(projectLocalId: widget.projectLocalId),
      _WatchlistTab(projectLocalId: widget.projectLocalId),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectName),
      ),
      body: pages[_tabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) {
          setState(() => _tabIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
            label: '리포트',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'AI 대화',
          ),
          NavigationDestination(
            icon: Icon(Icons.newspaper_outlined),
            selectedIcon: Icon(Icons.newspaper),
            label: '뉴스',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_outline),
            selectedIcon: Icon(Icons.star),
            label: '최종 후보',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border),
            selectedIcon: Icon(Icons.bookmark),
            label: '관심종목',
          ),
        ],
      ),
    );
  }
}

class _ReportsTab extends StatefulWidget {
  final int projectLocalId;

  const _ReportsTab({required this.projectLocalId});

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  bool _loading = true;
  String? _error;
  List<LongTermReport> _reports = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final reports = await LongTermReportService.instance.getReports(
        projectLocalId: widget.projectLocalId,
      );

      if (!mounted) return;
      setState(() {
        _reports = reports;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _openBulkImport() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LongTermReportImportScreen(
          projectLocalId: widget.projectLocalId,
        ),
      ),
    );

    if (changed == true) {
      await _load();
    }
  }

  Future<void> _addTextReport() async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('리포트 추가'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: '리포트 제목',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentController,
                  minLines: 6,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    labelText: 'Google Docs 본문 붙여넣기',
                    hintText: '현재는 텍스트 입력부터 연결합니다.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('저장'),
            ),
          ],
        );
      },
    );

    if (shouldSave != true) return;

    final title = titleController.text.trim();
    final content = contentController.text.trim();
    if (title.isEmpty || content.isEmpty) return;

    try {
      await LongTermReportService.instance.createReport(
        projectLocalId: widget.projectLocalId,
        title: title,
        rawText: content,
        sourceType: 'USER_REPORT',
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('리포트 저장 실패: $e')),
      );
    }
  }

  String _reportDateText(DateTime? value) {
    final date = value?.toLocal();
    if (date == null) return '';

    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}.${two(date.month)}.${two(date.day)}';
  }

  Widget _reportMetaChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Future<bool> _editReport(LongTermReport report) async {
    final titleController = TextEditingController(text: report.title);
    final contentController = TextEditingController(
      text: report.rawText ?? '',
    );

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('리포트 수정'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: '리포트 제목',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentController,
                    minLines: 10,
                    maxLines: 18,
                    decoration: const InputDecoration(
                      labelText: '리포트 원문',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('저장'),
            ),
          ],
        );
      },
    );

    if (shouldSave != true) return false;

    final title = titleController.text.trim();
    final rawText = contentController.text.trim();

    if (title.isEmpty || rawText.isEmpty) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목과 원문을 모두 입력하세요.')),
      );
      return false;
    }

    try {
      await LongTermReportService.instance.updateReportAndAnalyze(
        report: report,
        title: title,
        rawText: rawText,
      );

      await _load();

      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('리포트 수정 완료')),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('리포트 수정 실패: $e')),
      );
      return false;
    }
  }

  Future<bool> _deleteReport(LongTermReport report) async {
    if (report.id == null) return false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('리포트 삭제'),
          content: Text(
            '"${report.title}" 리포트를 삭제할까요?\n'
            '삭제한 리포트는 복구할 수 없습니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return false;

    try {
      await LongTermReportService.instance.deleteReport(report.id!);
      await _load();

      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('리포트 삭제 완료')),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('리포트 삭제 실패: $e')),
      );
      return false;
    }
  }

  Future<void> _openReportDetail(LongTermReport report) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final reportDate = report.reportDate ?? report.createdAt;

        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.88,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 8, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          report.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '수정',
                        onPressed: () async {
                          Navigator.pop(sheetContext);
                          await _editReport(report);
                        },
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: '삭제',
                        onPressed: () async {
                          Navigator.pop(sheetContext);
                          await _deleteReport(report);
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (_reportDateText(reportDate).isNotEmpty)
                            _reportMetaChip(
                              '리포트 날짜 ${_reportDateText(reportDate)}',
                            ),
                          _reportMetaChip(report.sourceType),
                          ...report.symbols.map(_reportMetaChip),
                          ...report.sectors.map(_reportMetaChip),
                          ...report.tags.map(_reportMetaChip),
                        ],
                      ),

                      if (report.summary?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 22),
                        const Text(
                          'AI 요약',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: SelectableText(
                              report.summary!.trim(),
                              style: const TextStyle(height: 1.55),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 22),
                      const Text(
                        '리포트 원문',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: SelectableText(
                            report.rawText?.trim().isNotEmpty == true
                                ? report.rawText!.trim()
                                : report.storagePath?.trim().isNotEmpty == true
                                    ? '원문 텍스트가 저장되어 있지 않습니다.\n\n'
                                        '저장 파일 경로: ${report.storagePath}'
                                    : '저장된 원문이 없습니다.',
                            style: const TextStyle(height: 1.6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
          const Text(
            '내 장기투자 리포트',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _openBulkImport,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('여러 파일 가져오기'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _addTextReport,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('직접 입력'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '내가 작성한 리포트가 장기 AI 판단의 최우선 데이터가 됩니다.',
            style: TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 20),
          if (_error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!),
              ),
            )
          else if (_reports.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  '등록된 리포트가 없습니다.\n'
                  'Google Docs 리포트 본문을 먼저 추가해보세요.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ..._reports.map(
              (report) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  onTap: () => _openReportDetail(report),
                  leading: const Icon(Icons.article_outlined),
                  title: Text(
                    report.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      [
                        if (report.symbols.isNotEmpty)
                          report.symbols.take(3).join(', '),
                        _reportDateText(
                          report.reportDate ?? report.createdAt,
                        ),
                      ].where((e) => e.isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChatTab extends StatefulWidget {
  final int projectLocalId;

  const _ChatTab({required this.projectLocalId});

  @override
  State<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<_ChatTab> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  int? _conversationId;
  bool _busy = false;
  bool _loadingHistory = true;

  List<LongTermChatMessage> _messages = const [];
  List<Map<String, dynamic>> _conversations = const [];

  @override
  void initState() {
    super.initState();
    _loadConversationHistory(openLatest: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadConversationHistory({
    bool openLatest = false,
  }) async {
    try {
      final conversations =
          await LongTermAiService.instance.getConversations(
        projectLocalId: widget.projectLocalId,
      );

      if (!mounted) return;

      setState(() {
        _conversations = conversations;
        _loadingHistory = false;
      });

      if (openLatest &&
          _conversationId == null &&
          conversations.isNotEmpty) {
        final latestId = _toInt(conversations.first['id']);
        if (latestId != null) {
          await _openConversation(latestId);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingHistory = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('최근 대화 불러오기 실패: $e')),
      );
    }
  }

  Future<void> _openConversation(int conversationId) async {
    final messages = await LongTermAiService.instance.getMessages(
      conversationId: conversationId,
    );

    if (!mounted) return;

    setState(() {
      _conversationId = conversationId;
      _messages = messages;
    });

    _scrollToBottom();
  }

  Future<void> _newConversation() async {
    if (_busy) return;

    setState(() {
      _conversationId = null;
      _messages = const [];
      _controller.clear();
    });
  }

  Future<void> _ensureConversation(String firstMessage) async {
    if (_conversationId != null) return;

    final title = _makeConversationTitle(firstMessage);

    final id = await LongTermAiService.instance.createConversation(
      projectLocalId: widget.projectLocalId,
      title: title,
    );

    if (!mounted) return;

    setState(() => _conversationId = id);
    await _loadConversationHistory();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;

    setState(() => _busy = true);

    try {
      await _ensureConversation(text);

      final conversationId = _conversationId;
      if (conversationId == null) {
        throw StateError('대화방을 만들지 못했습니다.');
      }

      // 질문을 먼저 DB에 저장한 뒤 즉시 다시 읽어 화면에 표시합니다.
      await LongTermAiService.instance.saveUserMessage(
        projectLocalId: widget.projectLocalId,
        conversationId: conversationId,
        content: text,
      );

      _controller.clear();

      final userSavedMessages =
          await LongTermAiService.instance.getMessages(
        conversationId: conversationId,
      );

      if (mounted) {
        setState(() => _messages = userSavedMessages);
        _scrollToBottom();
      }

      // USER 메시지는 이미 저장했으므로 여기서는 AI만 호출합니다.
      await LongTermAiService.instance.askAiAfterUserSaved(
        projectLocalId: widget.projectLocalId,
        conversationId: conversationId,
        message: text,
      );

      final messages = await LongTermAiService.instance.getMessages(
        conversationId: conversationId,
      );

      if (!mounted) return;

      setState(() => _messages = messages);
      await _loadConversationHistory();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      // AI 호출 실패 시에도 이미 저장된 사용자 질문은 유지/표시합니다.
      if (_conversationId != null) {
        try {
          final messages = await LongTermAiService.instance.getMessages(
            conversationId: _conversationId!,
          );
          if (mounted) {
            setState(() => _messages = messages);
          }
        } catch (_) {}
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI 대화 오류: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showRecentChats() async {
    await _loadConversationHistory();

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.72,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '최근 대화',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _newConversation();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('새 대화'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _conversations.isEmpty
                      ? const Center(
                          child: Text('저장된 대화가 없습니다.'),
                        )
                      : ListView.builder(
                          itemCount: _conversations.length,
                          itemBuilder: (context, index) {
                            final item = _conversations[index];
                            final id = _toInt(item['id']);
                            final title =
                                item['title']?.toString().trim();
                            final isSelected =
                                id != null && id == _conversationId;

                            return ListTile(
                              selected: isSelected,
                              leading: Icon(
                                isSelected
                                    ? Icons.chat_bubble
                                    : Icons.chat_bubble_outline,
                              ),
                              title: Text(
                                title == null || title.isEmpty
                                    ? '제목 없는 대화'
                                    : title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                _dateLabel(
                                  item['updated_at'] ??
                                      item['created_at'],
                                ),
                              ),
                              onTap: id == null
                                  ? null
                                  : () async {
                                      Navigator.pop(sheetContext);
                                      await _openConversation(id);
                                    },
                              trailing: id == null
                                  ? null
                                  : IconButton(
                                      tooltip: '대화 삭제',
                                      icon: const Icon(
                                        Icons.delete_outline,
                                      ),
                                      onPressed: () async {
                                        final ok =
                                            await showDialog<bool>(
                                          context: sheetContext,
                                          builder: (dialogContext) {
                                            return AlertDialog(
                                              title:
                                                  const Text('대화 삭제'),
                                              content: const Text(
                                                '이 대화와 대화 내용을 삭제할까요?\n'
                                                '삭제한 뒤에는 되돌릴 수 없습니다.',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                    dialogContext,
                                                    false,
                                                  ),
                                                  child:
                                                      const Text('취소'),
                                                ),
                                                FilledButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                    dialogContext,
                                                    true,
                                                  ),
                                                  child:
                                                      const Text('삭제'),
                                                ),
                                              ],
                                            );
                                          },
                                        );

                                        if (ok != true) return;

                                        await LongTermAiService.instance
                                            .deleteConversation(
                                          conversationId: id,
                                        );

                                        if (_conversationId == id &&
                                            mounted) {
                                          setState(() {
                                            _conversationId = null;
                                            _messages = const [];
                                          });
                                        }

                                        await _loadConversationHistory();

                                        if (sheetContext.mounted) {
                                          Navigator.pop(sheetContext);
                                        }
                                      },
                                    ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  String _makeConversationTitle(String text) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= 28) return clean;
    return '${clean.substring(0, 28)}…';
  }

  String _dateLabel(dynamic value) {
    if (value == null) return '';
    final date = DateTime.tryParse(value.toString())?.toLocal();
    if (date == null) return '';

    String two(int n) => n.toString().padLeft(2, '0');

    return '${date.year}.${two(date.month)}.${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 6),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '리포트 기반 AI 대화',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: '최근 대화',
                onPressed:
                    _loadingHistory ? null : _showRecentChats,
                icon: const Icon(Icons.history),
              ),
              IconButton(
                tooltip: '새 대화',
                onPressed: _busy ? null : _newConversation,
                icon: const Icon(Icons.add_comment_outlined),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'AI는 내 리포트를 우선 참고하고, 외부 데이터는 관련 뉴스만 보강합니다.',
              style: TextStyle(color: Colors.white60),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loadingHistory
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              '새 대화를 시작하거나 최근 대화를 열어보세요.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _showRecentChats,
                              icon: const Icon(Icons.history),
                              label: const Text('최근 대화 보기'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final isUser = message.isUser;

                        return Align(
                          alignment: isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width *
                                      0.82,
                            ),
                            margin:
                                const EdgeInsets.only(bottom: 10),
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: isUser
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isUser ? '나' : 'AI',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isUser
                                            ? Colors.lightBlueAccent
                                            : Colors.white54,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(message.content),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: 'AI와 투자 아이디어를 대화하세요',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _busy ? null : _send,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NewsTab extends StatefulWidget {
  final int projectLocalId;

  const _NewsTab({required this.projectLocalId});

  @override
  State<_NewsTab> createState() => _NewsTabState();
}

class _NewsTabState extends State<_NewsTab> {
  bool _loading = true;
  bool _refreshing = false;
  bool _importantOnly = false;
  String _impactFilter = '전체';
  String? _error;
  String? _message;
  List<LongTermNewsItem> _news = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final news = await LongTermNewsService.instance.getNews(
        projectLocalId: widget.projectLocalId,
      );

      if (!mounted) return;
      setState(() {
        _news = news;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _refreshFromServer() async {
    if (_refreshing) return;

    setState(() {
      _refreshing = true;
      _error = null;
      _message = null;
    });

    try {
      final result = await LongTermNewsService.instance.refreshNews(
        projectLocalId: widget.projectLocalId,
      );

      await _load();

      if (!mounted) return;
      setState(() {
        _refreshing = false;
        _message =
            '뉴스 갱신 완료 · 신규 ${result['inserted_count'] ?? 0}건';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _refreshing = false;
        _error = e.toString();
      });
    }
  }

  String _dateText(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}.${two(local.month)}.${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  String _scoreText(double? value) {
    if (value == null) return '-';
    return '${(value * 100).round()}';
  }

  Color _importanceColor(double? value) {
    final score = value ?? 0;
    if (score >= 0.75) return Colors.redAccent;
    if (score >= 0.50) return Colors.orangeAccent;
    return Colors.blueGrey.shade200;
  }

  Widget _chip(String text, {Color? color}) {
    final c = color ?? Colors.white70;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: c,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _showDetail(LongTermNewsItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.86,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '뉴스 상세',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        item.displayTitle,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        [
                          if (item.sourceName?.trim().isNotEmpty == true)
                            item.sourceName!.trim(),
                          if (item.publishedAt != null)
                            _dateText(item.publishedAt),
                        ].join(' · '),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _chip(
                            '중요도 ${_scoreText(item.importanceScore)}',
                            color: _importanceColor(item.importanceScore),
                          ),
                          _chip(
                            '영향도 ${_scoreText(item.impactScore)}',
                            color: Colors.lightBlueAccent,
                          ),
                          _chip(
                            item.impactLabel,
                            color: item.impactLabel == '호재'
                                ? Colors.greenAccent
                                : item.impactLabel == '악재'
                                    ? Colors.redAccent
                                    : Colors.white60,
                          ),
                          ...item.relatedSymbols
                              .take(5)
                              .map((e) => _chip(e, color: Colors.amberAccent)),
                          ...item.relatedTopics
                              .take(6)
                              .map((e) => _chip(e)),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'AI 한국어 요약',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.displaySummary ?? 'AI 요약 대기중',
                        style: const TextStyle(height: 1.6),
                      ),
                      if (item.aiRelevanceReason?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 24),
                        const Text(
                          '왜 중요한 뉴스인가',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.aiRelevanceReason!.trim(),
                          style: const TextStyle(height: 1.6),
                        ),
                      ],
                      const SizedBox(height: 24),
                      const Text(
                        '원문 제목',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white60,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        style: const TextStyle(
                          color: Colors.white54,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<LongTermNewsItem> get _filteredNews {
    return _news.where((item) {
      if (_importantOnly && !item.isHighImportance) {
        return false;
      }

      if (_impactFilter != '전체' && item.impactLabel != _impactFilter) {
        return false;
      }

      return true;
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _refreshFromServer,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'AI 맞춤 뉴스',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: _refreshing ? null : _refreshFromServer,
                icon: _refreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(_refreshing ? '수집 중' : '뉴스 갱신'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '리포트·관심종목 기준으로 AI가 중요도와 투자 영향을 분석합니다.',
            style: TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('중요 뉴스만'),
                selected: _importantOnly,
                onSelected: (value) {
                  setState(() => _importantOnly = value);
                },
              ),
              ...['전체', '호재', '중립', '악재'].map(
                (value) => ChoiceChip(
                  label: Text(value),
                  selected: _impactFilter == value,
                  onSelected: (_) {
                    setState(() => _impactFilter = value);
                  },
                ),
              ),
            ],
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_message!),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: SelectableText(_error!),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_filteredNews.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('아직 수집된 뉴스가 없습니다.')),
              ),
            )
          else
            ..._filteredNews.map((item) {
              final color = _importanceColor(item.importanceScore);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _showDetail(item),
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (item.importanceScore != null)
                              _chip(
                                '중요 ${_scoreText(item.importanceScore)}',
                                color: color,
                              ),
                            _chip(
                              item.impactLabel,
                              color: item.impactLabel == '호재'
                                  ? Colors.greenAccent
                                  : item.impactLabel == '악재'
                                      ? Colors.redAccent
                                      : Colors.white60,
                            ),
                            ...item.relatedSymbols
                                .take(2)
                                .map((e) => _chip(e, color: Colors.amberAccent)),
                            ...item.relatedTopics.take(2).map(_chip),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          item.displayTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          [
                            if (item.sourceName?.trim().isNotEmpty == true)
                              item.sourceName!.trim(),
                            if (item.publishedAt != null)
                              _dateText(item.publishedAt),
                          ].join(' · '),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        if (item.displaySummary?.isNotEmpty == true) ...[
                          const SizedBox(height: 10),
                          Text(
                            item.displaySummary!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              height: 1.45,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _CandidatesTab extends StatefulWidget {
  final int projectLocalId;

  const _CandidatesTab({required this.projectLocalId});

  @override
  State<_CandidatesTab> createState() => _CandidatesTabState();
}

class _CandidatesTabState extends State<_CandidatesTab> {
  bool _loading = false;
  bool _initialLoading = true;
  String? _error;
  String? _marketView;
  String? _savedAt;
  List<Map<String, dynamic>> _candidates = const [];
  Set<String> _watchSymbols = <String>{};

  @override
  void initState() {
    super.initState();
    _loadLatest();
  }

  Future<void> _loadLatest() async {
    try {
      final result =
          await LongTermCandidateService.instance.getLatestCandidates(
        projectLocalId: widget.projectLocalId,
      );
      final watchSymbols =
          await LongTermWatchlistService.instance.getSymbols(
        projectLocalId: widget.projectLocalId,
      );

      if (!mounted) return;
      _watchSymbols = watchSymbols;

      if (result == null) {
        setState(() => _initialLoading = false);
        return;
      }

      final rawCandidates = result['candidates'];
      final candidates = rawCandidates is List
          ? rawCandidates
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(growable: false)
          : <Map<String, dynamic>>[];

      setState(() {
        _marketView = result['market_view']?.toString();
        _savedAt = result['created_at']?.toString();
        _candidates = candidates;
        _initialLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initialLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _generate() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result =
          await LongTermCandidateService.instance.generateCandidates(
        projectLocalId: widget.projectLocalId,
      );

      final rawCandidates = result['candidates'];
      final candidates = rawCandidates is List
          ? rawCandidates
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(growable: false)
          : <Map<String, dynamic>>[];

      if (!mounted) return;

      setState(() {
        _marketView = result['market_view']?.toString();
        _savedAt = result['created_at']?.toString();
        _candidates = candidates;
        _loading = false;
        _initialLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _toggleWatch(Map<String, dynamic> candidate) async {
    final symbol =
        candidate['symbol']?.toString().trim().toUpperCase() ?? '';
    if (symbol.isEmpty) return;

    try {
      if (_watchSymbols.contains(symbol)) {
        await LongTermWatchlistService.instance.remove(
          projectLocalId: widget.projectLocalId,
          symbol: symbol,
        );
        if (!mounted) return;
        setState(() => _watchSymbols.remove(symbol));
      } else {
        await LongTermWatchlistService.instance.add(
          projectLocalId: widget.projectLocalId,
          candidate: candidate,
        );
        if (!mounted) return;
        setState(() => _watchSymbols.add(symbol));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('관심종목 처리 실패: $e')),
      );
    }
  }

  String _verdictLabel(String? value) {
    switch ((value ?? '').toUpperCase()) {
      case 'STRONG_BUY_CANDIDATE':
        return '강력 후보';
      case 'WATCH':
        return '관찰';
      case 'HOLD_OFF':
        return '보류';
      default:
        return value ?? '';
    }
  }

  Color _verdictColor(String? value) {
    switch ((value ?? '').toUpperCase()) {
      case 'STRONG_BUY_CANDIDATE':
        return Colors.greenAccent;
      case 'WATCH':
        return Colors.orangeAccent;
      case 'HOLD_OFF':
        return Colors.redAccent;
      default:
        return Colors.white60;
    }
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  String _savedDateText() {
    final raw = _savedAt;
    if (raw == null || raw.isEmpty) return '';
    final date = DateTime.tryParse(raw)?.toLocal();
    if (date == null) return '';

    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}.${two(date.month)}.${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)} 저장';
  }

  Widget _bulletSection(String title, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                '• $item',
                style: const TextStyle(
                  height: 1.45,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '최종 종목 후보',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _loading ? null : _generate,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(_loading ? '분석 중' : '후보 생성'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          '종목·AI 점수·판정만 간단히 보고, 종목을 누르면 상세 근거를 확인합니다.',
          style: TextStyle(color: Colors.white60),
        ),
        if (_savedDateText().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            _savedDateText(),
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 16),

        if (_candidates.isNotEmpty) ...[
          Builder(
            builder: (context) {
              final top = _candidates.first;
              final topSymbol =
                  top['symbol']?.toString().trim().toUpperCase() ?? '-';
              final topScore = top['score'];
              final topScoreText = topScore is num
                  ? topScore.round().toString()
                  : topScore?.toString() ?? '-';
              final topVerdict = top['verdict']?.toString();

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.insights, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'AI 최종 판단',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '1순위 $topSymbol · $topScoreText점 · ${_verdictLabel(topVerdict)}',
                              style: const TextStyle(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
        ],

        if (_error != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(_error!),
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (_marketView?.trim().isNotEmpty == true) ...[
          Card(
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              title: const Text(
                'AI 종합 판단',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              subtitle: const Text(
                '눌러서 전체 시장 판단 보기',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              childrenPadding:
                  const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _marketView!.trim(),
                    style: const TextStyle(height: 1.55),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        if (!_loading && _candidates.isEmpty && _error == null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.star_outline, size: 42),
                  const SizedBox(height: 12),
                  const Text(
                    '아직 생성된 최종 후보가 없습니다.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '후보 생성 버튼을 누르면\n리포트·대화·뉴스를 함께 분석합니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _generate,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('최종 후보 생성'),
                  ),
                ],
              ),
            ),
          ),

        ..._candidates.map((candidate) {
          final symbol =
              candidate['symbol']?.toString().trim().toUpperCase() ?? '';
          final company =
              candidate['company_name']?.toString().trim() ?? '';
          final score = candidate['score'];
          final scoreText = score is num
              ? score.round().toString()
              : score?.toString() ?? '-';

          final verdict = candidate['verdict']?.toString();
          final verdictColor = _verdictColor(verdict);
          final isWatching = _watchSymbols.contains(symbol);

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
              childrenPadding:
                  const EdgeInsets.fromLTRB(16, 0, 16, 16),
              leading: Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '#${candidate['rank'] ?? '-'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                company.isEmpty ? symbol : '$symbol  $company',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Text(
                      'AI $scoreText점',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: verdictColor.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _verdictLabel(verdict),
                        style: TextStyle(
                          color: verdictColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isWatching) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.bookmark,
                        size: 15,
                        color: Colors.amberAccent,
                      ),
                    ],
                  ],
                ),
              ),
              children: [
                if (candidate['thesis']?.toString().trim().isNotEmpty ==
                    true) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'AI 투자 판단',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      candidate['thesis'].toString().trim(),
                      style: const TextStyle(
                        height: 1.55,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
                _bulletSection(
                  '핵심 근거',
                  _stringList(candidate['supporting_evidence']),
                ),
                _bulletSection(
                  '핵심 리스크',
                  _stringList(candidate['risks']),
                ),
                _bulletSection(
                  '계속 확인할 조건',
                  _stringList(candidate['watch_conditions']),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _toggleWatch(candidate),
                    icon: Icon(
                      isWatching
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                    ),
                    label: Text(
                      isWatching
                          ? '관심종목 등록됨 · 해제'
                          : '관심종목 등록',
                    ),
                  ),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 80),
      ],
    );
  }
}

class _WatchlistTab extends StatefulWidget {
  final int projectLocalId;

  const _WatchlistTab({required this.projectLocalId});

  @override
  State<_WatchlistTab> createState() => _WatchlistTabState();
}

class _WatchlistTabState extends State<_WatchlistTab> {
  bool _loading = true;
  bool _refreshingAnalysis = false;
  String? _error;
  String? _message;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await LongTermWatchlistService.instance.getItems(
        projectLocalId: widget.projectLocalId,
      );

      if (!mounted) return;

      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _refreshAnalysis() async {
    if (_refreshingAnalysis) return;

    setState(() {
      _refreshingAnalysis = true;
      _error = null;
      _message = null;
    });

    try {
      final result =
          await LongTermWatchlistService.instance.refreshTracking(
        projectLocalId: widget.projectLocalId,
      );

      await _load();

      if (!mounted) return;

      setState(() {
        _refreshingAnalysis = false;
        _message =
            '관심종목 재분석 완료 · ${result['updated_count'] ?? 0}개 갱신';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _refreshingAnalysis = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _showHistory(String symbol) async {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.78,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: LongTermWatchlistService.instance.getHistory(
                projectLocalId: widget.projectLocalId,
                symbol: symbol,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: SelectableText(
                      '분석 이력 불러오기 실패: ${snapshot.error}',
                    ),
                  );
                }

                final history = snapshot.data ?? const [];

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$symbol 분석 이력',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: history.isEmpty
                          ? const Center(
                              child: Text('저장된 분석 이력이 없습니다.'),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: history.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final row = history[index];
                                final score = row['score'];
                                final scoreText = score is num
                                    ? score.round().toString()
                                    : score?.toString() ?? '-';
                                final date =
                                    _analysisDate(row['analyzed_at']);
                                final reason = row['change_reason']
                                        ?.toString()
                                        .trim() ??
                                    '';
                                final verdict =
                                    row['verdict']?.toString();
                                final color =
                                    _verdictColor(verdict);

                                return Card(
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              '$scoreText점',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight:
                                                    FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            if ((verdict ?? '')
                                                .isNotEmpty)
                                              Container(
                                                padding:
                                                    const EdgeInsets
                                                        .symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration:
                                                    BoxDecoration(
                                                  color: color
                                                      .withOpacity(0.15),
                                                  borderRadius:
                                                      BorderRadius
                                                          .circular(14),
                                                ),
                                                child: Text(
                                                  _verdictLabel(
                                                    verdict,
                                                  ),
                                                  style: TextStyle(
                                                    color: color,
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            const Spacer(),
                                            Text(
                                              date,
                                              style: const TextStyle(
                                                color: Colors.white38,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (reason.isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          Text(
                                            reason,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              height: 1.45,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _remove(String symbol) async {
    try {
      await LongTermWatchlistService.instance.remove(
        projectLocalId: widget.projectLocalId,
        symbol: symbol,
      );

      await _load();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('관심종목 해제 실패: $e')),
      );
    }
  }

  String _scoreChangeText(dynamic value) {
    final n = value is num ? value.toDouble() : double.tryParse('$value');
    if (n == null) return '';
    if (n > 0) return '+${n.round()}';
    if (n < 0) return '${n.round()}';
    return '0';
  }

  String _analysisDate(dynamic value) {
    if (value == null) return '';
    final date = DateTime.tryParse(value.toString())?.toLocal();
    if (date == null) return '';

    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}.${two(date.month)}.${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  String _verdictLabel(String? value) {
    switch ((value ?? '').toUpperCase()) {
      case 'STRONG_BUY_CANDIDATE':
        return '강력 후보';
      case 'WATCH':
        return '관찰';
      case 'HOLD_OFF':
        return '보류';
      default:
        return value ?? '';
    }
  }

  Color _verdictColor(String? value) {
    switch ((value ?? '').toUpperCase()) {
      case 'STRONG_BUY_CANDIDATE':
        return Colors.greenAccent;
      case 'WATCH':
        return Colors.orangeAccent;
      case 'HOLD_OFF':
        return Colors.redAccent;
      default:
        return Colors.white60;
    }
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return const [];

    return value
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  Widget _section(String title, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                '• $item',
                style: const TextStyle(
                  color: Colors.white70,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
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
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '관심종목',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed:
                    _refreshingAnalysis ? null : _refreshAnalysis,
                icon: _refreshingAnalysis
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  _refreshingAnalysis ? '분석 중' : 'AI 재분석',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '종목을 누르면 상세 분석 내용을 볼 수 있습니다.',
            style: TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 18),

          if (_message != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(_message!),
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (_error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(_error!),
              ),
            )
          else if (_items.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.bookmark_border, size: 42),
                    SizedBox(height: 12),
                    Text(
                      '등록된 관심종목이 없습니다.',
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      '최종 후보 탭에서 관심종목을 등록하세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._items.map((item) {
              final symbol = item['symbol']?.toString() ?? '';
              final companyName = item['company_name']?.toString() ?? '';
              final score = item['score'];
              final scoreText = score is num
                  ? score.round().toString()
                  : score?.toString() ?? '-';
              final verdict = item['verdict']?.toString();
              final verdictColor = _verdictColor(verdict);
              final changeText = _scoreChangeText(item['score_change']);
              final analyzedAt = _analysisDate(item['last_analyzed_at']);

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  childrenPadding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$symbol  $companyName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if ((verdict ?? '').isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: verdictColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            _verdictLabel(verdict),
                            style: TextStyle(
                              color: verdictColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          'AI 점수 $scoreText',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        if (changeText.isNotEmpty)
                          Text(
                            changeText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: (item['score_change'] is num
                                      ? item['score_change'] as num
                                      : num.tryParse(
                                            '${item['score_change']}',
                                          ) ??
                                          0) >
                                  0
                                  ? Colors.greenAccent
                                  : (item['score_change'] is num
                                          ? item['score_change'] as num
                                          : num.tryParse(
                                                '${item['score_change']}',
                                              ) ??
                                              0) <
                                      0
                                      ? Colors.redAccent
                                      : Colors.white54,
                            ),
                          ),
                        if (analyzedAt.isNotEmpty)
                          Text(
                            '마지막 분석 $analyzedAt',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  children: [
                    const Divider(height: 1),
                    if (item['thesis']?.toString().trim().isNotEmpty ==
                        true) ...[
                      const SizedBox(height: 14),
                      Text(
                        item['thesis'].toString().trim(),
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.55,
                        ),
                      ),
                    ],

                    if (item['change_reason']
                            ?.toString()
                            .trim()
                            .isNotEmpty ==
                        true) ...[
                      const SizedBox(height: 14),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '점수 변화 이유',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          item['change_reason'].toString().trim(),
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],

                    _section(
                      '핵심 근거',
                      _stringList(item['supporting_evidence']),
                    ),
                    _section(
                      '핵심 리스크',
                      _stringList(item['risks']),
                    ),
                    _section(
                      '계속 확인할 조건',
                      _stringList(item['watch_conditions']),
                    ),

                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: () => _showHistory(symbol),
                        icon: const Icon(Icons.history),
                        label: const Text('분석 이력 보기'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _remove(symbol),
                        icon:
                            const Icon(Icons.bookmark_remove_outlined),
                        label: const Text('관심종목 해제'),
                      ),
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
