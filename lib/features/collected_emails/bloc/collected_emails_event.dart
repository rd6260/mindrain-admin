abstract class CollectedEmailsEvent {}

class LoadCollectedEmails extends CollectedEmailsEvent {}

class ToggleShowUnpaid extends CollectedEmailsEvent {
  final bool showOnlyUnpaid;

  ToggleShowUnpaid(this.showOnlyUnpaid);
}
