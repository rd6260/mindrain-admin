import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _supabase = Supabase.instance.client;

// ─── Models ───────────────────────────────────────────────────────────────────

class RegistrationEvent {
  final String id;
  final String title;
  final String codeName;

  RegistrationEvent({
    required this.id,
    required this.title,
    required this.codeName,
  });

  factory RegistrationEvent.fromJson(Map<String, dynamic> json) =>
      RegistrationEvent(
        id: json['id'] as String,
        title: json['title'] as String,
        codeName: json['code_name'] as String,
      );
}

class RegistrationMember {
  final String id;
  final String name;
  final String email;
  final String institute;
  final int academicYear;
  final String instituteId;
  final String? phone;
  final String? code;

  RegistrationMember({
    required this.id,
    required this.name,
    required this.email,
    required this.institute,
    required this.academicYear,
    required this.instituteId,
    this.phone,
    this.code,
  });

  factory RegistrationMember.fromJson(Map<String, dynamic> json) =>
      RegistrationMember(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        institute: json['institute'] as String,
        academicYear: json['academic_year'] as int,
        instituteId: json['institute_id'] as String,
        phone: json['phone'] as String?,
        code: json['code'] as String?,
      );
}

class RegistrationUser {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? role;
  final String? institute;
  final int? academicYear;
  final String? academicLevel;

  RegistrationUser({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.role,
    this.institute,
    this.academicYear,
    this.academicLevel,
  });

  factory RegistrationUser.fromJson(Map<String, dynamic> json) =>
      RegistrationUser(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Unknown',
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        role: json['role'] as String?,
        institute: json['institute'] as String?,
        academicYear: json['academic_year'] as int?,
        academicLevel: json['academic_level'] as String?,
      );
}

class RegistrationPayment {
  final String paymentId;
  final String registrationId;
  final String amount;
  final String currency;
  final String status;
  final String? method;

  RegistrationPayment({
    required this.paymentId,
    required this.registrationId,
    required this.amount,
    required this.currency,
    required this.status,
    this.method,
  });

  factory RegistrationPayment.fromJson(Map<String, dynamic> json) =>
      RegistrationPayment(
        paymentId: json['payment_id'] as String,
        registrationId: json['registration_id'] as String,
        amount: json['amount'] as String,
        currency: json['currency'] as String,
        status: json['status'] as String,
        method: json['method'] as String?,
      );
}

class Registration {
  final String id;
  final String registrationBy;
  final String eventId;
  final String group;
  final String category;
  final String teamType;
  final DateTime createdAt;
  final String country;
  final bool paid;
  final String teamId;
  final String? referralUsed;

  // Joined
  RegistrationUser? user;
  RegistrationEvent? event;
  List<RegistrationMember> members;
  RegistrationPayment? payment;

  Registration({
    required this.id,
    required this.registrationBy,
    required this.eventId,
    required this.group,
    required this.category,
    required this.teamType,
    required this.createdAt,
    required this.country,
    required this.paid,
    required this.teamId,
    this.referralUsed,
    this.user,
    this.event,
    this.members = const [],
    this.payment,
  });

  factory Registration.fromJson(Map<String, dynamic> json) => Registration(
    id: json['id'] as String,
    registrationBy: json['registration_by'] as String,
    eventId: json['event_id'] as String,
    group: json['group'] as String,
    category: json['category'] as String,
    teamType: json['team_type'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    country: json['country'] as String,
    paid: json['paid'] as bool,
    teamId: json['team_id'] as String,
    referralUsed: json['referral_used'] as String?,
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class RegistrationsPage extends StatefulWidget {
  const RegistrationsPage({super.key});

  @override
  State<RegistrationsPage> createState() => _RegistrationsPageState();
}

class _RegistrationsPageState extends State<RegistrationsPage> {
  List<Registration> _all = [];
  List<Registration> _filtered = [];
  bool _loading = true;
  String? _error;

  // Filters
  final _searchController = TextEditingController();
  String _eventFilter = '';
  String _groupFilter = '';
  String _typeFilter = '';
  String _paidFilter = '';

  // Sort
  String _sortKey = 'created_at';
  bool _sortAsc = false;

  // ── Colours ────────────────────────────────────────────────────────────────
  static const _bg = Color(0xFFF7F7F5);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4E4E0);
  static const _textPrimary = Color(0xFF1A1A1A);
  static const _textSecondary = Color(0xFF8A8A85);
  static const _accentLight = Color(0xFFF0F0EE);
  static const _positive = Color(0xFF2E7D5E);
  static const _warning = Color(0xFFB45309);
  static const _positiveLight = Color(0xFFECF5F0);
  static const _warningLight = Color(0xFFFDF3E3);
  static const _errorColor = Color(0xFFDC2626);
  static const _errorLight = Color(0xFFFEF2F2);
  static const _infoColor = Color(0xFF1D4ED8);
  static const _infoLight = Color(0xFFEFF6FF);

  @override
  void initState() {
    super.initState();
    _fetchData();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _fetchData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _supabase
            .from('registrations')
            .select()
            .order('created_at', ascending: false),
        _supabase.from('events').select('id, title, code_name'),
        _supabase
            .from('user_info')
            .select('id, name, role, institute, academic_year, academic_level'),
        _supabase
            .from('members')
            .select(
              'id, registration_id, name, email, institute, academic_year, institute_id, phone, code',
            ),
        _supabase
            .from('payments')
            .select('payment_id, registration_id, amount, currency, status, method')
            .eq('status', 'paid'),
      ]);

      final eventMap = <String, RegistrationEvent>{
        for (final e in results[1] as List)
          (e as Map<String, dynamic>)['id'] as String:
              RegistrationEvent.fromJson(e),
      };

      final userMap = <String, RegistrationUser>{
        for (final u in results[2] as List)
          (u as Map<String, dynamic>)['id'] as String:
              RegistrationUser.fromJson(u),
      };

      final membersByReg = <String, List<RegistrationMember>>{};
      for (final m in results[3] as List) {
        final row = m as Map<String, dynamic>;
        final regId = row['registration_id'] as String;
        membersByReg.putIfAbsent(regId, () => []);
        membersByReg[regId]!.add(RegistrationMember.fromJson(row));
      }

      // Latest captured payment per registration
      final paymentMap = <String, RegistrationPayment>{};
      for (final p in results[4] as List) {
        final row = p as Map<String, dynamic>;
        final regId = row['registration_id'] as String;
        // keep first found (already filtered to captured)
        paymentMap.putIfAbsent(regId, () => RegistrationPayment.fromJson(row));
      }

      final registrations = (results[0] as List).map((e) {
        final reg = Registration.fromJson(e as Map<String, dynamic>);
        reg.user = userMap[reg.registrationBy];
        reg.event = eventMap[reg.eventId];
        reg.members = membersByReg[reg.id] ?? [];
        reg.payment = paymentMap[reg.id];
        return reg;
      }).toList();

      setState(() {
        _all = registrations;
        _applyFilters();
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

  void _applyFilters() {
    final q = _searchController.text.toLowerCase();
    var list = _all.where((r) {
      if (q.isNotEmpty) {
        final nameMatch = r.user?.name.toLowerCase().contains(q) ?? false;
        final teamMatch = r.teamId.toLowerCase().contains(q);
        final eventMatch = r.event?.title.toLowerCase().contains(q) ?? false;
        final memberMatch = r.members.any(
          (m) => m.name.toLowerCase().contains(q),
        );
        if (!nameMatch && !teamMatch && !eventMatch && !memberMatch) {
          return false;
        }
      }
      if (_eventFilter.isNotEmpty && r.eventId != _eventFilter) return false;
      if (_groupFilter.isNotEmpty && r.group != _groupFilter) return false;
      if (_typeFilter.isNotEmpty && r.teamType != _typeFilter) return false;
      if (_paidFilter == 'paid' && !r.paid) return false;
      if (_paidFilter == 'unpaid' && r.paid) return false;
      return true;
    }).toList();

    list.sort((a, b) {
      dynamic va, vb;
      switch (_sortKey) {
        case 'name':
          va = a.user?.name ?? '';
          vb = b.user?.name ?? '';
        case 'paid':
          va = a.paid ? 1 : 0;
          vb = b.paid ? 1 : 0;
        default:
          va = _sortKey == 'created_at'
              ? a.createdAt.millisecondsSinceEpoch
              : '';
          vb = _sortKey == 'created_at'
              ? b.createdAt.millisecondsSinceEpoch
              : '';
      }
      final cmp = Comparable.compare(va as Comparable, vb as Comparable);
      return _sortAsc ? cmp : -cmp;
    });

    setState(() => _filtered = list);
  }

  void _setSort(String key) {
    setState(() {
      if (_sortKey == key) {
        _sortAsc = !_sortAsc;
      } else {
        _sortKey = key;
        _sortAsc = false;
      }
    });
    _applyFilters();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _fmtDate(DateTime d) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} ${d.year}, $h:$m';
  }

  String _fmtAmount(String amount, String currency) {
    // amount is typically in paise (smallest unit) for INR
    try {
      final val = int.parse(amount);
      final major = val / 100;
      final symbol = currency.toUpperCase() == 'INR' ? '₹' : currency;
      return '$symbol${major.toStringAsFixed(0)}';
    } catch (_) {
      return amount;
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  List<RegistrationEvent> get _uniqueEvents {
    final seen = <String>{};
    return _all
        .where((r) => r.event != null && seen.add(r.event!.id))
        .map((r) => r.event!)
        .toList();
  }

  // ── Popups ─────────────────────────────────────────────────────────────────

  void _showUserPopup(RegistrationUser user) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (_) => _InfoDialog(
        avatar: _initials(user.name),
        title: user.name,
        subtitle: user.email ?? '—',
        rows: [
          _PopupRow('Role', user.role ?? '—'),
          _PopupRow('Institute', user.institute ?? '—'),
          _PopupRow(
            'Academic Year',
            user.academicYear != null ? 'Year ${user.academicYear}' : '—',
          ),
          _PopupRow('Academic Level', user.academicLevel ?? '—'),
        ],
      ),
    );
  }

  void _showEventPopup(RegistrationEvent event) {
    final total = _all.where((r) => r.eventId == event.id).length;
    final paid = _all.where((r) => r.eventId == event.id && r.paid).length;
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (_) => _InfoDialog(
        avatar: event.codeName.substring(0, event.codeName.length.clamp(0, 3)),
        avatarBg: _infoLight,
        avatarFg: _infoColor,
        title: event.title,
        subtitle: 'Code: ${event.codeName}',
        rows: [
          _PopupRow('Registrations', '$total total ($paid paid)'),
          _PopupRow('Code Name', event.codeName),
        ],
      ),
    );
  }

  void _showMembersPopup(Registration reg) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 420,
          constraints: const BoxConstraints(maxHeight: 560),
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
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.group_outlined,
                      size: 18,
                      color: Color(0xFF6D28D9),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Team Members',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${reg.teamId} · ${reg.members.length} member${reg.members.length != 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: _textSecondary,
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
              const SizedBox(height: 20),
              const Divider(color: _border, height: 1),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: reg.members.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final m = reg.members[i];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: _border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(
                            m.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          SelectableText(
                            '${m.email}${m.phone != null ? ' · ${m.phone}' : ''}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: _textSecondary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          SelectableText(
                            '${m.institute} · Year ${m.academicYear}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: _textSecondary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          SelectableText(
                            'ID: ${m.instituteId}${m.code != null ? ' · Code: ${m.code}' : ''}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: _textSecondary,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
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
          _buildFilterBar(),
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
    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.list_alt_outlined,
              size: 40,
              color: _textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            const Text(
              'No registrations found',
              style: TextStyle(color: _textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return _buildTable();
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
            onPressed: _fetchData,
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
    final paid = _filtered.where((r) => r.paid).length;
    final unpaid = _filtered.where((r) => !r.paid).length;
    return Container(
      color: _surface,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Registrations',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _loading
                    ? 'Loading…'
                    : '${_filtered.length} registration${_filtered.length != 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 13, color: _textSecondary),
              ),
            ],
          ),
          const Spacer(),
          if (!_loading) ...[
            _StatChip(label: 'Total', value: '${_filtered.length}'),
            const SizedBox(width: 12),
            _StatChip(
              label: 'Paid',
              value: '$paid',
              color: _positive,
              bgColor: _positiveLight,
            ),
            const SizedBox(width: 12),
            _StatChip(
              label: 'Unpaid',
              value: '$unpaid',
              color: _errorColor,
              bgColor: _errorLight,
            ),
            const SizedBox(width: 12),
          ],
          _HoverIconButton(
            icon: Icons.refresh_rounded,
            onTap: _fetchData,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  // ── Filter Bar ─────────────────────────────────────────────────────────────

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          // Search
          SizedBox(
            width: 220,
            height: 32,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 12, color: _textPrimary),
              decoration: InputDecoration(
                hintText: 'Search name, team ID…',
                hintStyle: const TextStyle(fontSize: 12, color: _textSecondary),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 15,
                  color: _textSecondary,
                ),
                filled: true,
                fillColor: _bg,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: _border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: _textSecondary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Event filter
          _FilterDropdown(
            value: _eventFilter,
            hint: 'All Events',
            items: [
              const DropdownMenuItem(value: '', child: Text('All Events')),
              ..._uniqueEvents.map(
                (e) => DropdownMenuItem(value: e.id, child: Text(e.title)),
              ),
            ],
            onChanged: (v) {
              setState(() => _eventFilter = v ?? '');
              _applyFilters();
            },
          ),
          const SizedBox(width: 10),
          _FilterDropdown(
            value: _groupFilter,
            hint: 'All Groups',
            items: const [
              DropdownMenuItem(value: '', child: Text('All Groups')),
              DropdownMenuItem(value: 'A', child: Text('Group A')),
              DropdownMenuItem(value: 'B', child: Text('Group B')),
            ],
            onChanged: (v) {
              setState(() => _groupFilter = v ?? '');
              _applyFilters();
            },
          ),
          const SizedBox(width: 10),
          _FilterDropdown(
            value: _typeFilter,
            hint: 'All Types',
            items: const [
              DropdownMenuItem(value: '', child: Text('All Types')),
              DropdownMenuItem(value: 'solo', child: Text('Solo')),
              DropdownMenuItem(value: 'group', child: Text('Group')),
            ],
            onChanged: (v) {
              setState(() => _typeFilter = v ?? '');
              _applyFilters();
            },
          ),
          const SizedBox(width: 14),
          // Paid filter badges
          _PaidBadge(
            label: 'All',
            active: _paidFilter == '',
            color: _textPrimary,
            bgActive: _textPrimary,
            onTap: () {
              setState(() => _paidFilter = '');
              _applyFilters();
            },
          ),
          const SizedBox(width: 6),
          _PaidBadge(
            label: 'Paid',
            active: _paidFilter == 'paid',
            color: _positive,
            bgActive: _positive,
            bgInactive: _positiveLight,
            onTap: () {
              setState(() => _paidFilter = 'paid');
              _applyFilters();
            },
          ),
          const SizedBox(width: 6),
          _PaidBadge(
            label: 'Unpaid',
            active: _paidFilter == 'unpaid',
            color: _errorColor,
            bgActive: _errorColor,
            bgInactive: _errorLight,
            onTap: () {
              setState(() => _paidFilter = 'unpaid');
              _applyFilters();
            },
          ),
        ],
      ),
    );
  }

  // ── Table ──────────────────────────────────────────────────────────────────

  Widget _buildTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width,
          ),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(_surface),
            dataRowColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.hovered)
                  ? _accentLight
                  : _surface,
            ),
            headingRowHeight: 42,
            dataRowMinHeight: 56,
            dataRowMaxHeight: 56,
            horizontalMargin: 28,
            columnSpacing: 20,
            dividerThickness: 1,
            border: TableBorder(
              horizontalInside: BorderSide(
                color: _border.withValues(alpha: 0.6),
              ),
              bottom: const BorderSide(color: _border),
            ),
            columns: [
              _col('Registered By', 'name'),
              _col('Team ID', 'team_id', sortable: false),
              _col('Group / Cat / Type', 'group', sortable: false),
              _col('Paid', 'paid'),
              _col('Members', 'members', sortable: false),
              _col('Created At', 'created_at'),
            ],
            rows: _filtered.map(_buildRow).toList(),
          ),
        ),
      ),
    );
  }

  DataColumn _col(
    String label,
    String key, {
    bool numeric = false,
    bool sortable = true,
  }) {
    return DataColumn(
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _textSecondary,
          letterSpacing: 0.8,
        ),
      ),
      numeric: numeric,
      onSort: sortable ? (_, __) => _setSort(key) : null,
    );
  }

  DataRow _buildRow(Registration r) {
    return DataRow(
      cells: [
        // ── Registered By ──────────────────────────────────────────────────
        DataCell(
          SizedBox(
            width: 130,
            child: GestureDetector(
              onTap: r.user != null ? () => _showUserPopup(r.user!) : null,
              child: Text(
                r.user?.name ?? 'Unknown',
                maxLines: 1,
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
        ),

        // ── Team ID ────────────────────────────────────────────────────────
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _accentLight,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              r.teamId,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                color: _textPrimary,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),

        // ── Group / Category / Type (combined) ─────────────────────────────
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Group — styled like paid/unpaid pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: r.group == 'A' ? _infoLight : const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon(
                    //   r.group == 'A' ? Icons.looks_one_outlined : Icons.looks_two_outlined,
                    //   size: 11,
                    //   color: r.group == 'A' ? _infoColor : const Color(0xFF6D28D9),
                    // ),
                    // const SizedBox(width: 4),
                    Text(
                      r.group,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: r.group == 'A' ? _infoColor : const Color(0xFF6D28D9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Category — muted chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _accentLight,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _border),
                ),
                child: Text(
                  'C${r.category}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Team Type — muted chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _accentLight,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _border),
                ),
                child: Text(
                  r.teamType[0].toUpperCase() + r.teamType.substring(1),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Paid ───────────────────────────────────────────────────────────
        DataCell(
          r.paid
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _positiveLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check, size: 11, color: _positive),
                      const SizedBox(width: 4),
                      Text(
                        r.payment != null
                            // ? _fmtAmount(r.payment!.amount, r.payment!.currency)
                            ? r.payment!.amount
                            : 'Paid',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _positive,
                        ),
                      ),
                    ],
                  ),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _errorLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close, size: 11, color: _errorColor),
                      SizedBox(width: 4),
                      Text(
                        'Unpaid',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _errorColor,
                        ),
                      ),
                    ],
                  ),
                ),
        ),

        // ── Members ────────────────────────────────────────────────────────
        DataCell(
          GestureDetector(
            onTap: r.members.isNotEmpty ? () => _showMembersPopup(r) : null,
            child: r.members.isEmpty
                ? const Text(
                    '—',
                    style: TextStyle(color: _textSecondary, fontSize: 12),
                  )
                : SizedBox(
                    width: 160,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ...r.members.take(2).map(
                          (m) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              m.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: _textPrimary,
                                decoration: TextDecoration.underline,
                                decorationColor: _border,
                              ),
                            ),
                          ),
                        ),
                        if (r.members.length > 2)
                          Text(
                            '+${r.members.length - 2} more',
                            style: const TextStyle(
                              fontSize: 10,
                              color: _textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ),

        // ── Created At ─────────────────────────────────────────────────────
        DataCell(
          Text(
            _fmtDate(r.createdAt),
            style: const TextStyle(
              fontSize: 12,
              color: _textSecondary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Small reusable widgets ───────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bgColor;

  const _StatChip({
    required this.label,
    required this.value,
    this.color = const Color(0xFF1A1A1A),
    this.bgColor = const Color(0xFFF0F0EE),
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color.withValues(alpha: 0.6),
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );
}

class _HoverIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _HoverIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  State<_HoverIconButton> createState() => _HoverIconButtonState();
}

class _HoverIconButtonState extends State<_HoverIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: widget.tooltip,
    child: MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFFF0F0EE) : const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE4E4E0)),
          ),
          child: Icon(
            widget.icon,
            size: 16,
            color: _hovered ? const Color(0xFF1A1A1A) : const Color(0xFF8A8A85),
          ),
        ),
      ),
    ),
  );
}

class _FilterDropdown extends StatelessWidget {
  final String value;
  final String hint;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: 32,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F7F5),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: const Color(0xFFE4E4E0)),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value.isEmpty ? '' : value,
        items: items,
        onChanged: onChanged,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF1A1A1A),
          fontFamily: 'sans-serif',
        ),
        icon: const Icon(
          Icons.keyboard_arrow_down,
          size: 16,
          color: Color(0xFF8A8A85),
        ),
        isDense: true,
      ),
    ),
  );
}

class _PaidBadge extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final Color bgActive;
  final Color bgInactive;
  final VoidCallback onTap;

  const _PaidBadge({
    required this.label,
    required this.active,
    required this.color,
    required this.bgActive,
    this.bgInactive = const Color(0xFFF0F0EE),
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? bgActive : bgInactive,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: active ? Colors.white : color,
        ),
      ),
    ),
  );
}

// ─── Info Dialog ──────────────────────────────────────────────────────────────

class _PopupRow {
  final String label;
  final String value;
  _PopupRow(this.label, this.value);
}

class _InfoDialog extends StatelessWidget {
  final String avatar;
  final Color avatarBg;
  final Color avatarFg;
  final String title;
  final String subtitle;
  final List<_PopupRow> rows;

  const _InfoDialog({
    required this.avatar,
    this.avatarBg = const Color(0xFFF0F0EE),
    this.avatarFg = const Color(0xFF1A1A1A),
    required this.title,
    required this.subtitle,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) => Dialog(
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
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: avatarBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    avatar,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: avatarFg,
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
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8A8A85),
                        letterSpacing: 0.4,
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
                  color: Color(0xFF8A8A85),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFE4E4E0), height: 1),
          const SizedBox(height: 18),
          ...rows.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      r.label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8A8A85),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SelectableText(
                      r.value,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
