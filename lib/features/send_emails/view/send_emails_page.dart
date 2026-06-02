import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mindrain_admin/features/send_emails/bloc/send_emails_bloc.dart';
import 'package:mindrain_admin/features/send_emails/data/csv_parser.dart';
import 'package:mindrain_admin/features/send_emails/view/widgets/attachments_section.dart';
import 'package:mindrain_admin/features/send_emails/view/widgets/composer_section.dart';
import 'package:mindrain_admin/features/send_emails/view/widgets/csv_section.dart';
import 'package:mindrain_admin/features/send_emails/view/widgets/default_values_section.dart';
import 'package:mindrain_admin/features/send_emails/view/widgets/preview_dialog.dart';
import 'package:mindrain_admin/features/send_emails/view/widgets/progress_dialog.dart';
import 'package:mindrain_admin/features/send_emails/view/widgets/run_buttons.dart';

const _accent = Color(0xFF6366F1);
const _bg = Color(0xFFF4F5F7);

/// Public entry point — provides the [SendEmailsBloc] and mounts the view.
class SendEmailsPage extends StatelessWidget {
  const SendEmailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SendEmailsBloc(),
      child: const _SendEmailsView(),
    );
  }
}

// ── View (owns ephemeral UI state) ────────────────────────────────────────────

class _SendEmailsView extends StatefulWidget {
  const _SendEmailsView();

  @override
  State<_SendEmailsView> createState() => _SendEmailsViewState();
}

class _SendEmailsViewState extends State<_SendEmailsView> {
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _htmlBodyCtrl = TextEditingController();
  void Function(String)? _columnInsertFn;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    _htmlBodyCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _onColumnInsert(String column) {
    _columnInsertFn?.call(column);
  }

  void _onPreview() {
    final state = context.read<SendEmailsBloc>().state;
    if (state.testRows.isEmpty) return;
    final row = state.testRows.first;

    if (state.isHtmlMode) {
      final resolvedHtml = _htmlBodyCtrl.text.isNotEmpty
          ? CsvParser.resolveTemplate(_htmlBodyCtrl.text, row, state.defaultValues)
          : '';
      _launchBrowser(resolvedHtml);
    } else {
      showPreviewDialog(
        context: context,
        state: state,
        subject: _subjectCtrl.text,
        body: _bodyCtrl.text,
        htmlBody: '',
      );
    }
  }

  Future<void> _launchBrowser(String htmlContent) async {
    try {
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/email_preview.html');
      await tempFile.writeAsString(htmlContent);
      final uri = Uri.file(tempFile.path);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      final uri = Uri.file('${Directory.systemTemp.path}/email_preview.html');
      await launchUrl(uri);
    }
  }

  Future<void> _onTestRun() async {
    context.read<SendEmailsBloc>().add(
          TestRunRequested(
            subject: _subjectCtrl.text,
            body: _bodyCtrl.text,
            htmlBody: _htmlBodyCtrl.text.isNotEmpty ? _htmlBodyCtrl.text : null,
          ),
        );
    _showProgressDialog();
  }

  Future<void> _onFinalRun() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final count =
            context.read<SendEmailsBloc>().state.finalRows.length;
        return AlertDialog(
          title: const Text('Confirm Final Run'),
          content: Text('Send to $count recipients?'),
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
        );
      },
    );
    if (ok != true) return;
    if (!mounted) return;

    context.read<SendEmailsBloc>().add(
          FinalRunRequested(
            subject: _subjectCtrl.text,
            body: _bodyCtrl.text,
            htmlBody: _htmlBodyCtrl.text.isNotEmpty ? _htmlBodyCtrl.text : null,
          ),
        );
    _showProgressDialog();
  }

  void _showProgressDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: context.read<SendEmailsBloc>(),
        child: const ProgressDialog(),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocListener<SendEmailsBloc, SendEmailsState>(
      listenWhen: (p, c) => p.csvWarning != c.csvWarning,
      listener: (context, state) {
        // Show missing-token dialog when bloc signals it
        if (state.csvWarning == '__missing_token__') {
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Missing API Token'),
              content: const Text(
                'Please configure your Postmark Server API Token in the '
                'Settings page before sending emails.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      },
      child: Container(
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
                        _buildSection(
                          'CSV Files',
                          Icons.table_chart_rounded,
                          CsvSection(onColumnInsert: _onColumnInsert),
                        ),
                        const SizedBox(height: 16),

                        _buildSection(
                          'Compose Email',
                          Icons.edit_rounded,
                          ComposerSection(
                            subjectCtrl: _subjectCtrl,
                            bodyCtrl: _bodyCtrl,
                            htmlBodyCtrl: _htmlBodyCtrl,
                            onPreview: _onPreview,
                            onSuggestionInserted: (_, _) {},
                            onRegisterInsertFn: (fn) {
                              _columnInsertFn = fn;
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        _buildSection(
                          'Attachments',
                          Icons.attach_file_rounded,
                          const AttachmentsSection(),
                        ),

                        BlocBuilder<SendEmailsBloc, SendEmailsState>(
                          buildWhen: (p, c) =>
                              p.detectedVars != c.detectedVars,
                          builder: (context, state) {
                            if (state.detectedVars.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Column(
                              children: [
                                const SizedBox(height: 16),
                                _buildSection(
                                  'Default Values',
                                  Icons.tune_rounded,
                                  const DefaultValuesSection(),
                                ),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 16),
                        RunButtons(
                          onTestRun: _onTestRun,
                          onFinalRun: _onFinalRun,
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
}


