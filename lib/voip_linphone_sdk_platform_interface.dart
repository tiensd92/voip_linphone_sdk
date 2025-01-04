import 'dart:async';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'src/callkit/model/sip_configuration.dart';
import 'src/callkit/voip_event.dart';
import 'voip_linphone_sdk_method_channel.dart';

abstract class VoipLinphoneSdkPlatform extends PlatformInterface {
  /// Constructs a VoipLinphoneSdkPlatform.
  VoipLinphoneSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static VoipLinphoneSdkPlatform _instance = MethodChannelVoipLinphoneSdk();

  /// The default instance of [VoipLinphoneSdkPlatform] to use.
  ///
  /// Defaults to [MethodChannelVoipLinphoneSdk].
  static VoipLinphoneSdkPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [VoipLinphoneSdkPlatform] when
  /// they register themselves.
  static set instance(VoipLinphoneSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<void> initSipModule(SipConfiguration sipConfiguration) async {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<bool> call(String phoneNumber) async {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<bool> hangup() async {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<bool> answer() async {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<bool> reject() async {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<bool> transfer(String extension) async {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<bool> pause() async {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<bool> resume() async {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<bool> sendDTMF(String dtmf) async {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<bool> toggleSpeaker() async {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<bool> toggleMic() async {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<bool> refreshSipAccount() async {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<bool> unregisterSipAccount() async {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<String> getCallId() async {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<int> getMissedCalls() async {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<String> getSipRegistrationState() async {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<bool> isMicEnabled() async {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<bool> isSpeakerEnabled() async {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<void> registerPush() async {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  StreamController<VoipEvent> get eventStreamController {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
