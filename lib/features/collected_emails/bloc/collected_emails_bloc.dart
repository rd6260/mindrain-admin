import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mindrain_admin/features/collected_emails/bloc/collected_emails_event.dart';
import 'package:mindrain_admin/features/collected_emails/bloc/collected_emails_state.dart';
import 'package:mindrain_admin/features/collected_emails/data/service.dart';

class CollectedEmailsBloc extends Bloc<CollectedEmailsEvent, CollectedEmailsState> {
  final CollectedEmailsService _service;

  CollectedEmailsBloc(this._service) : super(CollectedEmailsLoading()) {
    on<LoadCollectedEmails>(_onLoadCollectedEmails);
    on<ToggleShowUnpaid>(_onToggleShowUnpaid);
  }

  Future<void> _onLoadCollectedEmails(
    LoadCollectedEmails event,
    Emitter<CollectedEmailsState> emit,
  ) async {
    emit(CollectedEmailsLoading());
    try {
      final emails = await _service.getCollectedEmails();
      emit(CollectedEmailsLoaded(allEmails: emails, showOnlyUnpaid: false));
    } catch (e) {
      emit(CollectedEmailsError(e.toString()));
    }
  }

  void _onToggleShowUnpaid(
    ToggleShowUnpaid event,
    Emitter<CollectedEmailsState> emit,
  ) {
    if (state is CollectedEmailsLoaded) {
      final currentState = state as CollectedEmailsLoaded;
      emit(CollectedEmailsLoaded(
        allEmails: currentState.allEmails,
        showOnlyUnpaid: event.showOnlyUnpaid,
      ));
    }
  }
}
