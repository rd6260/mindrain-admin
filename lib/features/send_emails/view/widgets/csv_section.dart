import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mindrain_admin/features/send_emails/bloc/send_emails_bloc.dart';
import 'package:mindrain_admin/features/send_emails/view/widgets/csv_card.dart';

const _accent = Color(0xFF6366F1);
const _teal = Color(0xFF06B6D4);

class CsvSection extends StatelessWidget {
  const CsvSection({super.key, required this.onColumnInsert});

  /// Called when the user taps a column chip. The view layer uses this to
  /// insert `{{column}}` into the body [TextEditingController].
  final void Function(String column) onColumnInsert;

  @override
  Widget build(BuildContext context) {
    return ColumnInsertScope(
      onInsert: onColumnInsert,
      child: BlocBuilder<SendEmailsBloc, SendEmailsState>(
        buildWhen: (p, c) => p.csvWarning != c.csvWarning,
        builder: (context, state) {
          return Column(
            children: [
              if (state.csvWarning != null) ...[
                _WarningBanner(msg: state.csvWarning!),
                const SizedBox(height: 12),
              ],
              Row(
                children: const [
                  Expanded(
                    child: CsvCard(
                      label: 'Test CSV',
                      color: _teal,
                      isTest: true,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: CsvCard(
                      label: 'Final CSV',
                      color: _accent,
                      isTest: false,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.msg});
  final String msg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Colors.orange.shade700, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
