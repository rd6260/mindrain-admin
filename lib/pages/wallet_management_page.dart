import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mindrain_admin/pages/wallet_shared_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Convenience getter
final _supabase = Supabase.instance.client;

// ─── Model ────────────────────────────────────────────────────────────────────

class ReferralAccount {
  final String id;
  final DateTime createdAt;
  final String referralCode;
  double earnedAmount;
  double redeemedAmount;

  // New fields from user_info join
  final String name;
  final String role;
  final String? institute;
  final int? academicYear;
  final String? academicLevel;

  ReferralAccount({
    required this.id,
    required this.createdAt,
    required this.referralCode,
    required this.earnedAmount,
    required this.redeemedAmount,
    required this.name,
    required this.role,
    this.institute,
    this.academicYear,
    this.academicLevel,
  });

  double get currentBalance => earnedAmount - redeemedAmount;

  factory ReferralAccount.fromJson(Map<String, dynamic> json) {
    // user_info comes back as a nested map from the join
    final info = json['user_info'] as Map<String, dynamic>? ?? {};
    return ReferralAccount(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      referralCode: json['referral_code'] as String,
      earnedAmount: (json['earned_amount'] as num).toDouble(),
      redeemedAmount: (json['redeemed_amount'] as num).toDouble(),
      name: info['name'] as String? ?? 'Unknown',
      role: info['role'] as String? ?? '—',
      institute: info['institute'] as String?,
      academicYear: info['academic_year'] as int?,
      academicLevel: info['academic_level'] as String?,
    );
  }
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class WalletManagementPage extends StatefulWidget {
  const WalletManagementPage({super.key});

  @override
  State<WalletManagementPage> createState() => _WalletManagementPageState();
}

class _WalletManagementPageState extends State<WalletManagementPage> {
  List<ReferralAccount> _accounts = [];
  ReferralAccount? _selectedAccount;
  bool _loading = true;
  String? _error;

  final _scrollController = ScrollController();

  // ── Colours ────────────────────────────────────────────────────────────────

  static const _bg = Color(0xFFF7F7F5);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4E4E0);
  static const _textPrimary = Color(0xFF1A1A1A);
  static const _textSecondary = Color(0xFF8A8A85);
  static const _accent = Color(0xFF1A1A1A);
  static const _accentLight = Color(0xFFF0F0EE);
  static const _positive = Color(0xFF2E7D5E);
  static const _warning = Color(0xFFB45309);
  static const _positiveLight = Color(0xFFECF5F0);
  static const _warningLight = Color(0xFFFDF3E3);
  static const _errorColor = Color(0xFFDC2626);

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
      // ── 1. Fetch both tables in parallel ──────────────────────────────────
      final results = await Future.wait([
        _supabase
            .from('referral_account')
            .select(
              'id, created_at, referral_code, earned_amount, redeemed_amount',
            )
            .eq('is_approved', true)
            .eq('is_blocked', false)
            .order('created_at', ascending: false),
        _supabase
            .from('user_info')
            .select('id, name, role, institute, academic_year, academic_level'),
      ]);

      // ── 2. Build a quick lookup map: id → user_info row ───────────────────
      final userInfoMap = <String, Map<String, dynamic>>{
        for (final row in results[1] as List)
          (row as Map<String, dynamic>)['id'] as String: row,
      };

      // ── 3. Merge and parse ────────────────────────────────────────────────
      final accounts = (results[0] as List).map((e) {
        final row = e as Map<String, dynamic>;
        final info = userInfoMap[row['id'] as String] ?? {};
        return ReferralAccount.fromJson({...row, 'user_info': info});
      }).toList();

      setState(() {
        _accounts = accounts;
        if (_selectedAccount != null) {
          _selectedAccount = _accounts
              .where((a) => a.id == _selectedAccount!.id)
              .firstOrNull;
        }
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

  /// Increments earned_amount or redeemed_amount by [amount] using a Supabase
  /// RPC call so the increment is atomic (no read-modify-write race condition).
  ///
  /// Falls back to a plain update if you prefer not to create the RPC.
  /// See comments below for both approaches.
  Future<void> _addAmount({
    required ReferralAccount account,
    required bool isEarned,
    required double amount,
  }) async {
    // ── Optimistic update ──────────────────────────────────────────────────
    setState(() {
      if (isEarned) {
        account.earnedAmount += amount;
      } else {
        account.redeemedAmount += amount;
      }
    });

    try {
      await _supabase.rpc(
        'increment_wallet',
        params: {
          'row_id': account.id,
          'col': isEarned ? 'earned_amount' : 'redeemed_amount',
          'delta': amount,
        },
      );
    } on PostgrestException catch (e) {
      // Roll back optimistic update
      setState(() {
        if (isEarned) {
          account.earnedAmount -= amount;
        } else {
          account.redeemedAmount -= amount;
        }
      });
      _showErrorSnackbar(e.message);
    } catch (e) {
      setState(() {
        if (isEarned) {
          account.earnedAmount -= amount;
        } else {
          account.redeemedAmount -= amount;
        }
      });
      _showErrorSnackbar(e.toString());
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

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _shortId(String id) => id.substring(0, 8).toUpperCase();

  String _fmt(double v) =>
      '₹${v.toStringAsFixed(2).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}';

  // ── Dialogs ────────────────────────────────────────────────────────────────

  void _showAmountDialog({
    required ReferralAccount account,
    required bool isEarned,
  }) {
    final controller = TextEditingController();
    final label = isEarned ? 'Add to Earned Amount' : 'Add to Redeemed Amount';
    final color = isEarned ? _positive : _warning;
    final lightColor = isEarned ? _positiveLight : _warningLight;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (_) => _AmountDialog(
        label: label,
        accentColor: color,
        accentLightColor: lightColor,
        referralCode: account.referralCode,
        controller: controller,
        onConfirm: (amount) =>
            _addAmount(account: account, isEarned: isEarned, amount: amount),
      ),
    );
  }

  // ─── User-info popup ──────────────────────────────────────────────────────────

  void _showUserInfoPopup(ReferralAccount account) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 40,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _accentLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        account.name.isNotEmpty
                            ? account.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          account.referralCode,
                          style: const TextStyle(
                            fontSize: 11,
                            color: _textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Divider(color: _border, height: 1),
              const SizedBox(height: 20),
              // ── Info rows ────────────────────────────────────────────────
              _InfoRow(label: 'Role', value: account.role),
              _InfoRow(label: 'Institute', value: account.institute ?? '—'),
              _InfoRow(
                label: 'Academic Year',
                value: account.academicYear?.toString() ?? '—',
              ),
              _InfoRow(
                label: 'Academic Level',
                value: account.academicLevel ?? '—',
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

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
              Icons.account_balance_wallet_outlined,
              size: 40,
              color: _textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'No accounts found',
              style: TextStyle(color: _textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: _buildTable()),
        if (_selectedAccount != null) ...[
          Container(width: 1, color: _border),
          _buildDetailPanel(_selectedAccount!),
        ],
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFEF2F2),
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
              Text(
                'Wallet Management',
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
                style: TextStyle(fontSize: 13, color: _textSecondary),
              ),
            ],
          ),
          const Spacer(),
          if (!_loading) ...[
            StatChip(
              label: 'Total Earned',
              value: _fmt(_accounts.fold(0, (s, a) => s + a.earnedAmount)),
              color: _positive,
            ),
            const SizedBox(width: 12),
            StatChip(
              label: 'Total Balance',
              value: _fmt(_accounts.fold(0, (s, a) => s + a.currentBalance)),
              color: _accent,
            ),
            const SizedBox(width: 12),
          ],
          // Refresh button
          HoverIconButton(
            icon: Icons.refresh_rounded,
            onTap: _fetchAccounts,
            tooltip: 'Refresh',
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
            controller: _scrollController,
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
      child: Row(
        children: [
          HeaderCell('Name', flex: 3),
          HeaderCell('Referral Code', flex: 2),
          HeaderCell('Earned', flex: 2, align: TextAlign.right),
          HeaderCell('Redeemed', flex: 2, align: TextAlign.right),
          HeaderCell('Balance', flex: 2, align: TextAlign.right),
          // _HeaderCell('Created', flex: 2),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildTableRow(ReferralAccount account) {
    final isSelected = _selectedAccount?.id == account.id;
    final balance = account.currentBalance;

    return GestureDetector(
      onTap: () => setState(() {
        _selectedAccount = isSelected ? null : account;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        color: isSelected ? _accentLight : _surface,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: GestureDetector(
                onTap: () => _showUserInfoPopup(account),
                child: Text(
                  account.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _textPrimary,
                    decoration: TextDecoration.underline,
                    decorationColor: _textSecondary,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _accentLight,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  account.referralCode,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _fmt(account.earnedAmount),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  color: _textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _fmt(account.redeemedAmount),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  color: _textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _fmt(balance),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: balance > 0 ? _positive : _textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            // Expanded(
            //   flex: 2,
            //   child: Text(
            //     '${account.createdAt.day}/${account.createdAt.month}/${account.createdAt.year}',
            //     style: TextStyle(fontSize: 12, color: _textSecondary),
            //   ),
            // ),
            SizedBox(
              width: 40,
              child: isSelected
                  ? Icon(Icons.chevron_right, size: 18, color: _textPrimary)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Detail Panel ───────────────────────────────────────────────────────────

  Widget _buildDetailPanel(ReferralAccount account) {
    return Container(
      width: 300,
      color: _surface,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  account.referralCode,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _selectedAccount = null),
                child: Icon(Icons.close, size: 18, color: _textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _shortId(account.id),
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: _textSecondary,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _textPrimary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Balance',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.5),
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _fmt(account.currentBalance),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Earned',
                  value: _fmt(account.earnedAmount),
                  color: _positive,
                  bgColor: _positiveLight,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  label: 'Redeemed',
                  value: _fmt(account.redeemedAmount),
                  color: _warning,
                  bgColor: _warningLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'ACTIONS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _textSecondary,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          _ActionButton(
            icon: Icons.add_circle_outline_rounded,
            label: 'Add Earned Amount',
            color: _positive,
            bgColor: _positiveLight,
            onTap: () => _showAmountDialog(account: account, isEarned: true),
          ),
          const SizedBox(height: 10),
          _ActionButton(
            icon: Icons.remove_circle_outline_rounded,
            label: 'Add Redeemed Amount',
            color: _warning,
            bgColor: _warningLight,
            onTap: () => _showAmountDialog(account: account, isEarned: false),
          ),
          const Spacer(),
          Divider(color: _border),
          const SizedBox(height: 8),
          Text(
            'Created ${account.createdAt.day}/${account.createdAt.month}/${account.createdAt.year}',
            style: TextStyle(fontSize: 11, color: _textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable widgets ─────────────────────────────────────────────────────────



class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bgColor;
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color.withValues(alpha: 0.7),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _hovered
              ? widget.color.withValues(alpha: 0.12)
              : widget.bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _hovered
                ? widget.color.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(widget.icon, size: 16, color: widget.color),
            const SizedBox(width: 10),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 13,
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


// ─── Amount Dialog ────────────────────────────────────────────────────────────

class _AmountDialog extends StatefulWidget {
  final String label;
  final Color accentColor;
  final Color accentLightColor;
  final String referralCode;
  final TextEditingController controller;
  final void Function(double) onConfirm;

  const _AmountDialog({
    required this.label,
    required this.accentColor,
    required this.accentLightColor,
    required this.referralCode,
    required this.controller,
    required this.onConfirm,
  });

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  String? _error;

  void _submit() {
    final raw = widget.controller.text.trim();
    final value = double.tryParse(raw);
    if (value == null || value <= 0) {
      setState(() => _error = 'Enter a valid positive amount');
      return;
    }
    widget.onConfirm(value);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 40,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.accentLightColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 18,
                    color: widget.accentColor,
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
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        widget.referralCode,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8A8A85),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Amount',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF8A8A85),
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: widget.controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              onSubmitted: (_) => _submit(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
              decoration: InputDecoration(
                prefixText: '₹  ',
                prefixStyle: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: widget.accentColor,
                ),
                errorText: _error,
                hintText: '0.00',
                hintStyle: const TextStyle(
                  fontSize: 20,
                  color: Color(0xFFCCCCC8),
                  fontWeight: FontWeight.w400,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                filled: true,
                fillColor: const Color(0xFFF7F7F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: widget.accentColor.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFFE53E3E),
                    width: 1.5,
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFFE53E3E),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      backgroundColor: const Color(0xFFF7F7F5),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Color(0xFF8A8A85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.accentColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── _InfoRow widget (add near the other small widgets at the bottom) ─────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8A8A85),
              letterSpacing: 0.4,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ),
      ],
    ),
  );
}
