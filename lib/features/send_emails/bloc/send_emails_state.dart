part of 'send_emails_bloc.dart';

enum RunStatus { idle, running, cancelling, done }

final class SendEmailsState extends Equatable {
  const SendEmailsState({
    this.testHeaders = const [],
    this.testRows = const [],
    this.finalHeaders = const [],
    this.finalRows = const [],
    this.emailCol,
    this.csvWarning,
    this.attachments = const [],
    this.plainTextBody = '',
    this.htmlBody = '',
    this.isHtmlMode = false,
    this.detectedVars = const {},
    this.defaultValues = const {},
    this.suggestions = const [],
    this.selectedSuggestionIndex = 0,
    this.runStatus = RunStatus.idle,
    this.total = 0,
    this.sent = 0,
    this.ok = 0,
    this.fail = 0,
    this.runLog = '',
  });

  // ── CSV ────────────────────────────────────────────────────────────────────
  final List<String> testHeaders;
  final List<Map<String, String>> testRows;
  final List<String> finalHeaders;
  final List<Map<String, String>> finalRows;
  final String? emailCol;
  final String? csvWarning;

  // ── Attachments ────────────────────────────────────────────────────────────
  final List<PlatformFile> attachments;

  // ── Body texts (stored for cross-body var detection) ──────────────────────
  final String plainTextBody;
  final String htmlBody;
  final bool isHtmlMode;

  // ── Composer ───────────────────────────────────────────────────────────────
  final Set<String> detectedVars;
  final Map<String, String> defaultValues;

  // ── Autocomplete ───────────────────────────────────────────────────────────
  final List<String> suggestions;
  final int selectedSuggestionIndex;

  // ── Run ────────────────────────────────────────────────────────────────────
  final RunStatus runStatus;
  final int total;
  final int sent;
  final int ok;
  final int fail;
  final String runLog;

  bool get isRunning =>
      runStatus == RunStatus.running || runStatus == RunStatus.cancelling;

  // ── copyWith ───────────────────────────────────────────────────────────────
  SendEmailsState copyWith({
    List<String>? testHeaders,
    List<Map<String, String>>? testRows,
    List<String>? finalHeaders,
    List<Map<String, String>>? finalRows,
    Object? emailCol = _keep,
    Object? csvWarning = _keep,
    List<PlatformFile>? attachments,
    String? plainTextBody,
    String? htmlBody,
    bool? isHtmlMode,
    Set<String>? detectedVars,
    Map<String, String>? defaultValues,
    List<String>? suggestions,
    int? selectedSuggestionIndex,
    RunStatus? runStatus,
    int? total,
    int? sent,
    int? ok,
    int? fail,
    String? runLog,
  }) {
    return SendEmailsState(
      testHeaders: testHeaders ?? this.testHeaders,
      testRows: testRows ?? this.testRows,
      finalHeaders: finalHeaders ?? this.finalHeaders,
      finalRows: finalRows ?? this.finalRows,
      emailCol: emailCol == _keep ? this.emailCol : emailCol as String?,
      csvWarning: csvWarning == _keep ? this.csvWarning : csvWarning as String?,
      attachments: attachments ?? this.attachments,
      plainTextBody: plainTextBody ?? this.plainTextBody,
      htmlBody: htmlBody ?? this.htmlBody,
      isHtmlMode: isHtmlMode ?? this.isHtmlMode,
      detectedVars: detectedVars ?? this.detectedVars,
      defaultValues: defaultValues ?? this.defaultValues,
      suggestions: suggestions ?? this.suggestions,
      selectedSuggestionIndex:
          selectedSuggestionIndex ?? this.selectedSuggestionIndex,
      runStatus: runStatus ?? this.runStatus,
      total: total ?? this.total,
      sent: sent ?? this.sent,
      ok: ok ?? this.ok,
      fail: fail ?? this.fail,
      runLog: runLog ?? this.runLog,
    );
  }

  @override
  List<Object?> get props => [
        testHeaders,
        testRows,
        finalHeaders,
        finalRows,
        emailCol,
        csvWarning,
        attachments,
        plainTextBody,
        htmlBody,
        isHtmlMode,
        detectedVars,
        defaultValues,
        suggestions,
        selectedSuggestionIndex,
        runStatus,
        total,
        sent,
        ok,
        fail,
        runLog,
      ];
}

const _keep = Object();
