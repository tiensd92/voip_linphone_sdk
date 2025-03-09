import 'dart:async';

import 'package:voip_linphone_sdk/src/callkit/utils/sip_event.dart';

import 'src/callkit/model/sip_configuration.dart';
import 'src/callkit/utils/audio_device.dart';
import 'src/callkit/voip_event.dart';
import 'voip_linphone_sdk_platform_interface.dart';

export 'src/callkit/callkit.dart';
export 'src/callkit/voip_event.dart';
export 'src/callkit/utils/audio_device.dart';

class VoipLinphoneSdk {
  static StreamController<VoipEvent> get eventStreamController =>
      VoipLinphoneSdkPlatform.instance.eventStreamController;

  static Future<String?> getPlatformVersion() {
    return VoipLinphoneSdkPlatform.instance.getPlatformVersion();
  }

  static Future<void> initSipModule(SipConfiguration sipConfiguration) {
    return VoipLinphoneSdkPlatform.instance.initSipModule(sipConfiguration);
  }

  static Future<bool> call(String phoneNumber, bool isRecord) {
    return VoipLinphoneSdkPlatform.instance.call(phoneNumber, isRecord);
  }

  static Future<bool> hangup() {
    return VoipLinphoneSdkPlatform.instance.hangup();
  }

  static Future<bool> answer() {
    return VoipLinphoneSdkPlatform.instance.answer();
  }

  static Future<bool> reject() {
    return VoipLinphoneSdkPlatform.instance.reject();
  }

  static Future<bool> transfer(String extension) {
    return VoipLinphoneSdkPlatform.instance.transfer(extension);
  }

  static Future<bool> pause() {
    return VoipLinphoneSdkPlatform.instance.pause();
  }

  static Future<bool> resume() async {
    return VoipLinphoneSdkPlatform.instance.resume();
  }

  static Future<bool> sendDTMF(String dtmf) {
    return VoipLinphoneSdkPlatform.instance.sendDTMF(dtmf);
  }

  static Future<bool> toggleSpeaker(AudioDeviceKind type) {
    return VoipLinphoneSdkPlatform.instance.toggleSpeaker(type.name);
  }

  static Future<bool> toggleMic() {
    return VoipLinphoneSdkPlatform.instance.toggleMic();
  }

  static Future<bool> refreshSipAccount() {
    return VoipLinphoneSdkPlatform.instance.refreshSipAccount();
  }

  static Future<bool> unregisterSipAccount() {
    return VoipLinphoneSdkPlatform.instance.unregisterSipAccount();
  }

  static Future<String> getCallId() {
    return VoipLinphoneSdkPlatform.instance.getCallId();
  }

  static Future<int> getMissedCalls() {
    return VoipLinphoneSdkPlatform.instance.getMissedCalls();
  }

  static Future<RegistrationState?> getSipRegistrationState() async {
    try {
      final eventName =
          await VoipLinphoneSdkPlatform.instance.getSipRegistrationState();
      try {
        return RegistrationState.values
            .firstWhere((event) => event.value == eventName);
      } catch (_) {
        return null;
      }
    } catch (_) {
      rethrow;
    }
  }

  static Future<bool> isMicEnabled() {
    return VoipLinphoneSdkPlatform.instance.isMicEnabled();
  }

  static Future<bool> isSpeakerEnabled() {
    return VoipLinphoneSdkPlatform.instance.isSpeakerEnabled();
  }

  static Future<void> registerPush() {
    return VoipLinphoneSdkPlatform.instance.registerPush();
  }

  static Future<List<AudioDevice>> getAudioDevices() async {
    List<AudioDevice> audioDevices = [];
    final audioDeviceNames =
        await VoipLinphoneSdkPlatform.instance.getAudioDevices();
    for (final audioDeviceName in audioDeviceNames.keys) {
      final key = audioDeviceName?.toString();
      final deviceName = audioDeviceNames[audioDeviceName]
              ?.toString()
              .replaceAll('[', '')
              .replaceAll(']', '') ??
          '';
      if (key == null || deviceName.isEmpty) continue;

      try {
        final type = AudioDeviceKind.values.firstWhere((e) => e.name == key);
        audioDevices.add(
          AudioDevice(
            type: type,
            deviceName: deviceName,
          ),
        );
      } catch (_) {}
    }
    return audioDevices;
  }

  static Future<AudioDeviceKind?> getCurrentAudioDevice() async {
    final audioDevice =
        await VoipLinphoneSdkPlatform.instance.getCurrentAudioDevice();

    try {
      return AudioDeviceKind.values.firstWhere((e) => e.name == audioDevice);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getVoipToken() async {
    final voipToken = await VoipLinphoneSdkPlatform.instance.getVoipToken();
    return voipToken;
  }
}
