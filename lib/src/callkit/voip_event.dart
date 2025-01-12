import 'callkit.dart';

class VoipEvent {
  final SipEvent? event;
  final RegistrationState? state;
  final dynamic body;

  VoipEvent({
    this.event,
    this.state,
    this.body,
  });
}
