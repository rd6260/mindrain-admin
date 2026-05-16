import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mindrain_admin/services/postmark.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmailManagementPage extends StatefulWidget {
  const EmailManagementPage({super.key});

  @override
  State<EmailManagementPage> createState() => _EmailManagementPageState();
}

class _EmailManagementPageState extends State<EmailManagementPage> {
  // ── CSV state ────────────────────────────────────────────────────────────
  List<String> _testHeaders = [], _finalHeaders = [];
  List<Map<String, String>> _testRows = [], _finalRows = [];
  String? _emailCol;
  String? _csvWarning;

  // ── Attachments ──────────────────────────────────────────────────────────
  List<PlatformFile> _attachments = [];

  // ── Composer ─────────────────────────────────────────────────────────────
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _bodyFocusNode = FocusNode();
  Set<String> _detectedVars = {};
  final Map<String, TextEditingController> _defaultCtrls = {};

  // ── Autocomplete overlay ─────────────────────────────────────────────────
  OverlayEntry? _overlayEntry;
  final LayerLink _bodyLayerLink = LayerLink();
  List<String> _suggestions = [];
  int _selectedIndex = 0;

  // ── Run state ────────────────────────────────────────────────────────────
  bool _running = false, _cancelled = false;
  int _total = 0, _sent = 0, _ok = 0, _fail = 0;
  String _runLog = '';
  final _progressNotifier = ValueNotifier<int>(0);

  // ── Theme ────────────────────────────────────────────────────────────────
  static const _accent = Color(0xFF6366F1);
  static const _teal = Color(0xFF06B6D4);
  static const _bg = Color(0xFFF4F5F7);

  // ────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _bodyCtrl.addListener(_onBodyChanged);
    _bodyFocusNode.addListener(() {
      if (!_bodyFocusNode.hasFocus) _hideOverlay();
    });
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    _bodyFocusNode.dispose();
    for (final c in _defaultCtrls.values) c.dispose();
    _progressNotifier.dispose();
    _hideOverlay();
    super.dispose();
  }

  // ── Variable detection + autocomplete trigger ────────────────────────────
  void _onBodyChanged() {
    _detectVars();
    _checkAutocomplete();
  }

  void _detectVars() {
    final found = RegExp(
      r'\{\{(\w+)\}\}',
    ).allMatches(_bodyCtrl.text).map((m) => m.group(1)!).toSet();

    if (found == _detectedVars) return;

    for (final v in found) {
      _defaultCtrls.putIfAbsent(v, () => TextEditingController());
    }
    for (final v in _detectedVars.difference(found)) {
      _defaultCtrls[v]?.dispose();
      _defaultCtrls.remove(v);
    }
    setState(() => _detectedVars = found);
  }

  // ── Autocomplete logic ───────────────────────────────────────────────────
  void _checkAutocomplete() {
    final text = _bodyCtrl.text;
    final cursor = _bodyCtrl.selection.baseOffset;
    if (cursor < 0 || cursor > text.length) {
      _hideOverlay();
      return;
    }

    final beforeCursor = text.substring(0, cursor);
    final openIdx = beforeCursor.lastIndexOf('{{');
    if (openIdx == -1) {
      _hideOverlay();
      return;
    }

    final afterOpen = beforeCursor.substring(openIdx + 2);
    if (afterOpen.contains('}}')) {
      _hideOverlay();
      return;
    }

    final typed = afterOpen.toLowerCase();

    final allHeaders = {..._testHeaders, ..._finalHeaders}.toList();
    if (allHeaders.isEmpty) {
      _hideOverlay();
      return;
    }

    final matches = allHeaders
        .where((h) => h.toLowerCase().startsWith(typed) && h.isNotEmpty)
        .toList();

    if (matches.isEmpty) {
      _hideOverlay();
      return;
    }

    if (_suggestions.join() != matches.join()) {
      _selectedIndex = 0;
    }
    _suggestions = matches;
    _showOverlay();
  }

  void _showOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
      return;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 280,
        child: CompositedTransformFollower(
          link: _bodyLayerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 52),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(10),
            color: Colors.white,
            child: _AutocompleteMenu(
              suggestions: _suggestions,
              selectedIndex: _selectedIndex,
              onSelect: (col) {
                _insertSuggestion(col);
              },
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _insertSuggestion(String column) {
    final text = _bodyCtrl.text;
    final cursor = _bodyCtrl.selection.baseOffset;
    if (cursor < 0) return;

    final beforeCursor = text.substring(0, cursor);
    final openIdx = beforeCursor.lastIndexOf('{{');
    if (openIdx == -1) return;

    final before = text.substring(0, openIdx);
    final after = text.substring(cursor);
    final replacement = '{{$column}}';
    final newText = '$before$replacement$after';
    final newCursor = before.length + replacement.length;

    _bodyCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );

    _hideOverlay();
    _bodyFocusNode.requestFocus();
  }

  void _selectNext() {
    if (_suggestions.isEmpty) return;
    _selectedIndex = (_selectedIndex + 1) % _suggestions.length;
    _overlayEntry?.markNeedsBuild();
  }

  void _confirmSelected() {
    if (_suggestions.isEmpty || _overlayEntry == null) return;
    _insertSuggestion(_suggestions[_selectedIndex]);
  }

  // Resolve {{var}} placeholders for a single row
  String _resolve(String template, Map<String, String> row) {
    return template.replaceAllMapped(RegExp(r'\{\{(\w+)\}\}'), (m) {
      final key = m.group(1)!;
      final cellValue = row[key];
      if (cellValue != null && cellValue.isNotEmpty) return cellValue;
      final def = _defaultCtrls[key]?.text ?? '';
      return def.isNotEmpty ? def : '{{$key}}';
    });
  }

  // ── Email column detection ───────────────────────────────────────────────
  String? _findEmailCol(List<String> headers) {
    const candidates = {'email', 'emails', 'e-mail', 'e-mails'};
    for (final h in headers) {
      if (candidates.contains(h.toLowerCase())) return h;
    }
    return null;
  }

  // ── CSV parsing ──────────────────────────────────────────────────────────
  Future<(List<String>, List<Map<String, String>>)?> _parseCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null) return null;

    final content = utf8.decode(result.files.first.bytes!);
    final rows = const CsvToListConverter(eol: '\n').convert(content);
    if (rows.isEmpty) return null;

    final headers = rows.first.map((e) => e.toString().trim()).toList();
    final data = rows.skip(1).map((r) {
      final map = <String, String>{};
      for (int i = 0; i < headers.length; i++) {
        map[headers[i]] = i < r.length ? r[i].toString().trim() : '';
      }
      return map;
    }).toList();

    return (headers, data);
  }

  // ── Warning checker ──────────────────────────────────────────────────────
  void _checkWarnings() {
    final warnings = <String>[];

    if (_testHeaders.isNotEmpty &&
        _finalHeaders.isNotEmpty &&
        _testHeaders.join(',') != _finalHeaders.join(',')) {
      warnings.add('Test and Final CSV headers do not match!');
    }

    final allHeaders = _testHeaders.isNotEmpty ? _testHeaders : _finalHeaders;
    _emailCol = allHeaders.isNotEmpty ? _findEmailCol(allHeaders) : null;
    if (allHeaders.isNotEmpty && _emailCol == null) {
      warnings.add(
        'No email column found. Add a column named "email", "emails", etc.',
      );
    }

    setState(
      () => _csvWarning = warnings.isEmpty ? null : warnings.join(' | '),
    );
  }

  // ── File pickers ─────────────────────────────────────────────────────────
  Future<void> _pickTest() async {
    final r = await _parseCsv();
    if (r == null) return;
    setState(() {
      _testHeaders = r.$1;
      _testRows = r.$2;
    });
    _checkWarnings();
  }

  Future<void> _pickFinal() async {
    final r = await _parseCsv();
    if (r == null) return;
    setState(() {
      _finalHeaders = r.$1;
      _finalRows = r.$2;
    });
    _checkWarnings();
  }

  Future<void> _pickAttachments() async {
    final r = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (r == null) return;
    setState(() => _attachments.addAll(r.files));
  }

  // ── Send runner ──────────────────────────────────────────────────────────
  Future<void> _run(
    List<Map<String, String>> rows, {
    required bool isTest,
  }) async {
    if (_emailCol == null) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('postmark_token') ?? '';

    if (token.isEmpty) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Missing API Token'),
            content: const Text('Please configure your Postmark Server API Token in the Settings page before sending emails.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    if (!isTest) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm Final Run'),
          content: Text('Send to ${rows.length} recipients?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Send'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    // Reset state before showing dialog
    setState(() {
      _running = true;
      _cancelled = false;
      _total = rows.length;
      _sent = 0;
      _ok = 0;
      _fail = 0;
      _runLog = '';
    });
    // Notify AFTER setState so dialog opens with fresh values
    _progressNotifier.value++;

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _ProgressDialog(
          state: this,
          onCancel: () {
            setState(() => _cancelled = true);
            _progressNotifier.value++;
          },
        ),
      );
    }

    final attachments = _attachments
        .map(
          (f) => PostmarkAttachment(
            name: f.name,
            bytes: f.bytes!,
            contentType: 'application/octet-stream',
          ),
        )
        .toList();

    for (final row in rows) {
      if (_cancelled) break;

      final to = row[_emailCol!] ?? '';
      if (to.isEmpty) {
        // ── FIX: use setState + notifier for every counter update ──────────
        setState(() {
          _sent++;
          _fail++;
        });
        _progressNotifier.value++;
        continue;
      }

      final res = await PostmarkService.sendEmail(
        token: token,
        to: to,
        subject: _resolve(_subjectCtrl.text, row),
        textBody: _resolve(_bodyCtrl.text, row),
        attachments: attachments,
      );

      // ── FIX: setState first, then bump notifier so dialog rebuilds ───────
      setState(() {
        _sent++;
        if (res.success) {
          _ok++;
        } else {
          _fail++;
          _runLog += '[$to] ${res.errorMessage}\n';
        }
      });
      _progressNotifier.value++;
    }

    setState(() => _running = false);
    _progressNotifier.value++;
  }

  // ── Preview dialog ────────────────────────────────────────────────────────
  void _showPreview() {
    if (_testRows.isEmpty) return;
    final row = _testRows.first;
    final resolved = _resolve(_bodyCtrl.text, row);

    final allHeaders = {..._testHeaders, ..._finalHeaders};
    final unresolved = _detectedVars.where((v) {
      final inHeader = allHeaders.contains(v);
      final hasDefault = (_defaultCtrls[v]?.text ?? '').isNotEmpty;
      return !inHeader && !hasDefault;
    }).toList();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 540),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.preview_rounded, color: _accent, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Preview',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              if (unresolved.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildInlineWarning(
                  'Unresolved variables: ${unresolved.map((v) => '{{$v}}').join(', ')}',
                ),
              ],
              const SizedBox(height: 14),
              const Text(
                'Subject',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: Color(0xFF6B7280),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _resolve(_subjectCtrl.text, row),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Divider(height: 20),
              const Text(
                'Body',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: Color(0xFF6B7280),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    resolved,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_csvWarning != null) _buildWarning(_csvWarning!),

                      _buildSection(
                        'CSV Files',
                        Icons.table_chart_rounded,
                        _buildCsvRow(),
                      ),
                      const SizedBox(height: 16),

                      _buildSection(
                        'Attachments',
                        Icons.attach_file_rounded,
                        _buildAttachments(),
                      ),
                      const SizedBox(height: 16),

                      _buildSection(
                        'Compose Email',
                        Icons.edit_rounded,
                        _buildComposer(),
                      ),

                      if (_detectedVars.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildSection(
                          'Default Values',
                          Icons.tune_rounded,
                          _buildDefaults(),
                        ),
                      ],

                      const SizedBox(height: 16),
                      _buildRunButtons(),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar() => Container(
    height: 60,
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: Color(0xFFE4E4EF))),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: const Row(
      children: [
        Icon(Icons.mail_rounded, color: _accent, size: 22),
        SizedBox(width: 12),
        Text(
          'Email Management',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
          ),
        ),
      ],
    ),
  );

  // ── Card section wrapper ──────────────────────────────────────────────────
  Widget _buildSection(String title, IconData icon, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: _accent),
            const SizedBox(width: 7),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE4E4EF)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: content,
        ),
      ],
    );
  }

  // ── Warning banner ────────────────────────────────────────────────────────
  Widget _buildWarning(String msg) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.amber.shade50,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.amber.shade300),
    ),
    child: Row(
      children: [
        Icon(
          Icons.warning_amber_rounded,
          color: Colors.orange.shade700,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            msg,
            style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
          ),
        ),
      ],
    ),
  );

  Widget _buildInlineWarning(String msg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.amber.shade50,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.amber.shade300),
    ),
    child: Row(
      children: [
        Icon(
          Icons.warning_amber_rounded,
          size: 15,
          color: Colors.orange.shade700,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            msg,
            style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
          ),
        ),
      ],
    ),
  );

  // ── CSV row ───────────────────────────────────────────────────────────────
  Widget _buildCsvRow() => Row(
    children: [
      Expanded(
        child: _csvCard(
          label: 'Test CSV',
          headers: _testHeaders,
          rowCount: _testRows.length,
          onPick: _pickTest,
          color: _teal,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _csvCard(
          label: 'Final CSV',
          headers: _finalHeaders,
          rowCount: _finalRows.length,
          onPick: _pickFinal,
          color: _accent,
        ),
      ),
    ],
  );

  Widget _csvCard({
    required String label,
    required List<String> headers,
    required int rowCount,
    required VoidCallback onPick,
    required Color color,
  }) {
    final loaded = headers.isNotEmpty;
    return MouseRegion(
      cursor: _running
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _running ? null : onPick,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: loaded
                ? color.withValues(alpha: 0.05)
                : const Color(0xFFFAFAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: loaded
                  ? color.withValues(alpha: 0.35)
                  : const Color(0xFFE4E4EF),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      loaded
                          ? Icons.check_circle_rounded
                          : Icons.upload_file_rounded,
                      color: color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          loaded
                              ? '$rowCount rows · ${headers.length} cols'
                                    ' · email: ${_emailCol ?? "not found"}'
                              : 'Click to select CSV file',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.black.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (loaded)
                    Icon(
                      Icons.edit_rounded,
                      size: 14,
                      color: color.withValues(alpha: 0.6),
                    ),
                ],
              ),

              if (loaded) ...[
                const SizedBox(height: 10),
                const Divider(height: 1, thickness: 1),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        'Columns',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.black.withValues(alpha: 0.4),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: headers.map((h) {
                          final isEmail =
                              h.toLowerCase() ==
                              (_emailCol?.toLowerCase() ?? '');
                          return _ColumnChip(
                            label: h,
                            color: color,
                            isEmail: isEmail,
                            onTap: () => _insertColumnIntoBody(h),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _insertColumnIntoBody(String column) {
    _hideOverlay();
    final text = _bodyCtrl.text;
    final cursor = _bodyCtrl.selection.baseOffset.clamp(0, text.length);
    final before = text.substring(0, cursor);
    final after = text.substring(cursor);

    if (before.endsWith('{{')) {
      final replacement = '$column}}';
      _bodyCtrl.value = TextEditingValue(
        text: '$before$replacement$after',
        selection: TextSelection.collapsed(
          offset: before.length + replacement.length,
        ),
      );
    } else {
      final replacement = '{{$column}}';
      _bodyCtrl.value = TextEditingValue(
        text: '$before$replacement$after',
        selection: TextSelection.collapsed(
          offset: before.length + replacement.length,
        ),
      );
    }
    _bodyFocusNode.requestFocus();
  }

  // ── Attachments ───────────────────────────────────────────────────────────
  Widget _buildAttachments() => Row(
    children: [
      Expanded(
        child: _attachments.isEmpty
            ? Text(
                'No attachments added',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black.withValues(alpha: 0.4),
                ),
              )
            : Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _attachments
                    .map(
                      (f) => Chip(
                        label: Text(
                          f.name,
                          style: const TextStyle(fontSize: 12),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () => setState(() => _attachments.remove(f)),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
      ),
      const SizedBox(width: 12),
      OutlinedButton.icon(
        onPressed: _running ? null : _pickAttachments,
        icon: const Icon(Icons.attach_file_rounded, size: 16),
        label: const Text('Add Files'),
        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
      ),
    ],
  );

  // ── Composer ──────────────────────────────────────────────────────────────
  Widget _buildComposer() {
    final allHeaders = {..._testHeaders, ..._finalHeaders};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _subjectCtrl,
          enabled: !_running,
          decoration: const InputDecoration(
            labelText: 'Subject',
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 12),

        CompositedTransformTarget(
          link: _bodyLayerLink,
          child: Focus(
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;

              if (event.logicalKey == LogicalKeyboardKey.escape) {
                _hideOverlay();
                return KeyEventResult.handled;
              }
              if (_overlayEntry != null) {
                if (event.logicalKey == LogicalKeyboardKey.tab) {
                  _selectNext();
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.enter) {
                  _confirmSelected();
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              controller: _bodyCtrl,
              focusNode: _bodyFocusNode,
              enabled: !_running,
              maxLines: 14,
              minLines: 8,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.55,
              ),
              decoration: InputDecoration(
                labelText: 'Email Body  —  use {{column_name}} for variables',
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.all(14),
                hintText:
                    'Dear {{name}},\n\nYour registration for {{event}} is confirmed.\n...',
                hintStyle: TextStyle(
                  color: Colors.black.withValues(alpha: 0.25),
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),

        if (_detectedVars.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Variables:',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ),
              ..._detectedVars.map((v) {
                final exists = allHeaders.contains(v);
                return Chip(
                  label: Text(
                    '{{$v}}',
                    style: TextStyle(
                      fontSize: 11,
                      color: exists
                          ? Colors.green.shade800
                          : Colors.red.shade700,
                    ),
                  ),
                  backgroundColor: exists
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  side: BorderSide(
                    color: exists ? Colors.green.shade200 : Colors.red.shade200,
                  ),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }),
            ],
          ),
        ],

        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: _testRows.isEmpty ? null : _showPreview,
              icon: const Icon(Icons.preview_rounded, size: 16),
              label: const Text('Preview with test data'),
            ),
          ],
        ),
      ],
    );
  }

  // ── Default values ────────────────────────────────────────────────────────
  Widget _buildDefaults() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Fallback used when a row has no value for that variable.',
        style: TextStyle(
          fontSize: 12,
          color: Colors.black.withValues(alpha: 0.45),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 16,
        runSpacing: 12,
        children: _detectedVars
            .map(
              (v) => SizedBox(
                width: 220,
                child: TextField(
                  controller: _defaultCtrls[v],
                  decoration: InputDecoration(
                    labelText: '{{$v}}',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    ],
  );

  // ── Run buttons ───────────────────────────────────────────────────────────
  Widget _buildRunButtons() => Row(
    children: [
      Expanded(
        child: ElevatedButton.icon(
          onPressed: (_running || _testRows.isEmpty || _emailCol == null)
              ? null
              : () => _run(_testRows, isTest: true),
          icon: const Icon(Icons.science_rounded, size: 18),
          label: const Text(
            'Test Run',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _teal,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _teal.withValues(alpha: 0.4),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: ElevatedButton.icon(
          onPressed: (_running || _finalRows.isEmpty || _emailCol == null)
              ? null
              : () => _run(_finalRows, isTest: false),
          icon: const Icon(Icons.send_rounded, size: 18),
          label: const Text(
            'Final Run',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _accent.withValues(alpha: 0.4),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
        ),
      ),
      if (_running) ...[
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: () => setState(() => _cancelled = true),
          icon: const Icon(Icons.stop_rounded, size: 18),
          label: const Text('Cancel'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade400,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
        ),
      ],
    ],
  );
}

// ── Column chip widget ────────────────────────────────────────────────────────
class _ColumnChip extends StatefulWidget {
  const _ColumnChip({
    required this.label,
    required this.color,
    required this.isEmail,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool isEmail;
  final VoidCallback onTap;

  @override
  State<_ColumnChip> createState() => _ColumnChipState();
}

class _ColumnChipState extends State<_ColumnChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = _hovered
        ? widget.color.withValues(alpha: 0.15)
        : widget.color.withValues(alpha: 0.07);
    final border = _hovered
        ? widget.color.withValues(alpha: 0.5)
        : widget.color.withValues(alpha: 0.25);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isEmail) ...[
                Icon(
                  Icons.alternate_email_rounded,
                  size: 10,
                  color: widget.color,
                ),
                const SizedBox(width: 3),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: widget.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Autocomplete menu widget ──────────────────────────────────────────────────
class _AutocompleteMenu extends StatelessWidget {
  const _AutocompleteMenu({
    required this.suggestions,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<String> suggestions;
  final int selectedIndex;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            color: const Color(0xFFF4F5F7),
            child: Row(
              children: [
                const Icon(
                  Icons.data_array_rounded,
                  size: 12,
                  color: Color(0xFF6366F1),
                ),
                const SizedBox(width: 6),
                Text(
                  'Available columns',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withValues(alpha: 0.45),
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                Text(
                  '↹ to cycle · ↵ to insert',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.black.withValues(alpha: 0.3),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE4E4EF)),
          ...suggestions.asMap().entries.map(
            (e) => _AutocompleteItem(
              column: e.value,
              isSelected: e.key == selectedIndex,
              onPointerDown: () => onSelect(e.value),
            ),
          ),
        ],
      ),
    );
  }
}

class _AutocompleteItem extends StatefulWidget {
  const _AutocompleteItem({
    required this.column,
    required this.isSelected,
    required this.onPointerDown,
  });
  final String column;
  final bool isSelected;
  final VoidCallback onPointerDown;

  @override
  State<_AutocompleteItem> createState() => _AutocompleteItemState();
}

class _AutocompleteItemState extends State<_AutocompleteItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = widget.isSelected || _hovered;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Listener(
        onPointerDown: (_) => widget.onPointerDown(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? const Color(0xFF6366F1).withValues(alpha: 0.10)
                : _hovered
                ? const Color(0xFF6366F1).withValues(alpha: 0.05)
                : Colors.white,
            border: widget.isSelected
                ? const Border(
                    left: BorderSide(color: Color(0xFF6366F1), width: 3),
                  )
                : const Border(
                    left: BorderSide(color: Colors.transparent, width: 3),
                  ),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: highlighted
                      ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                      : const Color(0xFF6366F1).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: Text(
                    '{ }',
                    style: TextStyle(
                      fontSize: 8,
                      fontFamily: 'monospace',
                      color: Color(0xFF6366F1),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                widget.column,
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                  color: widget.isSelected
                      ? const Color(0xFF6366F1)
                      : const Color(0xFF1A1A2E),
                  fontWeight: widget.isSelected
                      ? FontWeight.w600
                      : FontWeight.w500,
                ),
              ),
              const Spacer(),
              AnimatedOpacity(
                opacity: highlighted ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 80),
                child: Text(
                  '{{${widget.column}}}',
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: const Color(0xFF6366F1).withValues(alpha: 0.55),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Progress dialog ───────────────────────────────────────────────────────────
class _ProgressDialog extends StatelessWidget {
  const _ProgressDialog({required this.state, required this.onCancel});
  final _EmailManagementPageState state;
  final VoidCallback onCancel;

  static const _accent = Color(0xFF6366F1);

  @override
  Widget build(BuildContext context) {
    // ── FIX: read ALL live values inside ListenableBuilder, not before it ──
    return ListenableBuilder(
      listenable: state._progressNotifier,
      builder: (_, __) {
        final total = state._total;
        final sent = state._sent;
        final ok = state._ok;
        final fail = state._fail;
        final log = state._runLog;
        final running = state._running;
        final cancelled = state._cancelled;

        final pct = total == 0 ? 0.0 : sent / total;
        final statusLabel = running
            ? (cancelled ? 'Cancelling…' : 'Sending…')
            : (cancelled ? 'Cancelled' : 'Done ✓');

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Row(
                  children: [
                    const Icon(Icons.send_rounded, color: _accent, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      running ? 'Sending Emails…' : statusLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Percentage + bar
                Row(
                  children: [
                    Text(
                      '${(pct * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 10,
                          backgroundColor: const Color(0xFFE4E4EF),
                          valueColor: AlwaysStoppedAnimation(
                            !running ? Colors.green.shade400 : _accent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 16),

                // Stats row
                Row(
                  children: [
                    Text(
                      '$sent / $total sent',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 14,
                      color: Colors.green.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$ok ok',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green.shade600,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Icon(
                      Icons.cancel_outlined,
                      size: 14,
                      color: Colors.red.shade400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$fail failed',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.red.shade500,
                      ),
                    ),
                  ],
                ),

                // Error log
                if (log.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 120),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        log,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: Colors.red.shade800,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: running
                      ? ElevatedButton.icon(
                          onPressed: onCancel,
                          icon: const Icon(Icons.stop_rounded, size: 16),
                          label: const Text('Cancel'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade400,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                        )
                      : ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: const Text('Close'),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
