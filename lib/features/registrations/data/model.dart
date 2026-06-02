class PopupRow {
  final String label;
  final String value;
  PopupRow(this.label, this.value);
}

class RegistrationEvent {
  final String id;
  final String title;
  final String codeName;

  RegistrationEvent({
    required this.id,
    required this.title,
    required this.codeName,
  });

  factory RegistrationEvent.fromJson(Map<String, dynamic> json) =>
      RegistrationEvent(
        id: json['id'] as String,
        title: json['title'] as String,
        codeName: json['code_name'] as String,
      );
}

class RegistrationMember {
  final String id;
  final String name;
  final String email;
  final String institute;
  final int academicYear;
  final String instituteId;
  final String? phone;
  final String? code;

  RegistrationMember({
    required this.id,
    required this.name,
    required this.email,
    required this.institute,
    required this.academicYear,
    required this.instituteId,
    this.phone,
    this.code,
  });

  factory RegistrationMember.fromJson(Map<String, dynamic> json) =>
      RegistrationMember(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        institute: json['institute'] as String,
        academicYear: json['academic_year'] as int,
        instituteId: json['institute_id'] as String,
        phone: json['phone'] as String?,
        code: json['code'] as String?,
      );
}

class RegistrationUser {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? role;
  final String? institute;
  final int? academicYear;
  final String? academicLevel;

  RegistrationUser({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.role,
    this.institute,
    this.academicYear,
    this.academicLevel,
  });

  factory RegistrationUser.fromJson(Map<String, dynamic> json) =>
      RegistrationUser(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Unknown',
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        role: json['role'] as String?,
        institute: json['institute'] as String?,
        academicYear: json['academic_year'] as int?,
        academicLevel: json['academic_level'] as String?,
      );
}

class RegistrationPayment {
  final String paymentId;
  final String registrationId;
  final String amount;
  final String currency;
  final String status;
  final String? method;

  RegistrationPayment({
    required this.paymentId,
    required this.registrationId,
    required this.amount,
    required this.currency,
    required this.status,
    this.method,
  });

  factory RegistrationPayment.fromJson(Map<String, dynamic> json) =>
      RegistrationPayment(
        paymentId: json['payment_id'] as String,
        registrationId: json['registration_id'] as String,
        amount: json['amount'] as String,
        currency: json['currency'] as String,
        status: json['status'] as String,
        method: json['method'] as String?,
      );
}

class Registration {
  final String id;
  final String registrationBy;
  final String eventId;
  final String group;
  final String category;
  final String teamType;
  final DateTime createdAt;
  final String country;
  final bool paid;
  final String teamId;
  final String? referralUsed;

  // Joined
  RegistrationUser? user;
  RegistrationEvent? event;
  List<RegistrationMember> members;
  RegistrationPayment? payment;

  Registration({
    required this.id,
    required this.registrationBy,
    required this.eventId,
    required this.group,
    required this.category,
    required this.teamType,
    required this.createdAt,
    required this.country,
    required this.paid,
    required this.teamId,
    this.referralUsed,
    this.user,
    this.event,
    this.members = const [],
    this.payment,
  });

  factory Registration.fromJson(Map<String, dynamic> json) => Registration(
    id: json['id'] as String,
    registrationBy: json['registration_by'] as String,
    eventId: json['event_id'] as String,
    group: json['group'] as String,
    category: json['category'] as String,
    teamType: json['team_type'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    country: json['country'] as String,
    paid: json['paid'] as bool,
    teamId: json['team_id'] as String,
    referralUsed: json['referral_used'] as String?,
  );
}
