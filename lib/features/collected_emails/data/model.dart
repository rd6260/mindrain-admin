import 'package:mindrain_admin/features/registrations/data/model.dart';

class CollectedEmail {
  final int id;
  final String email;
  final DateTime createdAt;
  final String eventName;
  final bool isPaid;
  final RegistrationUser? user;

  const CollectedEmail({
    required this.id,
    required this.email,
    required this.createdAt,
    required this.eventName,
    required this.isPaid,
    this.user,
  });
}
