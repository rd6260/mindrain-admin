import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mindrain_admin/features/registrations/data/model.dart';
import 'package:mindrain_admin/features/registrations/data/registrations_repository.dart';

part 'registrations_event.dart';
part 'registrations_state.dart';

class RegistrationsBloc extends Bloc<RegistrationsEvent, RegistrationsState> {
  final RegistrationsRepository _repository;

  RegistrationsBloc({RegistrationsRepository? repository})
      : _repository = repository ?? RegistrationsRepository(),
        super(const RegistrationsState()) {
    on<FetchRegistrations>(_onFetchRegistrations);
    on<SearchQueryChanged>(_onSearchQueryChanged);
    on<EventFilterChanged>(_onEventFilterChanged);
    on<GroupFilterChanged>(_onGroupFilterChanged);
    on<TypeFilterChanged>(_onTypeFilterChanged);
    on<PaidFilterChanged>(_onPaidFilterChanged);
    on<SortChanged>(_onSortChanged);
  }

  Future<void> _onFetchRegistrations(
    FetchRegistrations event,
    Emitter<RegistrationsState> emit,
  ) async {
    emit(state.copyWith(status: RegistrationsStatus.loading));
    try {
      final registrations = await _repository.fetchRegistrations();
      emit(
        state.copyWith(
          status: RegistrationsStatus.success,
          allRegistrations: registrations,
        ),
      );
      _applyFilters(emit);
    } catch (e) {
      emit(
        state.copyWith(
          status: RegistrationsStatus.failure,
          error: e.toString(),
        ),
      );
    }
  }

  void _onSearchQueryChanged(
    SearchQueryChanged event,
    Emitter<RegistrationsState> emit,
  ) {
    emit(state.copyWith(searchQuery: event.query));
    _applyFilters(emit);
  }

  void _onEventFilterChanged(
    EventFilterChanged event,
    Emitter<RegistrationsState> emit,
  ) {
    emit(state.copyWith(eventFilter: event.eventFilter));
    _applyFilters(emit);
  }

  void _onGroupFilterChanged(
    GroupFilterChanged event,
    Emitter<RegistrationsState> emit,
  ) {
    emit(state.copyWith(groupFilter: event.groupFilter));
    _applyFilters(emit);
  }

  void _onTypeFilterChanged(
    TypeFilterChanged event,
    Emitter<RegistrationsState> emit,
  ) {
    emit(state.copyWith(typeFilter: event.typeFilter));
    _applyFilters(emit);
  }

  void _onPaidFilterChanged(
    PaidFilterChanged event,
    Emitter<RegistrationsState> emit,
  ) {
    emit(state.copyWith(paidFilter: event.paidFilter));
    _applyFilters(emit);
  }

  void _onSortChanged(SortChanged event, Emitter<RegistrationsState> emit) {
    final sortAsc =
        state.sortKey == event.sortKey ? !state.sortAsc : false;
    emit(state.copyWith(sortKey: event.sortKey, sortAsc: sortAsc));
    _applyFilters(emit);
  }

  void _applyFilters(Emitter<RegistrationsState> emit) {
    final q = state.searchQuery.toLowerCase();
    var list = state.allRegistrations.where((r) {
      if (q.isNotEmpty) {
        final nameMatch = r.user?.name.toLowerCase().contains(q) ?? false;
        final teamMatch = r.teamId.toLowerCase().contains(q);
        final eventMatch = r.event?.title.toLowerCase().contains(q) ?? false;
        final memberMatch = r.members.any(
          (m) => m.name.toLowerCase().contains(q),
        );
        if (!nameMatch && !teamMatch && !eventMatch && !memberMatch) {
          return false;
        }
      }
      if (state.eventFilter.isNotEmpty && r.eventId != state.eventFilter) {
        return false;
      }
      if (state.groupFilter.isNotEmpty && r.group != state.groupFilter) {
        return false;
      }
      if (state.typeFilter.isNotEmpty && r.teamType != state.typeFilter) {
        return false;
      }
      if (state.paidFilter == 'paid' && !r.paid) return false;
      if (state.paidFilter == 'unpaid' && r.paid) return false;
      return true;
    }).toList();

    list.sort((a, b) {
      dynamic va, vb;
      switch (state.sortKey) {
        case 'name':
          va = a.user?.name ?? '';
          vb = b.user?.name ?? '';
          break;
        case 'paid':
          va = a.paid ? 1 : 0;
          vb = b.paid ? 1 : 0;
          break;
        default:
          va = state.sortKey == 'created_at'
              ? a.createdAt.millisecondsSinceEpoch
              : '';
          vb = state.sortKey == 'created_at'
              ? b.createdAt.millisecondsSinceEpoch
              : '';
      }
      final cmp = Comparable.compare(va as Comparable, vb as Comparable);
      return state.sortAsc ? cmp : -cmp;
    });

    emit(state.copyWith(filteredRegistrations: list));
  }
}
