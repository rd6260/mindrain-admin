import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mindrain_admin/features/send_emails/bloc/send_emails_bloc.dart';

const _accent = Color(0xFF6366F1);
const _teal = Color(0xFF06B6D4);

class RunButtons extends StatelessWidget {
  const RunButtons({super.key, required this.onTestRun, required this.onFinalRun});

  final VoidCallback onTestRun;
  final VoidCallback onFinalRun;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SendEmailsBloc, SendEmailsState>(
      buildWhen: (p, c) =>
          p.runStatus != c.runStatus ||
          p.testRows != c.testRows ||
          p.finalRows != c.finalRows ||
          p.emailCol != c.emailCol,
      builder: (context, state) {
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                    (state.isRunning || state.testRows.isEmpty || state.emailCol == null)
                        ? null
                        : onTestRun,
                icon: const Icon(Icons.science_rounded, size: 18),
                label: const Text(
                  'Test Run',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _teal.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                    (state.isRunning || state.finalRows.isEmpty || state.emailCol == null)
                        ? null
                        : onFinalRun,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text(
                  'Final Run',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _accent.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            if (state.isRunning) ...[
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () =>
                    context.read<SendEmailsBloc>().add(const RunCancelled()),
                icon: const Icon(Icons.stop_rounded, size: 18),
                label: const Text('Cancel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
