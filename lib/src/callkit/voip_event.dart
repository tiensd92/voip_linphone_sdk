import 'callkit.dart';

class VoipEvent {
  final SipEvent type;
  final dynamic body;

  VoipEvent({
    required this.type,
    this.body,
  });
}
