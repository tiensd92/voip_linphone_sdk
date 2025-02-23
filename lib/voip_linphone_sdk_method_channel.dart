import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'src/callkit/model/sip_configuration.dart';
import 'src/callkit/utils/sip_event.dart';
import 'src/callkit/voip_event.dart';
import 'voip_linphone_sdk_platform_interface.dart';

/// An implementation of [VoipLinphoneSdkPlatform] that uses method channels.
class MethodChannelVoipLinphoneSdk extends VoipLinphoneSdkPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('voip_linphone_sdk');

  final eventChannel = const EventChannel('voip_linphone_sdk_event_channel');

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  late final Stream broadcastStream = eventChannel.receiveBroadcastStream();

  StreamSubscription? subEventStream;

  final StreamController<VoipEvent> _eventStreamController =
      StreamController.broadcast();

  @override
  StreamController<VoipEvent> get eventStreamController =>
      _eventStreamController;

  @override
  Future<void> initSipModule(SipConfiguration sipConfiguration) async {
    subEventStream?.cancel();
    subEventStream = broadcastStream.listen(_listener);
    await methodChannel.invokeMethod(
        'initSipModule', {"sipConfiguration": sipConfiguration.toJson()});
  }

  void _listener(dynamic event) {
    final eventName = event['event'] as String;

    SipEvent? eventType;
    RegistrationState? state;

    try {
      eventType =
          SipEvent.values.firstWhere((event) => event.value == eventName);
    } catch (_) {}

    try {
      state = RegistrationState.values
          .firstWhere((event) => event.value == eventName);
    } catch (_) {}

    _eventStreamController.add(
      VoipEvent(
        event: eventType,
        state: state,
        body: event['body'],
      ),
    );
  }

  @override
  Future<bool> call(String phoneNumber, bool isRecord) async {
    return await methodChannel.invokeMethod('call', {
      'recipient': phoneNumber,
      'isRecording': isRecord,
    });
  }

  @override
  Future<bool> hangup() async {
    return await methodChannel.invokeMethod('hangup');
  }

  @override
  Future<bool> answer() async {
    return await methodChannel.invokeMethod('answer');
  }

  @override
  Future<bool> reject() async {
    return await methodChannel.invokeMethod('reject');
  }

  @override
  Future<bool> transfer(String extension) async {
    return await methodChannel
        .invokeMethod('transfer', {"extension": extension});
  }

  @override
  Future<bool> pause() async {
    return await methodChannel.invokeMethod('pause');
  }

  @override
  Future<bool> resume() async {
    return await methodChannel.invokeMethod('resume');
  }

  @override
  Future<bool> sendDTMF(String dtmf) async {
    return await methodChannel.invokeMethod('sendDTMF', {
      "recipient": dtmf,
    });
  }

  @override
  Future<bool> toggleSpeaker(String audioDevice) async {
    return await methodChannel.invokeMethod('toggleSpeaker', {
      'kind': audioDevice,
    });
  }

  @override
  Future<bool> toggleMic() async {
    return await methodChannel.invokeMethod('toggleMic');
  }

  @override
  Future<bool> refreshSipAccount() async {
    return await methodChannel.invokeMethod('refreshSipAccount');
  }

  @override
  Future<bool> unregisterSipAccount() async {
    return await methodChannel.invokeMethod('unregisterSipAccount');
  }

  @override
  Future<String> getCallId() async {
    return await methodChannel.invokeMethod('getCallId');
  }

  @override
  Future<int> getMissedCalls() async {
    return await methodChannel.invokeMethod('getMissedCalls');
  }

  @override
  Future<String> getSipRegistrationState() async {
    return await methodChannel.invokeMethod('getSipRegistrationState');
  }

  @override
  Future<bool> isMicEnabled() async {
    return await methodChannel.invokeMethod('isMicEnabled');
  }

  @override
  Future<bool> isSpeakerEnabled() async {
    return await methodChannel.invokeMethod('isSpeakerEnabled');
  }

  @override
  Future<void> registerPush() async {
    return await methodChannel.invokeMethod('registerPush');
  }

  @override
  Future<Map<Object?, Object?>> getAudioDevices() async {
    return await methodChannel.invokeMethod('audioDevices');
  }

  @override
  Future<String?> getCurrentAudioDevice() async {
    return await methodChannel.invokeMethod('currentAudioDevice');
  }
}
