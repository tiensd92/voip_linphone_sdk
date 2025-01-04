enum SipEvent {
  accountRegistrationStateChanged('AccountRegistrationStateChanged'),
  ring('Ring'),
  up('Up'),
  paused('Paused'),
  resuming('Resuming'),
  missed('Missed'),
  hangup('Hangup'),
  error('Error');
  // Released

  final String value;

  const SipEvent(this.value);

  @override
  String toString() => value;
}
