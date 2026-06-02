import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mindrain_admin/features/send_emails/bloc/send_emails_bloc.dart';

const _accent = Color(0xFF6366F1);

class ProgressDialog extends StatelessWidget {
  const ProgressDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SendEmailsBloc, SendEmailsState>(
      buildWhen: (p, c) =>
          p.runStatus != c.runStatus ||
          p.sent != c.sent ||
          p.ok != c.ok ||
          p.fail != c.fail ||
          p.runLog != c.runLog,
      builder: (context, state) {
        final pct = state.total == 0 ? 0.0 : state.sent / state.total;
        final running = state.isRunning;
        final statusLabel = running
            ? (state.runStatus == RunStatus.cancelling
                ? 'Cancelling…'
                : 'Sending…')
            : (state.runStatus == RunStatus.done ? 'Done ✓' : '');

        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Row(
                  children: [
                    const Icon(Icons.send_rounded, color: _accent, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      running ? 'Sending Emails…' : statusLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Percentage + bar
                Row(
                  children: [
                    Text(
                      '${(pct * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 10,
                          backgroundColor: const Color(0xFFE4E4EF),
                          valueColor: AlwaysStoppedAnimation(
                            !running ? Colors.green.shade400 : _accent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  statusLabel,
                  style: TextStyle(
                      fontSize: 12, color: Colors.black.withValues(alpha: 0.4)),
                ),
                const SizedBox(height: 16),

                // Stats row
                Row(
                  children: [
                    Text(
                      '${state.sent} / ${state.total} sent',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.black.withValues(alpha: 0.55)),
                    ),
                    const SizedBox(width: 18),
                    Icon(Icons.check_circle_outline_rounded,
                        size: 14, color: Colors.green.shade500),
                    const SizedBox(width: 4),
                    Text('${state.ok} ok',
                        style: TextStyle(
                            fontSize: 13, color: Colors.green.shade600)),
                    const SizedBox(width: 18),
                    Icon(Icons.cancel_outlined,
                        size: 14, color: Colors.red.shade400),
                    const SizedBox(width: 4),
                    Text('${state.fail} failed',
                        style: TextStyle(
                            fontSize: 13, color: Colors.red.shade500)),
                  ],
                ),

                // Error log
                if (state.runLog.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 120),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        state.runLog,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: Colors.red.shade800,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: running
                      ? ElevatedButton.icon(
                          onPressed: () => context
                              .read<SendEmailsBloc>()
                              .add(const RunCancelled()),
                          icon: const Icon(Icons.stop_rounded, size: 16),
                          label: const Text('Cancel'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade400,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                        )
                      : ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: const Text('Close'),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
