import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mindrain_admin/core/theme.dart';
import 'package:mindrain_admin/features/registrations/bloc/registrations_bloc.dart';
import 'package:mindrain_admin/features/registrations/data/model.dart';

class MemberEditTile extends StatefulWidget {
  final String registrationId;
  final RegistrationMember? member; // If null, it's a "create new" tile

  const MemberEditTile({
    super.key,
    required this.registrationId,
    this.member,
  });

  @override
  State<MemberEditTile> createState() => _MemberEditTileState();
}

class _MemberEditTileState extends State<MemberEditTile> {
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _instituteController;
  late final TextEditingController _instituteIdController;
  late final TextEditingController _academicYearController;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.member == null; // Auto-edit if new
    _nameController = TextEditingController(text: widget.member?.name ?? '');
    _emailController = TextEditingController(text: widget.member?.email ?? '');
    _phoneController = TextEditingController(text: widget.member?.phone ?? '');
    _instituteController = TextEditingController(text: widget.member?.institute ?? '');
    _instituteIdController = TextEditingController(text: widget.member?.instituteId ?? '');
    _academicYearController = TextEditingController(text: widget.member?.academicYear.toString() ?? '1');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _instituteController.dispose();
    _instituteIdController.dispose();
    _academicYearController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final data = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'institute': _instituteController.text.trim(),
        'institute_id': _instituteIdController.text.trim(),
        'academic_year': int.parse(_academicYearController.text.trim()),
      };

      if (widget.member == null) {
        context.read<RegistrationsBloc>().add(
              CreateMember(widget.registrationId, data),
            );
        // Clear for next insert
        _nameController.clear();
        _emailController.clear();
        _phoneController.clear();
        _instituteController.clear();
        _instituteIdController.clear();
        _academicYearController.text = '1';
      } else {
        context.read<RegistrationsBloc>().add(
              UpdateMember(widget.registrationId, widget.member!.id, data),
            );
        setState(() => _isEditing = false);
      }
    }
  }

  void _delete() {
    if (widget.member != null) {
      context.read<RegistrationsBloc>().add(
            DeleteMember(widget.registrationId, widget.member!.id),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isEditing && widget.member != null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: CustomTheme.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.member!.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.member!.email} · Year ${widget.member!.academicYear}',
                    style: const TextStyle(color: CustomTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 16),
              onPressed: () => setState(() => _isEditing = true),
              color: CustomTheme.textSecondary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16),
              onPressed: _delete,
              color: CustomTheme.errorColor,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CustomTheme.accentLight.withValues(alpha: 0.5),
        border: Border.all(color: CustomTheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.member == null ? 'Add New Member' : 'Edit Member',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildField('Name', _nameController, required: true)),
                const SizedBox(width: 12),
                Expanded(child: _buildField('Email', _emailController, required: true)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildField('Institute', _instituteController, required: true)),
                const SizedBox(width: 12),
                Expanded(child: _buildField('Inst. ID', _instituteIdController, required: true)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildField('Year (1-5)', _academicYearController, required: true, isNumber: true)),
                const SizedBox(width: 12),
                Expanded(child: _buildField('Phone', _phoneController)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.member != null)
                  TextButton(
                    onPressed: () => setState(() => _isEditing = false),
                    style: TextButton.styleFrom(
                      foregroundColor: CustomTheme.textSecondary,
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                  ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CustomTheme.textPrimary,
                    foregroundColor: CustomTheme.surface,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: Text(widget.member == null ? 'Add' : 'Save', style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {bool required = false, bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: CustomTheme.textSecondary),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          style: const TextStyle(fontSize: 12),
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              borderSide: const BorderSide(color: CustomTheme.textPrimary),
            ),
            filled: true,
            fillColor: CustomTheme.surface,
          ),
          validator: required
              ? (val) {
                  if (val == null || val.trim().isEmpty) return 'Required';
                  if (isNumber && int.tryParse(val) == null) return 'Must be a number';
                  return null;
                }
              : null,
        ),
      ],
    );
  }
}
