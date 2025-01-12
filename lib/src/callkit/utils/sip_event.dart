enum SipEvent {
  ring('Sip.Ring'),
  connected('Sip.Connected'),
  up('Sip.Up'),
  paused('Sip.Paused'),
  resuming('Sip.Resuming'),
  missed('Sip.Missed'),
  hangup('Sip.Hangup'),
  error('Sip.Error'),
  released('Sip.Released'),
  pushReceive('Sip.PushReceive'),
  pushToken('Sip.PushToken');

  final String value;

  const SipEvent(this.value);

  @override
  String toString() => value;
}

enum RegistrationState {
  none('Registration.None'),
  progress('Registration.Progress'),
  ok('Registration.Ok'),
  cleared('Registration.Cleared'),
  failed('Registration.Failed'),
  refreshing('Registration.Refreshing');

  final String value;

  const RegistrationState(this.value);

  @override
  String toString() => value;
}
