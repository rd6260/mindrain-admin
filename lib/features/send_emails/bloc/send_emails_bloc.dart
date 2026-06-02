import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mindrain_admin/features/send_emails/data/csv_parser.dart';
import 'package:mindrain_admin/features/send_emails/data/postmark_service.dart';
import 'package:mindrain_admin/secret.dart';

part 'send_emails_event.dart';
part 'send_emails_state.dart';

class SendEmailsBloc extends Bloc<SendEmailsEvent, SendEmailsState> {
  SendEmailsBloc() : super(const SendEmailsState()) {
    on<PickTestCsvRequested>(_onPickTestCsv);
    on<PickFinalCsvRequested>(_onPickFinalCsv);
    on<PickAttachmentsRequested>(_onPickAttachments);
    on<AttachmentRemoved>(_onAttachmentRemoved);
    on<BodyTextChanged>(_onBodyTextChanged);
    on<HtmlBodyChanged>(_onHtmlBodyChanged);
    on<EmailModeChanged>(_onEmailModeChanged);
    on<NextSuggestionRequested>(_onNextSuggestion);
    on<OverlayDismissed>(_onOverlayDismissed);
    on<DefaultValueChanged>(_onDefaultValueChanged);
    on<TestRunRequested>(_onTestRun);
    on<FinalRunRequested>(_onFinalRun);
    on<RunCancelled>(_onRunCancelled);
  }

  // A flag checked inside the run loop; set by RunCancelled which runs
  // concurrently (different event type → different handler, not queued).
  bool _cancelRequested = false;

  // ── CSV ────────────────────────────────────────────────────────────────────

  Future<void> _onPickTestCsv(
    PickTestCsvRequested event,
    Emitter<SendEmailsState> emit,
  ) async {
    final result = await CsvParser.pickAndParse();
    if (result == null) return;
    emit(
      _withWarnings(
        state.copyWith(
          testHeaders: result.headers,
          testRows: result.rows,
        ),
      ),
    );
  }

  Future<void> _onPickFinalCsv(
    PickFinalCsvRequested event,
    Emitter<SendEmailsState> emit,
  ) async {
    final result = await CsvParser.pickAndParse();
    if (result == null) return;
    emit(
      _withWarnings(
        state.copyWith(
          finalHeaders: result.headers,
          finalRows: result.rows,
        ),
      ),
    );
  }

  /// Recomputes [emailCol] and [csvWarning] for a given intermediate state.
  SendEmailsState _withWarnings(SendEmailsState s) {
    final warnings = <String>[];

    if (s.testHeaders.isNotEmpty &&
        s.finalHeaders.isNotEmpty &&
        s.testHeaders.join(',') != s.finalHeaders.join(',')) {
      warnings.add('Test and Final CSV headers do not match!');
    }

    final allHeaders =
        s.testHeaders.isNotEmpty ? s.testHeaders : s.finalHeaders;
    final emailCol =
        allHeaders.isNotEmpty ? CsvParser.findEmailColumn(allHeaders) : null;

    if (allHeaders.isNotEmpty && emailCol == null) {
      warnings.add(
        'No email column found. Add a column named "email", "emails", etc.',
      );
    }

    return s.copyWith(
      emailCol: emailCol,
      csvWarning: warnings.isEmpty ? null : warnings.join(' | '),
    );
  }

  // ── Attachments ────────────────────────────────────────────────────────────

  Future<void> _onPickAttachments(
    PickAttachmentsRequested event,
    Emitter<SendEmailsState> emit,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;
    emit(
      state.copyWith(
        attachments: [...state.attachments, ...result.files],
      ),
    );
  }

  void _onAttachmentRemoved(
    AttachmentRemoved event,
    Emitter<SendEmailsState> emit,
  ) {
    emit(
      state.copyWith(
        attachments: state.attachments
            .where((f) => f.name != event.file.name)
            .toList(),
      ),
    );
  }

  // ── Composer / autocomplete ────────────────────────────────────────────────

  void _onBodyTextChanged(
    BodyTextChanged event,
    Emitter<SendEmailsState> emit,
  ) {
    final vars = state.isHtmlMode
        ? _detectVars(state.htmlBody)
        : _detectVars(event.text);
    final suggestions = _computeSuggestions(event.text, event.cursorOffset);
    final index = suggestions.join() != state.suggestions.join()
        ? 0
        : state.selectedSuggestionIndex;

    // Prune removed vars from defaultValues
    final defaults = Map<String, String>.from(state.defaultValues)
      ..removeWhere((k, _) => !vars.contains(k));

    emit(
      state.copyWith(
        plainTextBody: event.text,
        detectedVars: vars,
        defaultValues: defaults,
        suggestions: suggestions,
        selectedSuggestionIndex: index,
      ),
    );
  }

  void _onHtmlBodyChanged(
    HtmlBodyChanged event,
    Emitter<SendEmailsState> emit,
  ) {
    final vars = state.isHtmlMode
        ? _detectVars(event.text)
        : _detectVars(state.plainTextBody);
    final suggestions = _computeSuggestions(event.text, event.cursorOffset);
    final index = suggestions.join() != state.suggestions.join()
        ? 0
        : state.selectedSuggestionIndex;

    final defaults = Map<String, String>.from(state.defaultValues)
      ..removeWhere((k, _) => !vars.contains(k));

    emit(
      state.copyWith(
        htmlBody: event.text,
        detectedVars: vars,
        defaultValues: defaults,
        suggestions: suggestions,
        selectedSuggestionIndex: index,
      ),
    );
  }

  void _onEmailModeChanged(
    EmailModeChanged event,
    Emitter<SendEmailsState> emit,
  ) {
    final vars = event.isHtml
        ? _detectVars(state.htmlBody)
        : _detectVars(state.plainTextBody);
    final defaults = Map<String, String>.from(state.defaultValues)
      ..removeWhere((k, _) => !vars.contains(k));

    emit(
      state.copyWith(
        isHtmlMode: event.isHtml,
        detectedVars: vars,
        defaultValues: defaults,
        suggestions: const [],
        selectedSuggestionIndex: 0,
      ),
    );
  }

  void _onNextSuggestion(
    NextSuggestionRequested event,
    Emitter<SendEmailsState> emit,
  ) {
    if (state.suggestions.isEmpty) return;
    emit(
      state.copyWith(
        selectedSuggestionIndex:
            (state.selectedSuggestionIndex + 1) % state.suggestions.length,
      ),
    );
  }

  void _onOverlayDismissed(
    OverlayDismissed event,
    Emitter<SendEmailsState> emit,
  ) {
    emit(state.copyWith(suggestions: []));
  }

  void _onDefaultValueChanged(
    DefaultValueChanged event,
    Emitter<SendEmailsState> emit,
  ) {
    emit(
      state.copyWith(
        defaultValues: {
          ...state.defaultValues,
          event.variable: event.value,
        },
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Set<String> _detectVars(String text) {
    return RegExp(r'\{\{(\w+)\}\}')
        .allMatches(text)
        .map((m) => m.group(1)!)
        .toSet();
  }

  List<String> _computeSuggestions(String text, int cursor) {
    if (cursor < 0 || cursor > text.length) return [];
    final before = text.substring(0, cursor);
    final openIdx = before.lastIndexOf('{{');
    if (openIdx == -1) return [];
    final afterOpen = before.substring(openIdx + 2);
    if (afterOpen.contains('}}')) return [];

    final typed = afterOpen.toLowerCase();
    final allHeaders = {...state.testHeaders, ...state.finalHeaders}.toList();

    return allHeaders
        .where((h) => h.isNotEmpty && h.toLowerCase().startsWith(typed))
        .toList();
  }

  // ── Run ────────────────────────────────────────────────────────────────────

  Future<void> _onTestRun(
    TestRunRequested event,
    Emitter<SendEmailsState> emit,
  ) async {
    await _executeRun(
      emit: emit,
      rows: state.testRows,
      subject: event.subject,
      body: event.body,
      htmlBody: event.htmlBody,
    );
  }

  Future<void> _onFinalRun(
    FinalRunRequested event,
    Emitter<SendEmailsState> emit,
  ) async {
    await _executeRun(
      emit: emit,
      rows: state.finalRows,
      subject: event.subject,
      body: event.body,
      htmlBody: event.htmlBody,
    );
  }

  void _onRunCancelled(
    RunCancelled event,
    Emitter<SendEmailsState> emit,
  ) {
    _cancelRequested = true;
    emit(state.copyWith(runStatus: RunStatus.cancelling));
  }

  Future<void> _executeRun({
    required Emitter<SendEmailsState> emit,
    required List<Map<String, String>> rows,
    required String subject,
    required String body,
    String? htmlBody,
  }) async {
    final emailCol = state.emailCol;
    if (emailCol == null) return;

    final token = POSTMARK_API_KEY;
    if (token.isEmpty) {
      // Emit a sentinel warning so the view can show a dialog
      emit(state.copyWith(csvWarning: '__missing_token__'));
      emit(state.copyWith(csvWarning: state.csvWarning));
      return;
    }

    _cancelRequested = false;
    emit(
      state.copyWith(
        runStatus: RunStatus.running,
        total: rows.length,
        sent: 0,
        ok: 0,
        fail: 0,
        runLog: '',
      ),
    );

    final attachments = state.attachments
        .map(
          (f) => PostmarkAttachment(
            name: f.name,
            bytes: f.bytes!,
            contentType: 'application/octet-stream',
          ),
        )
        .toList();

    int sent = 0, ok = 0, fail = 0;
    String log = '';

    for (final row in rows) {
      if (_cancelRequested) break;

      final to = row[emailCol] ?? '';
      if (to.isEmpty) {
        sent++;
        fail++;
        emit(state.copyWith(sent: sent, ok: ok, fail: fail, runLog: log));
        continue;
      }

      final resolvedSubject =
          CsvParser.resolveTemplate(subject, row, state.defaultValues);
      final resolvedText = state.isHtmlMode
          ? null
          : CsvParser.resolveTemplate(body, row, state.defaultValues);
      final resolvedHtml = (state.isHtmlMode && htmlBody != null && htmlBody.isNotEmpty)
          ? CsvParser.resolveTemplate(htmlBody, row, state.defaultValues)
          : null;

      final res = await PostmarkService.sendEmail(
        token: token,
        to: to,
        subject: resolvedSubject,
        textBody: resolvedText,
        htmlBody: resolvedHtml,
        attachments: attachments,
      );

      sent++;
      if (res.success) {
        ok++;
      } else {
        fail++;
        log += '[$to] ${res.errorMessage}\n';
      }
      emit(state.copyWith(sent: sent, ok: ok, fail: fail, runLog: log));
    }

    emit(state.copyWith(runStatus: RunStatus.done));
  }
}
