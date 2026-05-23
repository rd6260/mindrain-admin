import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BriefCollectedEmailsPage extends StatefulWidget {
  const BriefCollectedEmailsPage({super.key});

  @override
  State<BriefCollectedEmailsPage> createState() =>
      _BriefCollectedEmailsPageState();
}

class _BriefCollectedEmailsPageState extends State<BriefCollectedEmailsPage> {
  final _supabase = Supabase.instance.client;

  List<_EmailRow> _rows = [];
  bool _loading = true;
  bool _showOnlyUnpaid = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Fetch brief_emails joined with events
      final emailsRes = await _supabase
          .from('brief_emails')
          .select('id, email, created_at, event_id, events(title, created_at)')
          .order('created_at', ascending: false);

      final List emails = emailsRes as List;

      // Fetch paid emails from registrations (via auth.users email — not directly available)
      // registrations_2 stores email directly; for registrations, we join auth.users via registration_by
      // Strategy: collect all paid emails from registrations_2 directly,
      // and for registrations table, fetch user emails via supabase admin or use a DB view/function.
      // Since client-side can't query auth.users, we use registrations_2.email for paid check there,
      // and for registrations table we can only filter by event_id + paid=true and cross-reference
      // via a Supabase RPC or a Postgres view. Here we use the available data:
      //   - registrations_2: email column is available, paid=true
      //   - registrations: no email column, so we skip cross-referencing those (or you can add an RPC)

      final paidEmailsRes = await _supabase
          .from('registrations_2')
          .select('email')
          .eq('paid', true);

      final Set<String> paidEmails = {
        for (final r in (paidEmailsRes as List)) (r['email'] as String).toLowerCase(),
      };

      final rows = emails.map<_EmailRow>((e) {
        final event = e['events'] as Map<String, dynamic>?;
        return _EmailRow(
          id: e['id'] as int,
          email: e['email'] as String,
          createdAt: DateTime.parse(e['created_at'] as String).toLocal(),
          eventName: event?['title'] as String? ?? '—',
          eventTime: event?['created_at'] != null
              ? DateTime.parse(event!['created_at'] as String).toLocal()
              : null,
          isPaid: paidEmails.contains((e['email'] as String).toLowerCase()),
        );
      }).toList();

      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<_EmailRow> get _filteredRows {
    if (_showOnlyUnpaid) {
      return _rows.where((r) => !r.isPaid).toList();
    }
    return _rows;
  }

  Future<void> _copyAllEmails() async {
    final emails = _filteredRows.map((r) => r.email).join('\n');
    await Clipboard.setData(ClipboardData(text: emails));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_filteredRows.length} email${_filteredRows.length == 1 ? '' : 's'} copied to clipboard',
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
        child: Column(
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
                      _loading
                          ? 'Loading…'
                          : '${_filteredRows.length} of ${_rows.length} entries',
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
                      value: _showOnlyUnpaid,
                      onChanged: (v) => setState(() => _showOnlyUnpaid = v),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // Refresh
                IconButton(
                  onPressed: _loading ? null : _fetchData,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh',
                  iconSize: 18,
                ),
                const SizedBox(width: 8),
                // Copy all
                FilledButton.tonalIcon(
                  onPressed:
                      (_loading || _filteredRows.isEmpty) ? null : _copyAllEmails,
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
            if (_error != null)
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
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                          onPressed: _fetchData,
                          child: const Text('Retry')),
                    ],
                  ),
                ),
              )
            else if (_loading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_filteredRows.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    _showOnlyUnpaid
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
                child: _EmailTable(rows: _filteredRows),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

class _EmailRow {
  final int id;
  final String email;
  final DateTime createdAt;
  final String eventName;
  final DateTime? eventTime;
  final bool isPaid;

  const _EmailRow({
    required this.id,
    required this.email,
    required this.createdAt,
    required this.eventName,
    required this.eventTime,
    required this.isPaid,
  });
}

// ── Scrollable data table ─────────────────────────────────────────────────────

class _EmailTable extends StatefulWidget {
  final List<_EmailRow> rows;
  const _EmailTable({required this.rows});

  @override
  State<_EmailTable> createState() => _EmailTableState();
}

class _EmailTableState extends State<_EmailTable> {
  final _scrollController = ScrollController();

  static const _cols = ['#', 'Email', 'Event', 'Event Time', 'Collected At', 'Status'];
  static const _colWidths = [48.0, 280.0, 200.0, 160.0, 160.0, 90.0];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: colorScheme.outlineVariant.withOpacity(0.5)),
              itemBuilder: (context, i) {
                final row = widget.rows[i];
                return _TableRow(
                  isHeader: false,
                  cells: [
                    '${i + 1}',
                    row.email,
                    row.eventName,
                    row.eventTime != null ? _formatDate(row.eventTime!) : '—',
                    _formatDate(row.createdAt),
                    row.isPaid ? 'paid' : 'unpaid',
                  ],
                  widths: _colWidths,
                  colorScheme: colorScheme,
                  theme: theme,
                  isPaid: row.isPaid,
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

  const _TableRow({
    required this.isHeader,
    required this.cells,
    required this.widths,
    required this.colorScheme,
    required this.theme,
    this.isPaid,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isHeader
          ? colorScheme.surfaceContainerHighest.withOpacity(0.5)
          : null,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
      child: Row(
        children: List.generate(cells.length, (i) {
          final isStatus = !isHeader && i == cells.length - 1;
          return SizedBox(
            width: widths[i],
            child: Padding(
              padding: EdgeInsets.only(
                left: i == 0 ? 12 : 16,
                right: 8,
              ),
              child: isStatus
                  ? _StatusChip(paid: isPaid ?? false, colorScheme: colorScheme)
                  : Text(
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
                    ),
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
            ? Colors.green.withOpacity(0.12)
            : colorScheme.errorContainer.withOpacity(0.5),
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
