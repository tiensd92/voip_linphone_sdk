enum SipEvent {
  ring('Ring'),
  connected('Connected'),
  up('Up'),
  paused('Paused'),
  resuming('Resuming'),
  missed('Missed'),
  hangup('Hangup'),
  error('Error'),
  released('Released'),
  pushReceive('PushReceive'),
  pushToken('PushToken');

  final String value;

  const SipEvent(this.value);

  @override
  String toString() => value;
}

enum RegistrationState {
  none('None'),
  progress('Progress'),
  ok('Ok'),
  cleared('Cleared'),
  failed('Failed'),
  refreshing('Refreshing');

  final String value;

  const RegistrationState(this.value);

  @override
  String toString() => value;
}
