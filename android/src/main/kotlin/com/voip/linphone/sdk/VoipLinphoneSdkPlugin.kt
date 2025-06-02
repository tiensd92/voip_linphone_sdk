package com.voip.linphone.sdk

import android.content.Context
import android.os.Build
import com.voip.linphone.sdk.models.SipConfiguaration
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineName
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/** VoipLinphoneSdkPlugin */
class VoipLinphoneSdkPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private val sipManager: SipManager
        get() = SipManager.instance()

    private val pluginScope =
        CoroutineScope(Dispatchers.IO + SupervisorJob() + CoroutineName("VoipLinphoneSdkPluginScope"))

    private var context: Context? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "voip_linphone_sdk")
        channel.setMethodCallHandler(this)

        eventChannel =
            EventChannel(flutterPluginBinding.binaryMessenger, "voip_linphone_sdk_event_channel")
        eventChannel.setStreamHandler(this)

        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initSipModule" -> {
                call.argument<Map<String, Any>>("sipConfiguration")?.let { arguments ->
                    val sipConfiguaration = SipConfiguaration(
                        ext = arguments["extension"] as String,
                        password = arguments["password"] as String,
                        domain = arguments["domain"] as String,
                        port = arguments["port"] as Int,
                        transportType = arguments["transportType"] as String,
                        isKeepAlive = arguments["isKeepAlive"] as Boolean
                    )

                    context?.let {
                        pluginScope.launch {
                            try {
                                sipManager.initialize(it, sipConfiguaration)
                                launch(Dispatchers.Main) {
                                    result.success(true)
                                }
                            } catch (exception: Exception) {
                                launch(Dispatchers.Main) {
                                    result.error("500", exception.localizedMessage, null)
                                }
                            }
                        }
                    } ?: run {
                        result.error("500", "Sip configuration is not valid", null)
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
                    pluginScope.launch {
                        try {
                            sipManager.call(
                                recipient = phoneNumber,
                                isRecording = isRecording,
                            )
                        } catch (exception: Exception) {
                            launch(Dispatchers.Main) {
                                result.error("500", exception.localizedMessage, null)
                            }
                        }
                    }

                }
            }

            "hangup" -> {
                pluginScope.launch {
                    try {
                        val resultHangup = sipManager.hangup()
                        launch(Dispatchers.Main) {
                            result.success(resultHangup)
                        }
                    } catch (exception: Exception) {
                        launch(Dispatchers.Main) {
                            result.error("500", exception.localizedMessage, null)
                        }
                    }
                }
            }

            "answer" -> {
                pluginScope.launch {
                    try {
                        val resultAnswer = sipManager.answer()
                        launch(Dispatchers.Main) {
                            result.success(resultAnswer)
                        }
                    } catch (exception: Exception) {
                        launch(Dispatchers.Main) {
                            result.error("500", exception.localizedMessage, null)
                        }
                    }
                }
            }

            "reject" -> {
                pluginScope.launch {
                    try {
                        val resultReject = sipManager.reject()
                        launch(Dispatchers.Main) {
                            result.success(resultReject)
                        }
                    } catch (exception: Exception) {
                        launch(Dispatchers.Main) {
                            result.error("500", exception.localizedMessage, null)
                        }
                    }
                }
            }

            "transfer" -> {
                call.argument<String>("extension")?.let { ext ->
                    pluginScope.launch {
                        try {
                            val resultTransfer = sipManager.transfer(ext)
                            launch(Dispatchers.Main) {
                                result.success(resultTransfer)
                            }
                        } catch (exception: Exception) {
                            launch(Dispatchers.Main) {
                                result.error("500", exception.localizedMessage, null)
                            }
                        }
                    }
                } ?: run {
                    result.error("404", "Extension is not valid", null)
                }
            }

            "pause" -> {
                pluginScope.launch {
                    try {
                        val resultPause = sipManager.pause()
                        launch(Dispatchers.Main) {
                            result.success(resultPause)
                        }
                    } catch (exception: Exception) {
                        launch(Dispatchers.Main) {
                            result.error("500", exception.localizedMessage, null)
                        }
                    }
                }
            }

            "resume" -> {
                pluginScope.launch {
                    try {
                        val resultResume = sipManager.resume()
                        launch(Dispatchers.Main) {
                            result.success(resultResume)
                        }
                    } catch (exception: Exception) {
                        launch(Dispatchers.Main) {
                            result.error("500", exception.localizedMessage, null)
                        }
                    }
                }
            }

            "sendDTMF" -> {
                call.argument<String>("recipient")?.let { dtmf ->
                    pluginScope.launch {
                        try {
                            val resultSend = sipManager.sendDTMF(dtmf)
                            launch(Dispatchers.Main) {
                                result.success(resultSend)
                            }
                        } catch (exception: Exception) {
                            launch(Dispatchers.Main) {
                                result.error("500", exception.localizedMessage, null)
                            }
                        }
                    }
                } ?: run {
                    result.error("404", "DTMF is not valid", null)
                }
            }

            "toggleSpeaker" -> {
                call.argument<String>("kind")?.let { kind ->
                    pluginScope.launch {
                        try {
                            val resultToggle = sipManager.toggleSpeaker(kind)
                            launch(Dispatchers.Main) {
                                result.success(resultToggle)
                            }
                        } catch (exception: Exception) {
                            launch(Dispatchers.Main) {
                                result.error("500", exception.localizedMessage, null)
                            }
                        }
                    }
                } ?: run {
                    result.error("404", "Audio Device Kind is not valid", null)
                }
            }

            "toggleMic" -> {
                pluginScope.launch {
                    try {
                        val isMicEnabled = sipManager.toggleMic()
                        launch(Dispatchers.Main) {
                            result.success(isMicEnabled)
                        }
                    } catch (exception: Exception) {
                        launch(Dispatchers.Main) {
                            result.error("500", exception.localizedMessage, null)
                        }
                    }
                }
            }

            "refreshSipAccount" -> {
                pluginScope.launch {
                    try {
                        val resultRefresh = sipManager.refreshSipAccount()
                        launch(Dispatchers.Main) {
                            result.success(resultRefresh)
                        }
                    } catch (exception: Exception) {
                        launch(Dispatchers.Main) {
                            result.error("500", exception.localizedMessage, null)
                        }
                    }
                }
            }

            "unregisterSipAccount" -> {
                pluginScope.launch {
                    try {
                        val resultUnregister = sipManager.unregisterSipAccount()
                        launch(Dispatchers.Main) {
                            result.success(resultUnregister)
                        }
                    } catch (exception: Exception) {
                        launch(Dispatchers.Main) {
                            result.error("500", exception.localizedMessage, null)
                        }
                    }
                }
            }

            "getCallId" -> {
                pluginScope.launch {
                    try {
                        val callId = sipManager.getCallId()
                        launch(Dispatchers.Main) {
                            result.success(callId)
                        }
                    } catch (exception: Exception) {
                        launch(Dispatchers.Main) {
                            result.error("500", exception.localizedMessage, null)
                        }
                    }
                }
            }

            "getMissedCalls" -> {
                pluginScope.launch {
                    try {
                        val resultMissCount = sipManager.getMissCalls()
                        launch(Dispatchers.Main) {
                            result.success(resultMissCount)
                        }
                    } catch (exception: Exception) {
                        launch(Dispatchers.Main) {
                            result.error("500", exception.localizedMessage, null)
                        }
                    }
                }
            }

            "getSipRegistrationState" -> {
                pluginScope.launch {
                    try {
                        val resultState = sipManager.getSipReistrationState()
                        launch(Dispatchers.Main) {
                            result.success(resultState)
                        }
                    } catch (exception: Exception) {
                        launch(Dispatchers.Main) {
                            result.error("500", exception.localizedMessage, null)
                        }
                    }
                }
            }

            "isMicEnabled" -> {
                pluginScope.launch {
                    try {
                        val isMicEnabled = sipManager.isMicEnabled()
                        launch(Dispatchers.Main) {
                            result.success(isMicEnabled)
                        }
                    } catch (exception: Exception) {
                        launch(Dispatchers.Main) {
                            result.error("500", exception.localizedMessage, null)
                        }
                    }
                }
            }

            "isSpeakerEnabled" -> {
                pluginScope.launch {
                    try {
                        val isSpeakerEnabled = sipManager.isSpeakerEnabled()
                        launch(Dispatchers.Main) {
                            result.success(isSpeakerEnabled)
                        }
                    } catch (exception: Exception) {
                        launch(Dispatchers.Main) {
                            result.error("500", exception.localizedMessage, null)
                        }
                    }
                }
            }

            "removeListener" -> {
                pluginScope.launch {
                    sipManager.removeListener()
                }
            }

            "getPlatformVersion" -> {
                result.success("Android ${Build.DEVICE}")
            }

            "registerPush" -> {
                result.success(true)
            }

            "audioDevices" -> {
                pluginScope.launch(Dispatchers.IO) {
                    try {
                        val resultAudioDevices = sipManager.getAudioDevices()
                        launch(Dispatchers.Main) {
                            result.success(resultAudioDevices)
                        }
                    } catch (exception: Exception) {
                        launch(Dispatchers.Main) {
                            result.error("500", exception.localizedMessage, null)
                        }
                    }
                }
            }

            "currentAudioDevice" -> {
                pluginScope.launch {
                    try {
                        val resultAudioDevice = sipManager.getCurrentAudioDevice()
                        launch(Dispatchers.Main) {
                            result.success(resultAudioDevice)
                        }
                    } catch (exception: Exception) {
                        launch(Dispatchers.Main) {
                            result.error("500", exception.localizedMessage, null)
                        }
                    }
                }
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
        context = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    companion object {
        var eventSink: EventChannel.EventSink? = null

        fun sendEvent(data: Map<String, Any?>) {
            GlobalScope.launch(Dispatchers.Main) {
                eventSink?.success(data)
            }
        }
    }
}
