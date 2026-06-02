import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mindrain_admin/features/send_emails/bloc/send_emails_bloc.dart';

class AttachmentsSection extends StatelessWidget {
  const AttachmentsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SendEmailsBloc, SendEmailsState>(
      buildWhen: (p, c) =>
          p.attachments != c.attachments || p.isRunning != c.isRunning,
      builder: (context, state) {
        return Row(
          children: [
            Expanded(
              child: state.attachments.isEmpty
                  ? Text(
                      'No attachments added',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black.withValues(alpha: 0.4),
                      ),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: state.attachments
                          .map(
                            (f) => Chip(
                              label: Text(
                                f.name,
                                style: const TextStyle(fontSize: 12),
                              ),
                              deleteIcon:
                                  const Icon(Icons.close, size: 14),
                              onDeleted: () =>
                                  context.read<SendEmailsBloc>().add(
                                        AttachmentRemoved(f),
                                      ),
                              visualDensity: VisualDensity.compact,
                            ),
                          )
                          .toList(),
                    ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: state.isRunning
                  ? null
                  : () => context.read<SendEmailsBloc>().add(
                        const PickAttachmentsRequested(),
                      ),
              icon: const Icon(Icons.attach_file_rounded, size: 16),
              label: const Text('Add Files'),
              style:
                  OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
          ],
        );
      },
    );
  }
}
