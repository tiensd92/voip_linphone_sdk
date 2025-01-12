enum AudioDeviceKind {
  unknown("Unknown"),
  microphone("Microphone"),
  earpiece("Earpiece"),
  speaker("Speaker"),
  bluetooth("Bluetooth"),
  bluetoothA2DP("BluetoothA2DP"),
  telephony("Telephony"),
  auxLine("AuxLine"),
  genericUsb("GenericUsb"),
  headset("Headset"),
  headphones("Headphones"),
  hearingAid("HearingAid");

  final String name;

  const AudioDeviceKind(this.name);
}

class AudioDevice {
  final AudioDeviceKind type;
  final String deviceName;

  AudioDevice({
    required this.type,
    required this.deviceName,
  });
}
