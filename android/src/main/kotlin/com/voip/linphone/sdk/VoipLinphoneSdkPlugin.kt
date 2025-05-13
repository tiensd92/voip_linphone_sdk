package com.voip.linphone.sdk

import android.os.Build
import com.voip.linphone.sdk.models.SipConfiguaration
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** VoipLinphoneSdkPlugin */
class VoipLinphoneSdkPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var sipManager: SipManager = SipManager.instance()

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "voip_linphone_sdk")
        channel.setMethodCallHandler(this)

        eventChannel =
            EventChannel(flutterPluginBinding.binaryMessenger, "voip_linphone_sdk_event_channel")
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initSipModule" -> {
                call.argument<Map<String, Any>>("sipConfiguration")?.let { arguments ->
                    val sipConfiguaration = SipConfiguaration(
                        ext = arguments["ext"] as String,
                        password = arguments["password"] as String,
                        domain = arguments["domain"] as String,
                        port = arguments["port"] as Int,
                        transportType = arguments["transportType"] as String,
                        isKeepAlive = arguments["isKeepAlive"] as Boolean
                    )

                    try {
                        sipManager.initSipModule(sipConfiguaration)
                        result.success(true)
                    } catch (exception: Exception) {
                        result.error("500", exception.localizedMessage, null)
                    }
                } ?: run {
                    result.error("500", "Sip configuration is not valid", null)
                }
            }

            "call" -> {
                val phoneNumber = call.argument<String>("recipient")
                val isRecording = call.argument<Boolean>("isRecording")

                if (phoneNumber == null || isRecording == null) {
                    result.error("404", "Recipient is not valid", null)
                } else {
                    sipManager.call(
                        recipient = phoneNumber,
                        isRecording = isRecording,
                        result = result
                    )
                }
            }

            "hangup" -> {
                sipManager.hangup(result)
            }

            "answer" -> {
                sipManager.answer(result)
            }

            "reject" -> {
                sipManager.reject(result)
            }

            "transfer" -> {
                call.argument<String>("extension")?.let { ext ->
                    sipManager.transfer(ext, result)
                } ?: run {
                    result.error("404", "Extension is not valid", null)
                }
            }

            "pause" -> {
                sipManager.pause(result)
            }

            "resume" -> {
                sipManager.resume(result)
            }

            "sendDTMF" -> {
                call.argument<String>("recipient")?.let { dtmf ->
                    sipManager.sendDTMF(dtmf, result)
                } ?: run {
                    result.error("404", "DTMF is not valid", null)
                }
            }

            "toggleSpeaker" -> {
                call.argument<String>("kind")?.let { kind ->
                    sipManager.toggleSpeaker(kind, result)
                } ?: run {
                    result.error("404", "Audio Device Kind is not valid", null)
                }
            }

            "toggleMic" -> {
                sipManager.toggleMic(result)
            }

            "refreshSipAccount" -> {
                sipManager.refreshSipAccount(result)
            }

            "unregisterSipAccount" -> {
                sipManager.unregisterSipAccount(result)
            }

            "getCallId" -> {
                sipManager.getCallId(result)
            }

            "getMissedCalls" -> {
                sipManager.getMissCalls(result)
            }

            "getSipRegistrationState" -> {
                sipManager.getSipReistrationState(result)
            }

            "isMicEnabled" -> {
                sipManager.isMicEnabled(result)
            }

            "isSpeakerEnabled" -> {
                sipManager.isSpeakerEnabled(result)
            }

            "removeListener" -> {
                sipManager.removeListener()
            }

            "getPlatformVersion" -> {
                result.success("Android ${Build.DEVICE}")
            }

            "registerPush" -> {
                result.success(true)
            }

            "audioDevices" -> {
                sipManager.getAudioDevices(result)
            }

            "currentAudioDevice" -> {
                sipManager.getCurrentAudioDevice(result)
            }

            "voipToken" -> {
                result.notImplemented()
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    companion object {
        var eventSink: EventChannel.EventSink? = null
    }
}
