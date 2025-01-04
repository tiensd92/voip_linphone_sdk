import 'dart:async';

import 'src/callkit/model/sip_configuration.dart';
import 'src/callkit/voip_event.dart';
import 'voip_linphone_sdk_platform_interface.dart';

export 'src/callkit/callkit.dart';
export 'src/callkit/voip_event.dart';

class VoipLinphoneSdk {
  static StreamController<VoipEvent> get eventStreamController =>
      VoipLinphoneSdkPlatform.instance.eventStreamController;

  static Future<String?> getPlatformVersion() {
    return VoipLinphoneSdkPlatform.instance.getPlatformVersion();
  }

  static Future<void> initSipModule(SipConfiguration sipConfiguration) {
    return VoipLinphoneSdkPlatform.instance.initSipModule(sipConfiguration);
  }

  static Future<bool> call(String phoneNumber) {
    return VoipLinphoneSdkPlatform.instance.call(phoneNumber);
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

  static Future<bool> toggleSpeaker() {
    return VoipLinphoneSdkPlatform.instance.toggleSpeaker();
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

  static Future<String> getSipRegistrationState() {
    return VoipLinphoneSdkPlatform.instance.getSipRegistrationState();
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
}
