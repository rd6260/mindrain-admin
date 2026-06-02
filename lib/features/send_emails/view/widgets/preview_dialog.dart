import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mindrain_admin/features/send_emails/bloc/send_emails_bloc.dart';
import 'package:mindrain_admin/features/send_emails/data/csv_parser.dart';

const _accent = Color(0xFF6366F1);
const _teal = Color(0xFF06B6D4);

void showPreviewDialog({
  required BuildContext context,
  required SendEmailsState state,
  required String subject,
  required String body,
  required String htmlBody,
}) {
  if (state.testRows.isEmpty) return;
  final row = state.testRows.first;

  final resolvedSubject =
      CsvParser.resolveTemplate(subject, row, state.defaultValues);
  final resolvedText =
      CsvParser.resolveTemplate(body, row, state.defaultValues);
  final resolvedHtml = htmlBody.isNotEmpty
      ? CsvParser.resolveTemplate(htmlBody, row, state.defaultValues)
      : '';

  final allHeaders = {...state.testHeaders, ...state.finalHeaders};
  final unresolved = state.detectedVars.where((v) {
    final inHeader = allHeaders.contains(v);
    final hasDefault = (state.defaultValues[v] ?? '').isNotEmpty;
    return !inHeader && !hasDefault;
  }).toList();

  showDialog<void>(
    context: context,
    builder: (ctx) => _PreviewDialog(
      subject: resolvedSubject,
      textBody: resolvedText,
      htmlBody: resolvedHtml,
      unresolved: unresolved,
    ),
  );
}

class _PreviewDialog extends StatefulWidget {
  const _PreviewDialog({
    required this.subject,
    required this.textBody,
    required this.htmlBody,
    required this.unresolved,
  });

  final String subject;
  final String textBody;
  final String htmlBody;
  final List<String> unresolved;

  @override
  State<_PreviewDialog> createState() => _PreviewDialogState();
}

class _PreviewDialogState extends State<_PreviewDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  bool get _hasHtml => widget.htmlBody.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _hasHtml ? 2 : 1, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: _hasHtml ? 640 : 540,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.preview_rounded, color: _accent, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Preview',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            if (widget.unresolved.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InlineWarning(
                'Unresolved variables: ${widget.unresolved.map((v) => '{{$v}}').join(', ')}',
              ),
            ],
            const SizedBox(height: 12),

            // Subject
            _Label('Subject'),
            const SizedBox(height: 4),
            Text(
              widget.subject,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const Divider(height: 20),

            // Tab bar (only shown when HTML body exists)
            if (_hasHtml) ...[
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE4E4EF)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TabBar(
                  controller: _tabCtrl,
                  labelColor: _accent,
                  unselectedLabelColor: const Color(0xFF9494A8),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: _accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.text_fields_rounded, size: 14),
                          SizedBox(width: 6),
                          Text('Plain Text',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.web_rounded, size: 14),
                          SizedBox(width: 6),
                          Text('HTML Preview',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Body content
            Expanded(
              child: _hasHtml
                  ? TabBarView(
                      controller: _tabCtrl,
                      children: [
                        _TextBodyView(text: widget.textBody),
                        _HtmlBodyView(html: widget.htmlBody),
                      ],
                    )
                  : _TextBodyView(text: widget.textBody),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Text body (plain text tab) ────────────────────────────────────────────────

class _TextBodyView extends StatelessWidget {
  const _TextBodyView({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SelectableText(
        text,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          height: 1.6,
        ),
      ),
    );
  }
}

// ── HTML body (External Browser Launcher + Source View) ───────────────────────

class _HtmlBodyView extends StatelessWidget {
  const _HtmlBodyView({required this.html});
  final String html;

  Future<void> _launchBrowser() async {
    try {
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/email_preview.html');
      await tempFile.writeAsString(html);
      final uri = Uri.file(tempFile.path);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      final uri = Uri.file('${Directory.systemTemp.path}/email_preview.html');
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Launch box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _teal.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _teal.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _teal.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.open_in_browser_rounded,
                  color: _teal,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Live Browser Preview',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Open the fully rendered HTML email template in your system browser.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _launchBrowser,
                icon: const Icon(Icons.launch_rounded, size: 13),
                label: const Text('Open Browser'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Source code header
        const Row(
          children: [
            Icon(Icons.code_rounded, size: 14, color: Color(0xFF64748B)),
            SizedBox(width: 6),
            Text(
              'HTML Source Code',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Source code view
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFFF8FAFC),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                html,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.5,
                  color: Color(0xFF334155),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 11,
          color: Color(0xFF6B7280),
          letterSpacing: 0.5,
        ),
      );
}

class _InlineWarning extends StatelessWidget {
  const _InlineWarning(this.msg);
  final String msg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 15, color: Colors.orange.shade700),
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
  }
}
