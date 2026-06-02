import 'package:mindrain_admin/features/collected_emails/data/model.dart';

abstract class CollectedEmailsState {}

class CollectedEmailsLoading extends CollectedEmailsState {}

class CollectedEmailsLoaded extends CollectedEmailsState {
  final List<CollectedEmail> allEmails;
  final bool showOnlyUnpaid;
  final List<CollectedEmail> filteredEmails;

  CollectedEmailsLoaded({
    required this.allEmails,
    required this.showOnlyUnpaid,
  }) : filteredEmails = showOnlyUnpaid 
            ? allEmails.where((e) => !e.isPaid).toList() 
            : allEmails;
}

class CollectedEmailsError extends CollectedEmailsState {
  final String message;

  CollectedEmailsError(this.message);
}
