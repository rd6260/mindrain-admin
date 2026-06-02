part of 'send_emails_bloc.dart';

sealed class SendEmailsEvent extends Equatable {
  const SendEmailsEvent();

  @override
  List<Object?> get props => [];
}

// ── CSV ──────────────────────────────────────────────────────────────────────

final class PickTestCsvRequested extends SendEmailsEvent {
  const PickTestCsvRequested();
}

final class PickFinalCsvRequested extends SendEmailsEvent {
  const PickFinalCsvRequested();
}

// ── Attachments ──────────────────────────────────────────────────────────────

final class PickAttachmentsRequested extends SendEmailsEvent {
  const PickAttachmentsRequested();
}

final class AttachmentRemoved extends SendEmailsEvent {
  const AttachmentRemoved(this.file);
  final PlatformFile file;

  @override
  List<Object?> get props => [file.name];
}

// ── Composer / autocomplete ───────────────────────────────────────────────────

/// Fired on every body text change so the bloc can update detected vars and
/// compute autocomplete suggestions.
final class BodyTextChanged extends SendEmailsEvent {
  const BodyTextChanged({required this.text, required this.cursorOffset});
  final String text;
  final int cursorOffset;

  @override
  List<Object?> get props => [text, cursorOffset];
}

final class NextSuggestionRequested extends SendEmailsEvent {
  const NextSuggestionRequested();
}

final class OverlayDismissed extends SendEmailsEvent {
  const OverlayDismissed();
}

final class DefaultValueChanged extends SendEmailsEvent {
  const DefaultValueChanged({required this.variable, required this.value});
  final String variable;
  final String value;

  @override
  List<Object?> get props => [variable, value];
}

// ── Run ───────────────────────────────────────────────────────────────────────

final class TestRunRequested extends SendEmailsEvent {
  const TestRunRequested({
    required this.subject,
    required this.body,
    this.htmlBody,
  });
  final String subject;
  final String body;
  final String? htmlBody;

  @override
  List<Object?> get props => [subject, body, htmlBody];
}

final class FinalRunRequested extends SendEmailsEvent {
  const FinalRunRequested({
    required this.subject,
    required this.body,
    this.htmlBody,
  });
  final String subject;
  final String body;
  final String? htmlBody;

  @override
  List<Object?> get props => [subject, body, htmlBody];
}

final class RunCancelled extends SendEmailsEvent {
  const RunCancelled();
}

final class HtmlBodyChanged extends SendEmailsEvent {
  const HtmlBodyChanged({required this.text, required this.cursorOffset});
  final String text;
  final int cursorOffset;

  @override
  List<Object?> get props => [text, cursorOffset];
}

final class EmailModeChanged extends SendEmailsEvent {
  const EmailModeChanged({required this.isHtml});
  final bool isHtml;

  @override
  List<Object?> get props => [isHtml];
}

