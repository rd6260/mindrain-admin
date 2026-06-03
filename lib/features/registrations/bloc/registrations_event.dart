part of 'registrations_bloc.dart';

abstract class RegistrationsEvent {}

class FetchRegistrations extends RegistrationsEvent {}

class SearchQueryChanged extends RegistrationsEvent {
  final String query;
  SearchQueryChanged(this.query);
}

class EventFilterChanged extends RegistrationsEvent {
  final String eventFilter;
  EventFilterChanged(this.eventFilter);
}

class GroupFilterChanged extends RegistrationsEvent {
  final String groupFilter;
  GroupFilterChanged(this.groupFilter);
}

class TypeFilterChanged extends RegistrationsEvent {
  final String typeFilter;
  TypeFilterChanged(this.typeFilter);
}

class PaidFilterChanged extends RegistrationsEvent {
  final String paidFilter;
  PaidFilterChanged(this.paidFilter);
}

class SortChanged extends RegistrationsEvent {
  final String sortKey;
  SortChanged(this.sortKey);
}

// ── Edit events ───────────────────────────────────────────────────────────────

class UpdateRegistration extends RegistrationsEvent {
  final String id;
  final Map<String, dynamic> data;
  UpdateRegistration(this.id, this.data);
}

class UpdatePayment extends RegistrationsEvent {
  final String registrationId;
  final String paymentId;
  final Map<String, dynamic> data;
  UpdatePayment(this.registrationId, this.paymentId, this.data);
}

class CreatePayment extends RegistrationsEvent {
  final String registrationId;
  final Map<String, dynamic> data;
  CreatePayment(this.registrationId, this.data);
}

class UpdateMember extends RegistrationsEvent {
  final String registrationId;
  final String memberId;
  final Map<String, dynamic> data;
  UpdateMember(this.registrationId, this.memberId, this.data);
}

class CreateMember extends RegistrationsEvent {
  final String registrationId;
  final Map<String, dynamic> data;
  CreateMember(this.registrationId, this.data);
}

class DeleteMember extends RegistrationsEvent {
  final String registrationId;
  final String memberId;
  DeleteMember(this.registrationId, this.memberId);
}
