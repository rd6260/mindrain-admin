import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mindrain_admin/features/send_emails/bloc/send_emails_bloc.dart';

class CsvCard extends StatefulWidget {
  const CsvCard({
    super.key,
    required this.label,
    required this.color,
    required this.isTest,
  });

  final String label;
  final Color color;
  final bool isTest;

  @override
  State<CsvCard> createState() => _CsvCardState();
}

class _CsvCardState extends State<CsvCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SendEmailsBloc, SendEmailsState>(
      buildWhen: (prev, curr) =>
          prev.isRunning != curr.isRunning ||
          (widget.isTest
              ? prev.testHeaders != curr.testHeaders ||
                  prev.testRows != curr.testRows
              : prev.finalHeaders != curr.finalHeaders ||
                  prev.finalRows != curr.finalRows) ||
          prev.emailCol != curr.emailCol,
      builder: (context, state) {
        final headers =
            widget.isTest ? state.testHeaders : state.finalHeaders;
        final rowCount =
            widget.isTest ? state.testRows.length : state.finalRows.length;
        final loaded = headers.isNotEmpty;

        return MouseRegion(
          cursor: state.isRunning
              ? SystemMouseCursors.forbidden
              : SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: state.isRunning
                ? null
                : () => context.read<SendEmailsBloc>().add(
                      widget.isTest
                          ? const PickTestCsvRequested()
                          : const PickFinalCsvRequested(),
                    ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: loaded
                    ? widget.color.withValues(alpha: 0.05)
                    : _hovered
                        ? const Color(0xFFF4F5F7)
                        : const Color(0xFFFAFAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: loaded
                      ? widget.color.withValues(alpha: 0.35)
                      : _hovered
                          ? widget.color.withValues(alpha: 0.2)
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
                          color: widget.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          loaded
                              ? Icons.check_circle_rounded
                              : Icons.upload_file_rounded,
                          color: widget.color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              loaded
                                  ? '$rowCount rows · ${headers.length} cols'
                                      ' · email: ${state.emailCol ?? "not found"}'
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
                          color: widget.color.withValues(alpha: 0.6),
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
                                  (state.emailCol?.toLowerCase() ?? '');
                              return _ColumnChip(
                                label: h,
                                color: widget.color,
                                isEmail: isEmail,
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
      },
    );
  }
}

// ── Column Chip ───────────────────────────────────────────────────────────────

class _ColumnChip extends StatefulWidget {
  const _ColumnChip({
    required this.label,
    required this.color,
    required this.isEmail,
  });

  final String label;
  final Color color;
  final bool isEmail;

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
        // Column chips insert the column name into the body via a callback
        // stored in the nearest ComposerSection ancestor.
        onTap: () {
          final fn = _ColumnInsertCallback.of(context);
          fn?.call(widget.label);
        },
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

// ── Inherited widget to pass column-insert callback down the tree ─────────────

class _ColumnInsertCallback extends InheritedWidget {
  const _ColumnInsertCallback({required this.onInsert, required super.child});

  final void Function(String column) onInsert;

  static void Function(String)? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_ColumnInsertCallback>()
        ?.onInsert;
  }

  @override
  bool updateShouldNotify(_ColumnInsertCallback old) =>
      onInsert != old.onInsert;
}

/// Wraps [child] with a [_ColumnInsertCallback] so that [_ColumnChip]s inside
/// can call [onInsert] without prop-drilling.
class ColumnInsertScope extends StatelessWidget {
  const ColumnInsertScope({
    super.key,
    required this.onInsert,
    required this.child,
  });

  final void Function(String column) onInsert;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      _ColumnInsertCallback(onInsert: onInsert, child: child);
}
