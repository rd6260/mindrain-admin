part of 'registrations_bloc.dart';

enum RegistrationsStatus { initial, loading, success, failure }

class RegistrationsState {
  final RegistrationsStatus status;
  final List<Registration> allRegistrations;
  final List<Registration> filteredRegistrations;
  final String? error;

  // Filters
  final String searchQuery;
  final String eventFilter;
  final String groupFilter;
  final String typeFilter;
  final String paidFilter;

  // Sort
  final String sortKey;
  final bool sortAsc;

  const RegistrationsState({
    this.status = RegistrationsStatus.initial,
    this.allRegistrations = const [],
    this.filteredRegistrations = const [],
    this.error,
    this.searchQuery = '',
    this.eventFilter = '',
    this.groupFilter = '',
    this.typeFilter = '',
    this.paidFilter = '',
    this.sortKey = 'created_at',
    this.sortAsc = false,
  });

  RegistrationsState copyWith({
    RegistrationsStatus? status,
    List<Registration>? allRegistrations,
    List<Registration>? filteredRegistrations,
    String? error,
    String? searchQuery,
    String? eventFilter,
    String? groupFilter,
    String? typeFilter,
    String? paidFilter,
    String? sortKey,
    bool? sortAsc,
  }) {
    return RegistrationsState(
      status: status ?? this.status,
      allRegistrations: allRegistrations ?? this.allRegistrations,
      filteredRegistrations: filteredRegistrations ?? this.filteredRegistrations,
      error: error, // Don't use ??, allow resetting error to null
      searchQuery: searchQuery ?? this.searchQuery,
      eventFilter: eventFilter ?? this.eventFilter,
      groupFilter: groupFilter ?? this.groupFilter,
      typeFilter: typeFilter ?? this.typeFilter,
      paidFilter: paidFilter ?? this.paidFilter,
      sortKey: sortKey ?? this.sortKey,
      sortAsc: sortAsc ?? this.sortAsc,
    );
  }
}
