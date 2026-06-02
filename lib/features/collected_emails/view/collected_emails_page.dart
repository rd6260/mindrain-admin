import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mindrain_admin/features/collected_emails/bloc/collected_emails_bloc.dart';
import 'package:mindrain_admin/features/collected_emails/bloc/collected_emails_event.dart';
import 'package:mindrain_admin/features/collected_emails/bloc/collected_emails_state.dart';
import 'package:mindrain_admin/features/collected_emails/data/model.dart';
import 'package:mindrain_admin/features/collected_emails/data/service.dart';
import 'package:mindrain_admin/features/registrations/data/model.dart';
import 'package:mindrain_admin/features/registrations/widgets/info_dialog.dart';

class CollectedEmailsPage extends StatelessWidget {
  const CollectedEmailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CollectedEmailsBloc(CollectedEmailsService())
        ..add(LoadCollectedEmails()),
      child: const _CollectedEmailsView(),
    );
  }
}

class _CollectedEmailsView extends StatelessWidget {
  const _CollectedEmailsView();

  Future<void> _copyAllEmails(BuildContext context, List<CollectedEmail> rows) async {
    final emails = rows.map((r) => r.email).join('\n');
    await Clipboard.setData(ClipboardData(text: emails));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${rows.length} email${rows.length == 1 ? '' : 's'} copied to clipboard',
          ),
          behavior: SnackBarBehavior.floating,
          width: 320,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: BlocBuilder<CollectedEmailsBloc, CollectedEmailsState>(
          builder: (context, state) {
            bool isLoading = state is CollectedEmailsLoading;
            bool isError = state is CollectedEmailsError;
            String? errorMessage = state is CollectedEmailsError ? state.message : null;
            
            List<CollectedEmail> filteredRows = [];
            List<CollectedEmail> allRows = [];
            bool showOnlyUnpaid = false;

            if (state is CollectedEmailsLoaded) {
              filteredRows = state.filteredEmails;
              allRows = state.allEmails;
              showOnlyUnpaid = state.showOnlyUnpaid;
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────────────
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Brief Collected Emails',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isLoading
                              ? 'Loading…'
                              : '${filteredRows.length} of ${allRows.length} entries',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Show only unpaid toggle
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Show only unpaid',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: showOnlyUnpaid,
                          onChanged: (v) {
                            context.read<CollectedEmailsBloc>().add(ToggleShowUnpaid(v));
                          },
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // Refresh
                    IconButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              context.read<CollectedEmailsBloc>().add(LoadCollectedEmails());
                            },
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Refresh',
                      iconSize: 18,
                    ),
                    const SizedBox(width: 8),
                    // Copy all
                    FilledButton.tonalIcon(
                      onPressed: (isLoading || filteredRows.isEmpty)
                          ? null
                          : () => _copyAllEmails(context, filteredRows),
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy all emails'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                Divider(height: 1, color: colorScheme.outlineVariant),
                const SizedBox(height: 4),

                // ── Table ────────────────────────────────────────────────────
                if (isError)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline_rounded,
                              color: colorScheme.error, size: 32),
                          const SizedBox(height: 8),
                          Text(
                            'Failed to load data',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            errorMessage!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                              onPressed: () {
                                context.read<CollectedEmailsBloc>().add(LoadCollectedEmails());
                              },
                              child: const Text('Retry')),
                        ],
                      ),
                    ),
                  )
                else if (isLoading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (filteredRows.isEmpty)
                  Expanded(
                    child: Center(
                      child: Text(
                        showOnlyUnpaid
                            ? 'No unpaid emails found.'
                            : 'No emails collected yet.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: _EmailTable(rows: filteredRows),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Scrollable data table ─────────────────────────────────────────────────────

class _EmailTable extends StatefulWidget {
  final List<CollectedEmail> rows;
  const _EmailTable({required this.rows});

  @override
  State<_EmailTable> createState() => _EmailTableState();
}

class _EmailTableState extends State<_EmailTable> {
  final _scrollController = ScrollController();

  static const _cols = ['#', 'Email', 'User', 'Event', 'Collected At', 'Status'];
  static const _colWidths = [48.0, 260.0, 180.0, 200.0, 160.0, 90.0];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showUserPopup(RegistrationUser user) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (_) => InfoDialog(
        avatar: _initials(user.name),
        title: user.name,
        subtitle: user.email ?? '—',
        rows: [
          PopupRow('Role', user.role ?? '—'),
          PopupRow('Institute', user.institute ?? '—'),
          PopupRow(
            'Academic Year',
            user.academicYear != null ? 'Year ${user.academicYear}' : '—',
          ),
          PopupRow('Academic Level', user.academicLevel ?? '—'),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            _TableRow(
              isHeader: true,
              cells: _cols,
              widths: _colWidths,
              colorScheme: colorScheme,
              theme: theme,
            ),
            Divider(height: 1, color: colorScheme.outlineVariant),
            // Data rows
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.rows.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
              itemBuilder: (context, i) {
                final row = widget.rows[i];
                return _TableRow(
                  isHeader: false,
                  cells: [
                    '${i + 1}',
                    row.email,
                    row.user?.name ?? '—',
                    row.eventName,
                    _formatDate(row.createdAt),
                    row.isPaid ? 'paid' : 'unpaid',
                  ],
                  widths: _colWidths,
                  colorScheme: colorScheme,
                  theme: theme,
                  isPaid: row.isPaid,
                  onUserTap: row.user != null ? () => _showUserPopup(row.user!) : null,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    return '${d.day.toString().padLeft(2, '0')} '
        '${_month(d.month)} ${d.year}  '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _month(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];
}

class _TableRow extends StatelessWidget {
  final bool isHeader;
  final List<String> cells;
  final List<double> widths;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final bool? isPaid;
  final VoidCallback? onUserTap;

  const _TableRow({
    required this.isHeader,
    required this.cells,
    required this.widths,
    required this.colorScheme,
    required this.theme,
    this.isPaid,
    this.onUserTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isHeader
          ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
          : null,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
      child: Row(
        children: List.generate(cells.length, (i) {
          final isStatus = !isHeader && i == cells.length - 1;
          final isUser = !isHeader && i == 2;
          
          Widget childWidget;
          if (isStatus) {
            childWidget = _StatusChip(paid: isPaid ?? false, colorScheme: colorScheme);
          } else if (isUser && onUserTap != null) {
            childWidget = GestureDetector(
              onTap: onUserTap,
              child: Text(
                cells[i],
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: colorScheme.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: colorScheme.primary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            );
          } else {
            childWidget = Text(
              cells[i],
              style: isHeader
                  ? theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    )
                  : i == 1
                      ? theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          fontSize: 12.5,
                        )
                      : theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            );
          }
          
          return SizedBox(
            width: widths[i],
            child: Padding(
              padding: EdgeInsets.only(
                left: i == 0 ? 12 : 16,
                right: 8,
              ),
              child: childWidget,
            ),
          );
        }),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool paid;
  final ColorScheme colorScheme;

  const _StatusChip({required this.paid, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: paid
            ? Colors.green.withValues(alpha: 0.12)
            : colorScheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        paid ? 'paid' : 'unpaid',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: paid ? Colors.green.shade700 : colorScheme.error,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
