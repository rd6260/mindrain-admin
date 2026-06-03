import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mindrain_admin/core/theme.dart';
import 'package:mindrain_admin/features/registrations/bloc/registrations_bloc.dart';
import 'package:mindrain_admin/features/registrations/data/model.dart';
import 'package:mindrain_admin/features/registrations/widgets/filter_dropdown.dart';
import 'package:mindrain_admin/features/registrations/widgets/hover_icon_button.dart';
import 'package:mindrain_admin/features/registrations/widgets/info_dialog.dart';
import 'package:mindrain_admin/features/registrations/widgets/paid_badge.dart';
import 'package:mindrain_admin/features/registrations/widgets/stat_ship.dart';
import 'package:mindrain_admin/features/registrations/widgets/edit_registration_dialog.dart';

class RegistrationsPage extends StatelessWidget {
  const RegistrationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RegistrationsBloc()..add(FetchRegistrations()),
      child: const _RegistrationsPageView(),
    );
  }
}

class _RegistrationsPageView extends StatefulWidget {
  const _RegistrationsPageView();

  @override
  State<_RegistrationsPageView> createState() => _RegistrationsPageViewState();
}

class _RegistrationsPageViewState extends State<_RegistrationsPageView> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      context.read<RegistrationsBloc>().add(SearchQueryChanged(_searchController.text));
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _fmtDate(DateTime d) {
    final months = [
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
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} ${d.year}, $h:$m';
  }



  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  List<RegistrationEvent> _getUniqueEvents(List<Registration> all) {
    final seen = <String>{};
    return all
        .where((r) => r.event != null && seen.add(r.event!.id))
        .map((r) => r.event!)
        .toList();
  }

  // ── Popups ─────────────────────────────────────────────────────────────────

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
                            color: CustomTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${reg.teamId} · ${reg.members.length} member${reg.members.length != 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: CustomTheme.textSecondary,
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
                      color: CustomTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: CustomTheme.border, height: 1),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: reg.members.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final m = reg.members[i];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: CustomTheme.border),
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
                              color: CustomTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          SelectableText(
                            '${m.email}${m.phone != null ? ' · ${m.phone}' : ''}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: CustomTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          SelectableText(
                            '${m.institute} · Year ${m.academicYear}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: CustomTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          SelectableText(
                            'ID: ${m.instituteId}${m.code != null ? ' · Code: ${m.code}' : ''}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: CustomTheme.textSecondary,
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
    return BlocBuilder<RegistrationsBloc, RegistrationsState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: CustomTheme.bg,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(state),
              _buildFilterBar(state),
              if (state.error != null) _buildErrorBanner(state),
              Expanded(child: _buildBody(state)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(RegistrationsState state) {
    if (state.status == RegistrationsStatus.loading || state.status == RegistrationsStatus.initial) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF1A1A1A),
          strokeWidth: 1.5,
        ),
      );
    }
    if (state.filteredRegistrations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.list_alt_outlined,
              size: 40,
              color: CustomTheme.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            const Text(
              'No registrations found',
              style: TextStyle(color: CustomTheme.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return _buildTable(state);
  }

  Widget _buildErrorBanner(RegistrationsState state) {
    return Container(
      width: double.infinity,
      color: CustomTheme.errorLight,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            size: 16,
            color: CustomTheme.errorColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.error!,
              style: const TextStyle(
                fontSize: 12,
                color: CustomTheme.errorColor,
              ),
            ),
          ),
          TextButton(
            onPressed: () => context.read<RegistrationsBloc>().add(FetchRegistrations()),
            child: const Text(
              'Retry',
              style: TextStyle(
                fontSize: 12,
                color: CustomTheme.errorColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(RegistrationsState state) {
    final paid = state.filteredRegistrations.where((r) => r.paid).length;
    final unpaid = state.filteredRegistrations.where((r) => !r.paid).length;
    return Container(
      color: CustomTheme.surface,
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
                  color: CustomTheme.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                state.status == RegistrationsStatus.loading || state.status == RegistrationsStatus.initial
                    ? 'Loading…'
                    : '${state.filteredRegistrations.length} registration${state.filteredRegistrations.length != 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 13,
                  color: CustomTheme.textSecondary,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (state.status != RegistrationsStatus.loading && state.status != RegistrationsStatus.initial) ...[
            StatChip(label: 'Total', value: '${state.filteredRegistrations.length}'),
            const SizedBox(width: 12),
            StatChip(
              label: 'Paid',
              value: '$paid',
              color: CustomTheme.positive,
              bgColor: CustomTheme.positiveLight,
            ),
            const SizedBox(width: 12),
            StatChip(
              label: 'Unpaid',
              value: '$unpaid',
              color: CustomTheme.errorColor,
              bgColor: CustomTheme.errorLight,
            ),
            const SizedBox(width: 12),
          ],
          HoverIconButton(
            icon: Icons.refresh_rounded,
            onTap: () => context.read<RegistrationsBloc>().add(FetchRegistrations()),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  // ── Filter Bar ─────────────────────────────────────────────────────────────

  Widget _buildFilterBar(RegistrationsState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
      decoration: const BoxDecoration(
        color: CustomTheme.surface,
        border: Border(bottom: BorderSide(color: CustomTheme.border)),
      ),
      child: Row(
        children: [
          // Search
          SizedBox(
            width: 220,
            height: 32,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(
                fontSize: 12,
                color: CustomTheme.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Search name, team ID…',
                hintStyle: const TextStyle(
                  fontSize: 12,
                  color: CustomTheme.textSecondary,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 15,
                  color: CustomTheme.textSecondary,
                ),
                filled: true,
                fillColor: CustomTheme.bg,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: CustomTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: CustomTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(
                    color: CustomTheme.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Event filter
          FilterDropdown(
            value: state.eventFilter,
            hint: 'All Events',
            items: [
              const DropdownMenuItem(value: '', child: Text('All Events')),
              ..._getUniqueEvents(state.allRegistrations).map(
                (e) => DropdownMenuItem(value: e.id, child: Text(e.title)),
              ),
            ],
            onChanged: (v) {
              context.read<RegistrationsBloc>().add(EventFilterChanged(v ?? ''));
            },
          ),
          const SizedBox(width: 10),
          FilterDropdown(
            value: state.groupFilter,
            hint: 'All Groups',
            items: const [
              DropdownMenuItem(value: '', child: Text('All Groups')),
              DropdownMenuItem(value: 'A', child: Text('Group A')),
              DropdownMenuItem(value: 'B', child: Text('Group B')),
            ],
            onChanged: (v) {
              context.read<RegistrationsBloc>().add(GroupFilterChanged(v ?? ''));
            },
          ),
          const SizedBox(width: 10),
          FilterDropdown(
            value: state.typeFilter,
            hint: 'All Types',
            items: const [
              DropdownMenuItem(value: '', child: Text('All Types')),
              DropdownMenuItem(value: 'solo', child: Text('Solo')),
              DropdownMenuItem(value: 'group', child: Text('Group')),
            ],
            onChanged: (v) {
              context.read<RegistrationsBloc>().add(TypeFilterChanged(v ?? ''));
            },
          ),
          const SizedBox(width: 14),
          // Paid filter badges
          PaidBadge(
            label: 'All',
            active: state.paidFilter == '',
            color: CustomTheme.textPrimary,
            bgActive: CustomTheme.textPrimary,
            onTap: () {
              context.read<RegistrationsBloc>().add(PaidFilterChanged(''));
            },
          ),
          const SizedBox(width: 6),
          PaidBadge(
            label: 'Paid',
            active: state.paidFilter == 'paid',
            color: CustomTheme.positive,
            bgActive: CustomTheme.positive,
            bgInactive: CustomTheme.positiveLight,
            onTap: () {
              context.read<RegistrationsBloc>().add(PaidFilterChanged('paid'));
            },
          ),
          const SizedBox(width: 6),
          PaidBadge(
            label: 'Unpaid',
            active: state.paidFilter == 'unpaid',
            color: CustomTheme.errorColor,
            bgActive: CustomTheme.errorColor,
            bgInactive: CustomTheme.errorLight,
            onTap: () {
              context.read<RegistrationsBloc>().add(PaidFilterChanged('unpaid'));
            },
          ),
        ],
      ),
    );
  }

  // ── Table ──────────────────────────────────────────────────────────────────

  Widget _buildTable(RegistrationsState state) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width,
          ),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(CustomTheme.surface),
            dataRowColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.hovered)
                  ? CustomTheme.accentLight
                  : CustomTheme.surface,
            ),
            headingRowHeight: 42,
            dataRowMinHeight: 56,
            dataRowMaxHeight: 56,
            horizontalMargin: 28,
            columnSpacing: 20,
            dividerThickness: 1,
            border: TableBorder(
              horizontalInside: BorderSide(
                color: CustomTheme.border.withValues(alpha: 0.6),
              ),
              bottom: const BorderSide(color: CustomTheme.border),
            ),
            columns: [
              _col('Registered By', 'name', state),
              _col('Team ID', 'team_id', state, sortable: false),
              _col('Group / Cat / Type', 'group', state, sortable: false),
              _col('Paid', 'paid', state),
              _col('Members', 'members', state, sortable: false),
              _col('Created At', 'created_at', state),
              _col('Actions', 'actions', state, sortable: false),
            ],
            rows: state.filteredRegistrations.map(_buildRow).toList(),
          ),
        ),
      ),
    );
  }

  DataColumn _col(
    String label,
    String key,
    RegistrationsState state, {
    bool numeric = false,
    bool sortable = true,
  }) {
    return DataColumn(
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: CustomTheme.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
      numeric: numeric,
      onSort: sortable ? (_, _) => context.read<RegistrationsBloc>().add(SortChanged(key)) : null,
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
                  color: CustomTheme.textPrimary,
                  decoration: TextDecoration.underline,
                  decorationColor: CustomTheme.textSecondary,
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
              color: CustomTheme.accentLight,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              r.teamId,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                color: CustomTheme.textPrimary,
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
                  color: r.group == 'A'
                      ? CustomTheme.infoLight
                      : const Color(0xFFF5F3FF),
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
                        color: r.group == 'A'
                            ? CustomTheme.infoColor
                            : const Color(0xFF6D28D9),
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
                  color: CustomTheme.accentLight,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: CustomTheme.border),
                ),
                child: Text(
                  'C${r.category}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: CustomTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Team Type — muted chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: CustomTheme.accentLight,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: CustomTheme.border),
                ),
                child: Text(
                  r.teamType[0].toUpperCase() + r.teamType.substring(1),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: CustomTheme.textSecondary,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: CustomTheme.positiveLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check,
                        size: 11,
                        color: CustomTheme.positive,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        r.payment != null
                            // ? _fmtAmount(r.payment!.amount, r.payment!.currency)
                            ? r.payment!.amount
                            : 'Paid',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: CustomTheme.positive,
                        ),
                      ),
                    ],
                  ),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: CustomTheme.errorLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.close,
                        size: 11,
                        color: CustomTheme.errorColor,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Unpaid',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: CustomTheme.errorColor,
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
                    style: TextStyle(
                      color: CustomTheme.textSecondary,
                      fontSize: 12,
                    ),
                  )
                : SizedBox(
                    width: 160,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ...r.members
                            .take(2)
                            .map(
                              (m) => Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  m.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: CustomTheme.textPrimary,
                                    decoration: TextDecoration.underline,
                                    decorationColor: CustomTheme.border,
                                  ),
                                ),
                              ),
                            ),
                        if (r.members.length > 2)
                          Text(
                            '+${r.members.length - 2} more',
                            style: const TextStyle(
                              fontSize: 10,
                              color: CustomTheme.textSecondary,
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
              color: CustomTheme.textSecondary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),

        // ── Actions ────────────────────────────────────────────────────────
        DataCell(
          HoverIconButton(
            icon: Icons.edit_outlined,
            tooltip: 'Edit Registration',
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => BlocProvider.value(
                  value: context.read<RegistrationsBloc>(),
                  child: EditRegistrationDialog(registration: r),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
