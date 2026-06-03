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
