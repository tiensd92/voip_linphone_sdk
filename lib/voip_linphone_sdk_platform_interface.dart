import 'dart:async';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'voip_linphone_sdk.dart';
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
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
  }

  Future<void> initSipModule(SipConfiguration sipConfiguration) async {
    throw UnimplementedError('initSipModule() has not been implemented.');
  }

  Future<bool> call(String phoneNumber) async {
    throw UnimplementedError('call() has not been implemented.');
  }

  Future<bool> hangup() async {
    throw UnimplementedError('hangup() has not been implemented.');
  }

  Future<bool> answer() async {
    throw UnimplementedError('answer() has not been implemented.');
  }

  Future<bool> reject() async {
    throw UnimplementedError('reject() has not been implemented.');
  }

  Future<bool> transfer(String extension) async {
    throw UnimplementedError('transfer() has not been implemented.');
  }

  Future<bool> pause() async {
    throw UnimplementedError('pause() has not been implemented.');
  }

  Future<bool> resume() async {
    throw UnimplementedError('resume() has not been implemented.');
  }

  Future<bool> sendDTMF(String dtmf) async {
    throw UnimplementedError('sendDTMF() has not been implemented.');
  }

  Future<bool> toggleSpeaker(String audioDevice) async {
    throw UnimplementedError('toggleSpeaker() has not been implemented.');
  }

  Future<bool> toggleMic() async {
    throw UnimplementedError('toggleMic() has not been implemented.');
  }

  Future<bool> refreshSipAccount() async {
    throw UnimplementedError('refreshSipAccount() has not been implemented.');
  }

  Future<bool> unregisterSipAccount() async {
    throw UnimplementedError('unregisterSipAccount() has not been implemented.');
  }

  Future<String> getCallId() async {
    throw UnimplementedError('getCallId() has not been implemented.');
  }

  Future<int> getMissedCalls() async {
    throw UnimplementedError('getMissedCalls() has not been implemented.');
  }

  Future<String> getSipRegistrationState() async {
    throw UnimplementedError('getSipRegistrationState() has not been implemented.');
  }

  Future<bool> isMicEnabled() async {
    throw UnimplementedError('isMicEnabled() has not been implemented.');
  }

  Future<bool> isSpeakerEnabled() async {
    throw UnimplementedError('isSpeakerEnabled() has not been implemented.');
  }

  Future<void> registerPush() async {
    throw UnimplementedError('registerPush() has not been implemented.');
  }

  StreamController<VoipEvent> get eventStreamController {
    throw UnimplementedError('eventStreamController has not been implemented.');
  }

  Future<Map<Object?, Object?>> getAudioDevices() async {
    throw UnimplementedError('getAudioDevices() has not been implemented.');
  }

  Future<String?> getCurrentAudioDevice() async {
    throw UnimplementedError('getCurrentAudioDevice() has not been implemented.');
  }
}
