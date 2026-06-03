import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mindrain_admin/core/theme.dart';
import 'package:mindrain_admin/features/registrations/bloc/registrations_bloc.dart';
import 'package:mindrain_admin/features/registrations/data/model.dart';
import 'package:mindrain_admin/features/registrations/widgets/member_edit_tile.dart';

class EditRegistrationDialog extends StatefulWidget {
  final Registration registration;

  const EditRegistrationDialog({super.key, required this.registration});

  @override
  State<EditRegistrationDialog> createState() => _EditRegistrationDialogState();
}

class _EditRegistrationDialogState extends State<EditRegistrationDialog> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Registration Form
  final _regFormKey = GlobalKey<FormState>();
  late String _group;
  late String _category;
  late String _teamType;
  late String _eventId;
  late TextEditingController _countryController;
  late TextEditingController _teamIdController;
  late TextEditingController _referralController;
  late TextEditingController _registrationByController;
  late bool _paid;

  // Payment Form
  final _payFormKey = GlobalKey<FormState>();
  late TextEditingController _payAmountController;
  late TextEditingController _payCurrencyController;
  late String _payStatus;
  late TextEditingController _payMethodController;
  late TextEditingController _payOrderIdController;
  late TextEditingController _payPaymentIdController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Reg init
    _group = widget.registration.group;
    _category = widget.registration.category;
    _teamType = widget.registration.teamType;
    _eventId = widget.registration.eventId;
    _countryController = TextEditingController(text: widget.registration.country);
    _teamIdController = TextEditingController(text: widget.registration.teamId);
    _referralController = TextEditingController(text: widget.registration.referralUsed ?? '');
    _registrationByController = TextEditingController(text: widget.registration.registrationBy);
    _paid = widget.registration.paid;

    // Pay init
    final p = widget.registration.payment;
    _payAmountController = TextEditingController(text: p?.amount ?? '');
    _payCurrencyController = TextEditingController(text: p?.currency ?? 'INR');
    _payStatus = p?.status ?? 'paid';
    _payMethodController = TextEditingController(text: p?.method ?? '');
    _payOrderIdController = TextEditingController(text: ''); // Not in model but usually part of payment
    _payPaymentIdController = TextEditingController(text: p?.paymentId ?? '');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _countryController.dispose();
    _teamIdController.dispose();
    _referralController.dispose();
    _registrationByController.dispose();
    _payAmountController.dispose();
    _payCurrencyController.dispose();
    _payMethodController.dispose();
    _payOrderIdController.dispose();
    _payPaymentIdController.dispose();
    super.dispose();
  }

  void _saveRegistration() {
    if (_regFormKey.currentState!.validate()) {
      final data = {
        'group': _group,
        'category': _category,
        'team_type': _teamType,
        'event_id': _eventId,
        'country': _countryController.text.trim(),
        'team_id': _teamIdController.text.trim(),
        'paid': _paid,
        'registration_by': _registrationByController.text.trim(),
      };
      final ref = _referralController.text.trim();
      if (ref.isNotEmpty) data['referral_used'] = ref;

      context.read<RegistrationsBloc>().add(UpdateRegistration(widget.registration.id, data));
    }
  }

  void _savePayment() {
    if (_payFormKey.currentState!.validate()) {
      final data = {
        'amount': _payAmountController.text.trim(),
        'currency': _payCurrencyController.text.trim(),
        'status': _payStatus,
        'method': _payMethodController.text.trim(),
      };

      if (widget.registration.payment == null) {
        context.read<RegistrationsBloc>().add(CreatePayment(widget.registration.id, data));
      } else {
        context.read<RegistrationsBloc>().add(UpdatePayment(widget.registration.id, widget.registration.payment!.paymentId, data));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 600,
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: CustomTheme.surface,
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
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.only(left: 28, right: 28, top: 28, bottom: 16),
              child: Row(
                children: [
                  const Icon(Icons.edit_document, size: 20, color: CustomTheme.textPrimary),
                  const SizedBox(width: 12),
                  const Text(
                    'Edit Registration',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: CustomTheme.textPrimary),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close, size: 20, color: CustomTheme.textSecondary),
                  ),
                ],
              ),
            ),
            
            // Error Banner
            BlocBuilder<RegistrationsBloc, RegistrationsState>(
              builder: (context, state) {
                if (state.saveError != null) {
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 28).copyWith(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CustomTheme.errorLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: CustomTheme.errorColor.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, size: 16, color: CustomTheme.errorColor),
                        const SizedBox(width: 8),
                        Expanded(child: Text(state.saveError!, style: const TextStyle(fontSize: 12, color: CustomTheme.errorColor))),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            // Tabs
            TabBar(
              controller: _tabController,
              labelColor: CustomTheme.textPrimary,
              unselectedLabelColor: CustomTheme.textSecondary,
              indicatorColor: CustomTheme.textPrimary,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: CustomTheme.border,
              tabs: const [
                Tab(text: 'Registration'),
                Tab(text: 'Payment'),
                Tab(text: 'Members'),
              ],
            ),
            
            // Content
            Expanded(
              child: BlocBuilder<RegistrationsBloc, RegistrationsState>(
                builder: (context, state) {
                  final isSaving = state.savingIds.contains(widget.registration.id);
                  // Find the latest registration state to pass to tabs (so they update after save)
                  final currentReg = state.allRegistrations.firstWhere(
                    (r) => r.id == widget.registration.id,
                    orElse: () => widget.registration,
                  );

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRegistrationTab(currentReg, state.allRegistrations, isSaving),
                      _buildPaymentTab(currentReg, isSaving),
                      _buildMembersTab(currentReg),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationTab(Registration reg, List<Registration> all, bool isSaving) {
    // Collect unique events for dropdown
    final events = <RegistrationEvent>{};
    for (var r in all) {
      if (r.event != null) events.add(r.event!);
    }

    return Form(
      key: _regFormKey,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(28),
              children: [
                Row(
                  children: [
                    Expanded(child: _buildDropdown('Group', _group, ['A', 'B'], (v) => setState(() => _group = v!))),
                    const SizedBox(width: 16),
                    Expanded(child: _buildDropdown('Category', _category, ['1', '2'], (v) => setState(() => _category = v!))),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildDropdown('Team Type', _teamType, ['solo', 'group'], (v) => setState(() => _teamType = v!))),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDropdown(
                        'Event', 
                        _eventId, 
                        events.map((e) => e.id).toList(), 
                        (v) => setState(() => _eventId = v!),
                        display: (id) => events.firstWhere((e) => e.id == id).title,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildTextField('Team ID', _teamIdController, required: true)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTextField('Country', _countryController, required: true)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField('Registration By (User ID)', _registrationByController, required: true),
                const SizedBox(height: 16),
                _buildTextField('Referral Used (ID)', _referralController),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _paid ? CustomTheme.positiveLight : CustomTheme.errorLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _paid ? CustomTheme.positive.withValues(alpha: 0.2) : CustomTheme.errorColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _paid ? Icons.check_circle : Icons.cancel,
                        color: _paid ? CustomTheme.positive : CustomTheme.errorColor,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Payment Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _paid ? CustomTheme.positive : CustomTheme.errorColor)),
                          Text(_paid ? 'Registration is marked as paid' : 'Registration is unpaid', style: const TextStyle(fontSize: 11, color: CustomTheme.textSecondary)),
                        ],
                      ),
                      const Spacer(),
                      Switch(
                        value: _paid,
                        onChanged: (v) => setState(() => _paid = v),
                        activeTrackColor: CustomTheme.positive.withValues(alpha: 0.5),
                        activeThumbColor: CustomTheme.positive,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildBottomBar(_saveRegistration, isSaving),
        ],
      ),
    );
  }

  Widget _buildPaymentTab(Registration reg, bool isSaving) {
    return Form(
      key: _payFormKey,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(28),
              children: [
                if (reg.payment == null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: CustomTheme.infoLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: CustomTheme.infoColor, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No payment record exists. Fill the details below to create one.',
                            style: TextStyle(fontSize: 12, color: CustomTheme.infoColor),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
                Row(
                  children: [
                    Expanded(child: _buildTextField('Amount (e.g. 1000)', _payAmountController, required: true)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTextField('Currency', _payCurrencyController, required: true)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildDropdown('Status', _payStatus, ['paid', 'unpaid', 'created', 'failed'], (v) => setState(() => _payStatus = v!))),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTextField('Method (e.g. upi, card)', _payMethodController)),
                  ],
                ),
                if (reg.payment != null) ...[
                  const SizedBox(height: 16),
                  _buildTextField('Payment ID', _payPaymentIdController, enabled: false),
                ]
              ],
            ),
          ),
          _buildBottomBar(_savePayment, isSaving, label: reg.payment == null ? 'Create Payment' : 'Save Payment'),
        ],
      ),
    );
  }

  Widget _buildMembersTab(Registration reg) {
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        ...reg.members.map((m) => MemberEditTile(registrationId: reg.id, member: m)),
        const SizedBox(height: 8),
        MemberEditTile(registrationId: reg.id), // "Add new" tile
      ],
    );
  }

  // Helpers

  Widget _buildBottomBar(VoidCallback onSave, bool isSaving, {String label = 'Save Changes'}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      decoration: const BoxDecoration(
        color: CustomTheme.surface,
        border: Border(top: BorderSide(color: CustomTheme.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: isSaving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: CustomTheme.textSecondary)),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: isSaving ? null : onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: CustomTheme.textPrimary,
              foregroundColor: CustomTheme.surface,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            child: isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: CustomTheme.surface, strokeWidth: 2))
                : Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool required = false, bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: CustomTheme.textSecondary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          enabled: enabled,
          style: TextStyle(fontSize: 13, color: enabled ? CustomTheme.textPrimary : CustomTheme.textSecondary),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: CustomTheme.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: CustomTheme.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: CustomTheme.textPrimary)),
            filled: true,
            fillColor: enabled ? CustomTheme.surface : CustomTheme.accentLight.withValues(alpha: 0.5),
          ),
          validator: required ? (v) => v == null || v.trim().isEmpty ? 'Required' : null : null,
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, void Function(String?) onChanged, {String Function(String)? display}) {
    // Ensure value exists in items to avoid assertions
    final safeValue = items.contains(value) ? value : items.first;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: CustomTheme.textSecondary)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: safeValue,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 13, color: CustomTheme.textPrimary),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: CustomTheme.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: CustomTheme.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: CustomTheme.textPrimary)),
            filled: true,
            fillColor: CustomTheme.surface,
          ),
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(display != null ? display(i) : i))).toList(),
        ),
      ],
    );
  }
}
