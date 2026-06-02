import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mindrain_admin/secret.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<List<dynamic>> fetchAuthUsers() async {
  final response = await http.get(
    Uri.parse('$SUPABASE_URL/auth/v1/admin/users?page=1&per_page=1000'),
    headers: {
      'Authorization': 'Bearer $SUPABASE_SERVICE_ROLE_KEY',
      'apikey': SUPABASE_SERVICE_ROLE_KEY,
    },
  );

  final data = jsonDecode(response.body);
  return data['users'] as List;
}

// ── Data models ───────────────────────────────────────────────────────────────

class _EventRegistration {
  final String eventTitle;
  final bool paid;

  const _EventRegistration({required this.eventTitle, required this.paid});
}

class _UserRow {
  final String id;
  final String name;
  final String email;
  final bool emailVerified;
  final DateTime? createdAt;
  final List<_EventRegistration> registrations;

  const _UserRow({
    required this.id,
    required this.name,
    required this.email,
    required this.emailVerified,
    this.createdAt,
    required this.registrations,
  });

  bool get hasAnyPaid => registrations.any((r) => r.paid);
  bool get hasAnyUnpaid => registrations.any((r) => !r.paid);
}

// ── Page ──────────────────────────────────────────────────────────────────────

class SignedUpUsersPage extends StatefulWidget {
  const SignedUpUsersPage({super.key});

  @override
  State<SignedUpUsersPage> createState() => _SignedUpUsersPageState();
}

class _SignedUpUsersPageState extends State<SignedUpUsersPage> {
  final _supabase = Supabase.instance.client;

  List<_UserRow> _rows = [];
  bool _loading = true;
  bool _showOnlyUnpaid = false;
  String? _error;
  String _search = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1. Fetch user_info joined with nothing — user_info has name + id
      //    auth.users is not directly queryable from client, but we can get
      //    email + email_confirmed_at via a Supabase admin RPC or by using
      //    the service role. For client-side, we fetch user_info and then
      //    query registrations + registrations_2 for event data.
      //
      //    Email & email_verified: requires an RPC that wraps auth.users.
      //    Expected RPC signature (create this in Supabase):
      //
      //    create or replace function get_users_with_email()
      //    returns table(id uuid, email text, email_confirmed_at timestamptz)
      //    language sql security definer as $$
      //      select id, email, email_confirmed_at from auth.users;
      //    $$;

      final userInfoRes = await _supabase.from('user_info').select('id, name');

      // final authUsersRes = await _supabase
      //     .schema('auth')
      //     .from('users')
      //     .select('id, email, email_confirmed_at');
      final authUsersRes = await fetchAuthUsers();

      // Build lookup maps
      final Map<String, String> emailById = {};
      final Map<String, bool> verifiedById = {};
      final Map<String, DateTime?> createdAtById = {};
      for (final u in (authUsersRes)) {
        final id = u['id'] as String;
        emailById[id] = u['email'] as String? ?? '';
        verifiedById[id] = u['email_confirmed_at'] != null;
        final raw = u['created_at'] as String?;
        createdAtById[id] = raw != null ? DateTime.tryParse(raw) : null;
      }

      // 2. Fetch registrations (no email column — keyed by registration_by user id)
      final reg1Res = await _supabase
          .from('registrations')
          .select('registration_by, paid, events(title)');

      // 3. Fetch registrations_2 (has email column — also keyed by registration_by)
      final reg2Res = await _supabase
          .from('registrations_2')
          .select('registration_by, paid, events(title)');

      // Build per-user registration list
      final Map<String, List<_EventRegistration>> regsByUser = {};

      void addReg(dynamic r) {
        final userId = r['registration_by'] as String;
        final paid = r['paid'] as bool;
        final event = r['events'] as Map<String, dynamic>?;
        final title = event?['title'] as String? ?? 'Unknown event';
        regsByUser.putIfAbsent(userId, () => []);
        regsByUser[userId]!.add(
          _EventRegistration(eventTitle: title, paid: paid),
        );
      }

      for (final r in (reg1Res as List)) {
        addReg(r);
      }
      for (final r in (reg2Res as List)) {
        addReg(r);
      }

      // 4. Assemble rows
      final rows = (userInfoRes as List).map<_UserRow>((u) {
        final id = u['id'] as String;
        return _UserRow(
          id: id,
          name: u['name'] as String,
          email: emailById[id] ?? '—',
          emailVerified: verifiedById[id] ?? false,
          createdAt: createdAtById[id],
          registrations: regsByUser[id] ?? [],
        );
      }).toList();

      // Sort: users with registrations first, then alphabetically
      rows.sort((a, b) {
        if (a.registrations.isEmpty && b.registrations.isNotEmpty) return 1;
        if (a.registrations.isNotEmpty && b.registrations.isEmpty) return -1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

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

  List<_UserRow> get _filteredRows {
    var rows = _rows;

    if (_showOnlyUnpaid) {
      // Keep users who have at least one unpaid registration (or no registrations)
      rows = rows
          .where((r) => r.hasAnyUnpaid || r.registrations.isEmpty)
          .toList();
    }

    if (_search.trim().isNotEmpty) {
      final q = _search.toLowerCase();
      rows = rows
          .where(
            (r) =>
                r.name.toLowerCase().contains(q) ||
                r.email.toLowerCase().contains(q),
          )
          .toList();
    }

    return rows;
  }

  Future<void> _copyAllEmails() async {
    final emails = _filteredRows.map((r) => r.email).join('\n');
    await Clipboard.setData(ClipboardData(text: emails));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_filteredRows.length} email${_filteredRows.length == 1 ? '' : 's'} copied',
          ),
          behavior: SnackBarBehavior.floating,
          width: 280,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
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
                      'Signed Up Users',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _loading
                          ? 'Loading…'
                          : '${_filteredRows.length} of ${_rows.length} users',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Search
                SizedBox(
                  width: 220,
                  height: 36,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: 'Search name or email…',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 16,
                        color: cs.onSurfaceVariant,
                      ),
                      suffixIcon: _search.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 14),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _search = '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 0,
                      ),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: cs.outlineVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: cs.outlineVariant),
                      ),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 20),
                // Unpaid toggle
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Show only unpaid',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
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
                IconButton(
                  onPressed: _loading ? null : _fetchData,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh',
                  iconSize: 18,
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: (_loading || _filteredRows.isEmpty)
                      ? null
                      : _copyAllEmails,
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy all emails'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            Divider(height: 1, color: cs.outlineVariant),
            const SizedBox(height: 4),

            // ── Body ────────────────────────────────────────────────────
            if (_error != null)
              Expanded(
                child: _ErrorState(error: _error!, onRetry: _fetchData),
              )
            else if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_filteredRows.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    _search.isNotEmpty
                        ? 'No users match "$_search".'
                        : _showOnlyUnpaid
                        ? 'No users with unpaid registrations.'
                        : 'No users found.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              Expanded(child: _UsersTable(rows: _filteredRows)),
          ],
        ),
      ),
    );
  }
}

// ── Sort state ────────────────────────────────────────────────────────────────

enum _SortColumn { name, createdAt }

// ── Table ─────────────────────────────────────────────────────────────────────

class _UsersTable extends StatefulWidget {
  final List<_UserRow> rows;
  const _UsersTable({required this.rows});

  @override
  State<_UsersTable> createState() => _UsersTableState();
}

class _UsersTableState extends State<_UsersTable> {
  final _scrollV = ScrollController();
  final _scrollH = ScrollController();

  _SortColumn _sortColumn = _SortColumn.name;
  bool _sortAscending = true;

  // Column widths
  static const double _wIndex = 48;
  static const double _wName = 180;
  static const double _wEmail = 260;
  static const double _wVerified = 110;
  static const double _wCreated = 140; // ← NEW
  static const double _wEvents = 420;

  List<_UserRow> get _sorted {
    final list = List<_UserRow>.from(widget.rows);
    list.sort((a, b) {
      int cmp;
      if (_sortColumn == _SortColumn.name) {
        cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      } else {
        // nulls last
        if (a.createdAt == null && b.createdAt == null) {
          cmp = 0;
        } else if (a.createdAt == null) {
          cmp = 1;
        } else if (b.createdAt == null) {
          cmp = -1;
        } else {
          cmp = a.createdAt!.compareTo(b.createdAt!);
        }
      }
      return _sortAscending ? cmp : -cmp;
    });
    return list;
  }

  void _onHeaderTap(_SortColumn col) {
    setState(() {
      if (_sortColumn == col) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = col;
        _sortAscending = true;
      }
    });
  }

  @override
  void dispose() {
    _scrollV.dispose();
    _scrollH.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sorted = _sorted;

    return Scrollbar(
      controller: _scrollH,
      thumbVisibility: true,
      notificationPredicate: (n) => n.depth == 1,
      child: SingleChildScrollView(
        controller: _scrollH,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _wIndex + _wName + _wEmail + _wVerified + _wCreated + _wEvents,
          child: Column(
            children: [
              // Header
              _HeaderRow(
                cs: cs,
                theme: theme,
                sortColumn: _sortColumn,
                sortAscending: _sortAscending,
                onTap: _onHeaderTap,
              ),
              Divider(height: 1, color: cs.outlineVariant),
              // Data
              Expanded(
                child: Scrollbar(
                  controller: _scrollV,
                  thumbVisibility: true,
                  child: ListView.separated(
                    controller: _scrollV,
                    itemCount: sorted.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                    ),
                    itemBuilder: (context, i) =>
                        _UserRowWidget(index: i + 1, row: sorted[i]),
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

// ── Header row ────────────────────────────────────────────────────────────────

class _HeaderRow extends StatelessWidget {
  final ColorScheme cs;
  final ThemeData theme;
  final _SortColumn sortColumn;
  final bool sortAscending;
  final void Function(_SortColumn) onTap;

  const _HeaderRow({
    required this.cs,
    required this.theme,
    required this.sortColumn,
    required this.sortAscending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          _cell('#', _UsersTableState._wIndex, null, isFirst: true),
          _cell('Name', _UsersTableState._wName, _SortColumn.name),
          _cell('Email', _UsersTableState._wEmail, null),
          _cell('Verified', _UsersTableState._wVerified, null),
          _cell('Created', _UsersTableState._wCreated, _SortColumn.createdAt),
          _cell('Registrations', _UsersTableState._wEvents, null),
        ],
      ),
    );
  }

  Widget _cell(
    String label,
    double width,
    _SortColumn? col, {
    bool isFirst = false,
  }) {
    final active = col != null && sortColumn == col;
    return SizedBox(
      width: width,
      child: Padding(
        padding: EdgeInsets.only(left: isFirst ? 12 : 16, right: 8),
        child: col != null
            ? InkWell(
                onTap: () => onTap(col),
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: active ? cs.primary : cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      active
                          ? (sortAscending
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded)
                          : Icons.unfold_more_rounded,
                      size: 13,
                      color: active
                          ? cs.primary
                          : cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              )
            : Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
      ),
    );
  }
}

// ── Row widget ────────────────────────────────────────────────────────────────

class _UserRowWidget extends StatelessWidget {
  final int index;
  final _UserRow row;
  const _UserRowWidget({required this.index, required this.row});

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    // e.g. "12 Jan 2024"
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Index
          SizedBox(
            width: _UsersTableState._wIndex,
            child: Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Text(
                '$index',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
          // Name
          SizedBox(
            width: _UsersTableState._wName,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 8),
              child: Text(
                row.name,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // Email
          SizedBox(
            width: _UsersTableState._wEmail,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 8),
              child: Text(
                row.email,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // Email verified
          SizedBox(
            width: _UsersTableState._wVerified,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 8),
              child: _VerifiedChip(verified: row.emailVerified, cs: cs),
            ),
          ),
          // Created at                                                  ← NEW
          SizedBox(
            width: _UsersTableState._wCreated,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 8),
              child: Text(
                _formatDate(row.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: row.createdAt != null ? null : cs.onSurfaceVariant,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
          // Registrations
          SizedBox(
            width: _UsersTableState._wEvents,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 16),
              child: row.registrations.isEmpty
                  ? Text(
                      'No registrations',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    )
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: row.registrations
                          .map((r) => _EventChip(reg: r, cs: cs))
                          .toList(),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chips ─────────────────────────────────────────────────────────────────────

class _VerifiedChip extends StatelessWidget {
  final bool verified;
  final ColorScheme cs;
  const _VerifiedChip({required this.verified, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          verified ? Icons.verified_rounded : Icons.cancel_outlined,
          size: 14,
          color: verified ? Colors.green.shade600 : cs.onSurfaceVariant,
        ),
        const SizedBox(width: 5),
        Text(
          verified ? 'Verified' : 'Unverified',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: verified ? Colors.green.shade600 : cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _EventChip extends StatelessWidget {
  final _EventRegistration reg;
  final ColorScheme cs;
  const _EventChip({required this.reg, required this.cs});

  @override
  Widget build(BuildContext context) {
    final paid = reg.paid;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: paid
            ? Colors.green.withValues(alpha: 0.10)
            : cs.errorContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: paid
              ? Colors.green.withValues(alpha: 0.25)
              : cs.error.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              reg.eventTitle,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: paid ? Colors.green.shade700 : cs.error,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: paid
                  ? Colors.green.withValues(alpha: 0.18)
                  : cs.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              paid ? 'paid' : 'unpaid',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: paid ? Colors.green.shade700 : cs.error,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, color: cs.error, size: 32),
          const SizedBox(height: 8),
          Text('Failed to load users', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            error,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
