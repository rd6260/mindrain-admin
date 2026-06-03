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
    // Edit handlers
    on<UpdateRegistration>(_onUpdateRegistration);
    on<UpdatePayment>(_onUpdatePayment);
    on<CreatePayment>(_onCreatePayment);
    on<UpdateMember>(_onUpdateMember);
    on<CreateMember>(_onCreateMember);
    on<DeleteMember>(_onDeleteMember);
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

  // ── Edit handlers ──────────────────────────────────────────────────────────

  Future<void> _onUpdateRegistration(
    UpdateRegistration event,
    Emitter<RegistrationsState> emit,
  ) async {
    emit(state.copyWith(
      savingIds: {...state.savingIds, event.id},
      clearSaveError: true,
    ));
    try {
      await _repository.updateRegistration(event.id, event.data);
      final updated = state.allRegistrations.map((r) {
        if (r.id != event.id) return r;
        return Registration(
          id: r.id,
          registrationBy: event.data['registration_by'] as String? ?? r.registrationBy,
          eventId: event.data['event_id'] as String? ?? r.eventId,
          group: event.data['group'] as String? ?? r.group,
          category: event.data['category'] as String? ?? r.category,
          teamType: event.data['team_type'] as String? ?? r.teamType,
          createdAt: r.createdAt,
          country: event.data['country'] as String? ?? r.country,
          paid: event.data['paid'] as bool? ?? r.paid,
          teamId: event.data['team_id'] as String? ?? r.teamId,
          referralUsed: event.data.containsKey('referral_used')
              ? event.data['referral_used'] as String?
              : r.referralUsed,
          user: r.user,
          event: r.event,
          members: r.members,
          payment: r.payment,
        );
      }).toList();
      final newSaving = {...state.savingIds}..remove(event.id);
      emit(state.copyWith(allRegistrations: updated, savingIds: newSaving));
      _applyFilters(emit);
    } catch (e) {
      final newSaving = {...state.savingIds}..remove(event.id);
      emit(state.copyWith(savingIds: newSaving, saveError: e.toString()));
    }
  }

  Future<void> _onUpdatePayment(
    UpdatePayment event,
    Emitter<RegistrationsState> emit,
  ) async {
    emit(state.copyWith(
      savingIds: {...state.savingIds, event.registrationId},
      clearSaveError: true,
    ));
    try {
      await _repository.updatePayment(event.paymentId, event.data);
      final updated = state.allRegistrations.map((r) {
        if (r.id != event.registrationId || r.payment == null) return r;
        final p = r.payment!;
        final newPayment = RegistrationPayment(
          paymentId: p.paymentId,
          registrationId: p.registrationId,
          amount: event.data['amount'] as String? ?? p.amount,
          currency: event.data['currency'] as String? ?? p.currency,
          status: event.data['status'] as String? ?? p.status,
          method: event.data.containsKey('method')
              ? event.data['method'] as String?
              : p.method,
        );
        return Registration(
          id: r.id,
          registrationBy: r.registrationBy,
          eventId: r.eventId,
          group: r.group,
          category: r.category,
          teamType: r.teamType,
          createdAt: r.createdAt,
          country: r.country,
          paid: r.paid,
          teamId: r.teamId,
          referralUsed: r.referralUsed,
          user: r.user,
          event: r.event,
          members: r.members,
          payment: newPayment,
        );
      }).toList();
      final newSaving = {...state.savingIds}..remove(event.registrationId);
      emit(state.copyWith(allRegistrations: updated, savingIds: newSaving));
      _applyFilters(emit);
    } catch (e) {
      final newSaving = {...state.savingIds}..remove(event.registrationId);
      emit(state.copyWith(savingIds: newSaving, saveError: e.toString()));
    }
  }

  Future<void> _onCreatePayment(
    CreatePayment event,
    Emitter<RegistrationsState> emit,
  ) async {
    emit(state.copyWith(
      savingIds: {...state.savingIds, event.registrationId},
      clearSaveError: true,
    ));
    try {
      final payment = await _repository.createPayment({
        ...event.data,
        'registration_id': event.registrationId,
      });
      final updated = state.allRegistrations.map((r) {
        if (r.id != event.registrationId) return r;
        return Registration(
          id: r.id,
          registrationBy: r.registrationBy,
          eventId: r.eventId,
          group: r.group,
          category: r.category,
          teamType: r.teamType,
          createdAt: r.createdAt,
          country: r.country,
          paid: r.paid,
          teamId: r.teamId,
          referralUsed: r.referralUsed,
          user: r.user,
          event: r.event,
          members: r.members,
          payment: payment,
        );
      }).toList();
      final newSaving = {...state.savingIds}..remove(event.registrationId);
      emit(state.copyWith(allRegistrations: updated, savingIds: newSaving));
      _applyFilters(emit);
    } catch (e) {
      final newSaving = {...state.savingIds}..remove(event.registrationId);
      emit(state.copyWith(savingIds: newSaving, saveError: e.toString()));
    }
  }

  Future<void> _onUpdateMember(
    UpdateMember event,
    Emitter<RegistrationsState> emit,
  ) async {
    emit(state.copyWith(
      savingIds: {...state.savingIds, event.registrationId},
      clearSaveError: true,
    ));
    try {
      await _repository.updateMember(event.memberId, event.data);
      final updated = state.allRegistrations.map((r) {
        if (r.id != event.registrationId) return r;
        final newMembers = r.members.map((m) {
          if (m.id != event.memberId) return m;
          return RegistrationMember(
            id: m.id,
            name: event.data['name'] as String? ?? m.name,
            email: event.data['email'] as String? ?? m.email,
            institute: event.data['institute'] as String? ?? m.institute,
            academicYear: event.data['academic_year'] as int? ?? m.academicYear,
            instituteId: event.data['institute_id'] as String? ?? m.instituteId,
            phone: event.data.containsKey('phone')
                ? event.data['phone'] as String?
                : m.phone,
            code: event.data.containsKey('code')
                ? event.data['code'] as String?
                : m.code,
          );
        }).toList();
        return Registration(
          id: r.id,
          registrationBy: r.registrationBy,
          eventId: r.eventId,
          group: r.group,
          category: r.category,
          teamType: r.teamType,
          createdAt: r.createdAt,
          country: r.country,
          paid: r.paid,
          teamId: r.teamId,
          referralUsed: r.referralUsed,
          user: r.user,
          event: r.event,
          members: newMembers,
          payment: r.payment,
        );
      }).toList();
      final newSaving = {...state.savingIds}..remove(event.registrationId);
      emit(state.copyWith(allRegistrations: updated, savingIds: newSaving));
      _applyFilters(emit);
    } catch (e) {
      final newSaving = {...state.savingIds}..remove(event.registrationId);
      emit(state.copyWith(savingIds: newSaving, saveError: e.toString()));
    }
  }

  Future<void> _onCreateMember(
    CreateMember event,
    Emitter<RegistrationsState> emit,
  ) async {
    emit(state.copyWith(
      savingIds: {...state.savingIds, event.registrationId},
      clearSaveError: true,
    ));
    try {
      final member = await _repository.createMember({
        ...event.data,
        'registration_id': event.registrationId,
      });
      final updated = state.allRegistrations.map((r) {
        if (r.id != event.registrationId) return r;
        return Registration(
          id: r.id,
          registrationBy: r.registrationBy,
          eventId: r.eventId,
          group: r.group,
          category: r.category,
          teamType: r.teamType,
          createdAt: r.createdAt,
          country: r.country,
          paid: r.paid,
          teamId: r.teamId,
          referralUsed: r.referralUsed,
          user: r.user,
          event: r.event,
          members: [...r.members, member],
          payment: r.payment,
        );
      }).toList();
      final newSaving = {...state.savingIds}..remove(event.registrationId);
      emit(state.copyWith(allRegistrations: updated, savingIds: newSaving));
      _applyFilters(emit);
    } catch (e) {
      final newSaving = {...state.savingIds}..remove(event.registrationId);
      emit(state.copyWith(savingIds: newSaving, saveError: e.toString()));
    }
  }

  Future<void> _onDeleteMember(
    DeleteMember event,
    Emitter<RegistrationsState> emit,
  ) async {
    emit(state.copyWith(
      savingIds: {...state.savingIds, event.registrationId},
      clearSaveError: true,
    ));
    try {
      await _repository.deleteMember(event.memberId);
      final updated = state.allRegistrations.map((r) {
        if (r.id != event.registrationId) return r;
        return Registration(
          id: r.id,
          registrationBy: r.registrationBy,
          eventId: r.eventId,
          group: r.group,
          category: r.category,
          teamType: r.teamType,
          createdAt: r.createdAt,
          country: r.country,
          paid: r.paid,
          teamId: r.teamId,
          referralUsed: r.referralUsed,
          user: r.user,
          event: r.event,
          members: r.members.where((m) => m.id != event.memberId).toList(),
          payment: r.payment,
        );
      }).toList();
      final newSaving = {...state.savingIds}..remove(event.registrationId);
      emit(state.copyWith(allRegistrations: updated, savingIds: newSaving));
      _applyFilters(emit);
    } catch (e) {
      final newSaving = {...state.savingIds}..remove(event.registrationId);
      emit(state.copyWith(savingIds: newSaving, saveError: e.toString()));
    }
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


