import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mindrain_admin/features/send_emails/bloc/send_emails_bloc.dart';

class DefaultValuesSection extends StatefulWidget {
  const DefaultValuesSection({super.key});

  @override
  State<DefaultValuesSection> createState() => _DefaultValuesSectionState();
}

class _DefaultValuesSectionState extends State<DefaultValuesSection> {
  // Local controllers keyed by variable name, synced with bloc state.
  final Map<String, TextEditingController> _ctrls = {};

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncControllers(Set<String> vars) {
    // Add controllers for new vars
    for (final v in vars) {
      _ctrls.putIfAbsent(v, () => TextEditingController());
    }
    // Remove controllers for vars no longer present
    final removed = _ctrls.keys.where((k) => !vars.contains(k)).toList();
    for (final k in removed) {
      _ctrls[k]?.dispose();
      _ctrls.remove(k);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SendEmailsBloc, SendEmailsState>(
      buildWhen: (p, c) => p.detectedVars != c.detectedVars,
      builder: (context, state) {
        _syncControllers(state.detectedVars);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fallback used when a row has no value for that variable.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: state.detectedVars.map((v) {
                return SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _ctrls[v],
                    onChanged: (val) =>
                        context.read<SendEmailsBloc>().add(
                              DefaultValueChanged(variable: v, value: val),
                            ),
                    decoration: InputDecoration(
                      labelText: '{{$v}}',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}
