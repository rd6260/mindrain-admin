import 'package:flutter/material.dart';
import 'package:mindrain_admin/pages/wallet_shared_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _supabase = Supabase.instance.client;

// ─── Model ────────────────────────────────────────────────────────────────────

class ReferralAccountEntry {
  final String id;
  final DateTime createdAt;
  final String referralCode;
  bool isApproved;
  bool isBlocked;

  final String name;
  final String role;
  final String? institute;
  final int? academicYear;
  final String? academicLevel;

  ReferralAccountEntry({
    required this.id,
    required this.createdAt,
    required this.referralCode,
    required this.isApproved,
    required this.isBlocked,
    required this.name,
    required this.role,
    this.institute,
    this.academicYear,
    this.academicLevel,
  });

  String get statusLabel {
    if (isBlocked) return 'Blocked';
    if (isApproved) return 'Approved';
    return 'Pending';
  }

  factory ReferralAccountEntry.fromJson(Map<String, dynamic> json) {
    final info = json['user_info'] as Map<String, dynamic>? ?? {};
    return ReferralAccountEntry(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      referralCode: json['referral_code'] as String,
      isApproved: json['is_approved'] as bool? ?? false,
      isBlocked: json['is_blocked'] as bool? ?? false,
      name: info['name'] as String? ?? 'Unknown',
      role: info['role'] as String? ?? '—',
      institute: info['institute'] as String?,
      academicYear: info['academic_year'] as int?,
      academicLevel: info['academic_level'] as String?,
    );
  }
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class ReferralAccountManagementPage extends StatefulWidget {
  const ReferralAccountManagementPage({super.key});

  @override
  State<ReferralAccountManagementPage> createState() =>
      _ReferralAccountManagementPageState();
}

class _ReferralAccountManagementPageState
    extends State<ReferralAccountManagementPage> {
  List<ReferralAccountEntry> _accounts = [];
  bool _loading = true;
  String? _error;

  // ── Colours (same tokens as WalletManagementPage) ─────────────────────────
  static const _bg = Color(0xFFF7F7F5);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4E4E0);
  static const _textPrimary = Color(0xFF1A1A1A);
  static const _textSecondary = Color(0xFF8A8A85);
  static const _accentLight = Color(0xFFF0F0EE);
  static const _positive = Color(0xFF2E7D5E);
  static const _positiveLight = Color(0xFFECF5F0);
  static const _warning = Color(0xFFB45309);
  static const _warningLight = Color(0xFFFDF3E3);
  static const _errorColor = Color(0xFFDC2626);
  static const _errorLight = Color(0xFFFEF2F2);

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fetchAccounts();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _fetchAccounts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _supabase
            .from('referral_account')
            .select(
              'id, created_at, referral_code, is_approved, is_blocked',
            )
            .order('created_at', ascending: false),
        _supabase
            .from('user_info')
            .select('id, name, role, institute, academic_year, academic_level'),
      ]);

      final userInfoMap = <String, Map<String, dynamic>>{
        for (final row in results[1] as List)
          (row as Map<String, dynamic>)['id'] as String: row,
      };

      final accounts = (results[0] as List).map((e) {
        final row = e as Map<String, dynamic>;
        final info = userInfoMap[row['id'] as String] ?? {};
        return ReferralAccountEntry.fromJson({...row, 'user_info': info});
      }).toList();

      setState(() {
        _accounts = accounts;
        _loading = false;
      });
    } on PostgrestException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _setApproved(ReferralAccountEntry account) async {
    // Optimistic
    setState(() {
      account.isApproved = true;
      account.isBlocked = false;
    });
    try {
      await _supabase
          .from('referral_account')
          .update({'is_approved': true, 'is_blocked': false})
          .eq('id', account.id);
    } on PostgrestException catch (e) {
      setState(() {
        account.isApproved = false;
      });
      _showErrorSnackbar(e.message);
    }
  }

  Future<void> _setBlocked(ReferralAccountEntry account, bool blocked) async {
    final prevBlocked = account.isBlocked;
    setState(() => account.isBlocked = blocked);
    try {
      await _supabase
          .from('referral_account')
          .update({'is_blocked': blocked})
          .eq('id', account.id);
    } on PostgrestException catch (e) {
      setState(() => account.isBlocked = prevBlocked);
      _showErrorSnackbar(e.message);
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Counts ─────────────────────────────────────────────────────────────────

  int get _approvedCount =>
      _accounts.where((a) => a.isApproved && !a.isBlocked).length;
  int get _pendingCount =>
      _accounts.where((a) => !a.isApproved && !a.isBlocked).length;
  int get _blockedCount => _accounts.where((a) => a.isBlocked).length;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          if (_error != null) _buildErrorBanner(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF1A1A1A),
          strokeWidth: 1.5,
        ),
      );
    }
    if (_accounts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline,
              size: 40,
              color: _textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            const Text(
              'No accounts found',
              style: TextStyle(color: _textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return _buildTable();
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Referral Accounts',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _loading ? 'Loading…' : '${_accounts.length} accounts',
                style: const TextStyle(fontSize: 13, color: _textSecondary),
              ),
            ],
          ),
          const Spacer(),
          if (!_loading) ...[
            StatChip(
              label: 'Approved',
              value: '$_approvedCount',
              color: _positive,
            ),
            const SizedBox(width: 10),
            StatChip(
              label: 'Pending',
              value: '$_pendingCount',
              color: _warning,
            ),
            const SizedBox(width: 10),
            StatChip(
              label: 'Blocked',
              value: '$_blockedCount',
              color: _errorColor,
            ),
            const SizedBox(width: 12),
          ],
          HoverIconButton(
            icon: Icons.refresh_rounded,
            onTap: _fetchAccounts,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      color: _errorLight,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: _errorColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(fontSize: 12, color: _errorColor),
            ),
          ),
          TextButton(
            onPressed: _fetchAccounts,
            child: const Text(
              'Retry',
              style: TextStyle(
                fontSize: 12,
                color: _errorColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Table ──────────────────────────────────────────────────────────────────

  Widget _buildTable() {
    return Column(
      children: [
        _buildTableHeader(),
        Container(height: 1, color: _border),
        Expanded(
          child: ListView.separated(
            itemCount: _accounts.length,
            separatorBuilder: (_, _) =>
                Container(height: 1, color: _border.withValues(alpha: 0.6)),
            itemBuilder: (_, i) => _buildTableRow(_accounts[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Container(
      color: _surface,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      child: const Row(
        children: [
          HeaderCell('Name', flex: 3),
          HeaderCell('Code', flex: 2),
          HeaderCell('Institute', flex: 3),
          HeaderCell('Role', flex: 2),
          HeaderCell('Year', flex: 1),
          // HeaderCell('Joined', flex: 2),
          HeaderCell('Status', flex: 2),
          HeaderCell('Actions', flex: 3, align: TextAlign.right),
        ],
      ),
    );
  }

  Widget _buildTableRow(ReferralAccountEntry account) {
    return Container(
      color: _surface,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
      child: Row(
        children: [
          // Name + initials avatar
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _textPrimary,
                  ),
                ),
                if (account.academicLevel != null)
                  Text(
                    account.academicLevel!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: _textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          // Referral code
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: _accentLight,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                account.referralCode,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                  letterSpacing: 0.7,
                ),
              ),
            ),
          ),
          // Institute
          Expanded(
            flex: 3,
            child: Text(
              account.institute ?? '—',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: _textSecondary),
            ),
          ),
          // Role
          Expanded(
            flex: 2,
            child: Text(
              account.role,
              style: const TextStyle(fontSize: 12, color: _textSecondary),
            ),
          ),
          // Academic year
          Expanded(
            flex: 1,
            child: Text(
              account.academicYear != null ? 'Y${account.academicYear}' : '—',
              style: const TextStyle(fontSize: 12, color: _textSecondary),
            ),
          ),
          // Joined date
          // Expanded(
          //   flex: 2,
          //   child: Text(
          //     '${account.createdAt.day}/${account.createdAt.month}/${account.createdAt.year}',
          //     style: const TextStyle(fontSize: 12, color: _textSecondary),
          //   ),
          // ),
          // Status badge
          Expanded(
            flex: 2,
            child: _StatusBadge(account: account),
          ),
          // Action buttons
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!account.isApproved && !account.isBlocked)
                  _TableActionButton(
                    label: 'Approve',
                    icon: Icons.check_circle_outline_rounded,
                    color: _positive,
                    bgColor: _positiveLight,
                    onTap: () => _setApproved(account),
                  ),
                if (!account.isApproved && !account.isBlocked)
                  const SizedBox(width: 6),
                if (!account.isBlocked)
                  _TableActionButton(
                    label: 'Block',
                    icon: Icons.block_rounded,
                    color: _errorColor,
                    bgColor: _errorLight,
                    onTap: () => _setBlocked(account, true),
                  )
                else
                  _TableActionButton(
                    label: 'Unblock',
                    icon: Icons.lock_open_outlined,
                    color: _warning,
                    bgColor: _warningLight,
                    onTap: () => _setBlocked(account, false),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Small reusable widgets ───────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final ReferralAccountEntry account;
  const _StatusBadge({required this.account});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final Color dot;
    final String label = account.statusLabel;

    if (account.isBlocked) {
      bg = const Color(0xFFFEF2F2);
      fg = const Color(0xFFDC2626);
      dot = const Color(0xFFDC2626);
    } else if (account.isApproved) {
      bg = const Color(0xFFECF5F0);
      fg = const Color(0xFF2E7D5E);
      dot = const Color(0xFF2E7D5E);
    } else {
      bg = const Color(0xFFFDF3E3);
      fg = const Color(0xFFB45309);
      dot = const Color(0xFFB45309);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _TableActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;
  const _TableActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  State<_TableActionButton> createState() => _TableActionButtonState();
}

class _TableActionButtonState extends State<_TableActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _hovered
                  ? widget.color.withValues(alpha: 0.12)
                  : widget.bgColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _hovered
                    ? widget.color.withValues(alpha: 0.35)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 13, color: widget.color),
                const SizedBox(width: 5),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: widget.color,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

