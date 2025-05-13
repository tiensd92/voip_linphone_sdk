package com.voip.linphone.sdk

import com.voip.linphone.sdk.models.SipConfiguaration
import com.voip.linphone.sdk.utils.CallType
import com.voip.linphone.sdk.utils.SipEvent
import io.flutter.plugin.common.MethodChannel
import org.linphone.core.AudioDevice
import org.linphone.core.Call
import org.linphone.core.CallLog
import org.linphone.core.Core
import org.linphone.core.CoreListener
import org.linphone.core.CoreListenerStub
import org.linphone.core.Factory
import org.linphone.core.MediaEncryption
import org.linphone.core.ProxyConfig
import org.linphone.core.Reason
import org.linphone.core.RegistrationState
import org.linphone.core.TransportType
import java.util.Calendar
import java.util.Timer
import java.util.UUID

class SipManager {
    private lateinit var mCore: Core
    private lateinit var mCoreListener: CoreListener
    private var timeStartStreamingRunning: Long = 0
    private var isPause: Boolean = false
    private var isRecording: Boolean = false
    private var timerIncoming: Timer? = null
    private var recordFile: String? = null

    init {
        try {
            mCore = Factory.instance().createCore("", "", null)
            mCore.isPushNotificationEnabled = true
            mCoreListener = object : CoreListenerStub() {
                override fun onRegistrationStateChanged(
                    core: Core,
                    proxyConfig: ProxyConfig,
                    state: RegistrationState?,
                    message: String
                ) {
                    sendEvent(
                        eventName = state?.name ?: "",
                        body = mutableMapOf(message to MESSAGE_KEY)
                    )
                }

                override fun onCallStateChanged(
                    core: Core,
                    call: Call,
                    state: Call.State?,
                    message: String
                ) {
                    when (state) {
                        Call.State.PushIncomingReceived -> {}
                        Call.State.IncomingReceived -> {}
                        Call.State.OutgoingEarlyMedia -> {
                            val ext = core.defaultAccount?.contactAddress?.username ?: ""
                            val phoneNumber = call.remoteAddress.username ?: ""
                            sendEvent(
                                eventName = SipEvent.Ring.rawValue,
                                body = mutableMapOf(
                                    EXTENSTION_KEY to ext,
                                    PHONE_NUMBER_KEY to phoneNumber,
                                    CALL_TYPE_KEY to CallType.inbound.rawValue,
                                )
                            )
                        }

                        Call.State.OutgoingInit, Call.State.OutgoingRinging, Call.State.OutgoingProgress -> {
                            // First state an outgoing call will go through
                            val ext = core.defaultAccount?.contactAddress?.username ?: ""
                            val phoneNumber = call.remoteAddress.username ?: ""
                            sendEvent(
                                eventName = SipEvent.Ring.rawValue,
                                body = mutableMapOf(
                                    EXTENSTION_KEY to ext,
                                    PHONE_NUMBER_KEY to phoneNumber,
                                    CALL_TYPE_KEY to CallType.outbound.rawValue
                                )
                            )
                        }

                        Call.State.Connected -> {
                            val callId = call.callLog.callId ?: ""
                            sendEvent(
                                eventName = SipEvent.Connected.rawValue,
                                body = mutableMapOf(CALL_ID_KEY to callId)
                            )
                        }

                        Call.State.StreamsRunning -> {
                            if (timeStartStreamingRunning <= 0) {
                                timeStartStreamingRunning = Calendar.getInstance().timeInMillis

                            }

                            if (isRecording) {
                                startRecording()
                            }

                            isPause = false
                            val callId = call.callLog.callId ?: ""
                            sendEvent(
                                eventName = SipEvent.Up.rawValue,
                                body = mutableMapOf(CALL_ID_KEY to callId)
                            )
                        }

                        Call.State.Pausing, Call.State.PausedByRemote, Call.State.Paused -> {
                            isPause = true
                            sendEvent(eventName = SipEvent.Paused.rawValue, body = null)
                        }

                        Call.State.Resuming -> {
                            sendEvent(eventName = SipEvent.Resuming.rawValue, body = null)
                        }

                        Call.State.Released -> {
                            if (isMissed(callLog = call.callLog)) {
                                val callee = call.remoteAddress.username ?: ""
                                val totalMissed = core.missedCallsCount
                                sendEvent(
                                    eventName = SipEvent.Missed.rawValue,
                                    body = mutableMapOf(
                                        PHONE_NUMBER_KEY to callee,
                                        TOTAL_MISSED_KEY to totalMissed
                                    )
                                )
                            }

                            //mProviderDelegate?.incomingCall()
                        }

                        Call.State.End -> {
                            val duration =
                                if (timeStartStreamingRunning == 0L) 0 else (Calendar.getInstance().timeInMillis - timeStartStreamingRunning)
                            sendEvent(
                                eventName = SipEvent.Hangup.rawValue,
                                body = mutableMapOf(
                                    DURATION_KEY to duration,
                                    RECORD_FILE to recordFile
                                )
                            )
                            timeStartStreamingRunning = 0
                        }

                        Call.State.Error -> {
                            sendEvent(
                                eventName = SipEvent.Error.rawValue,
                                body = mutableMapOf(MESSAGE_KEY to message)
                            )
                        }

                        Call.State.IncomingEarlyMedia -> {}
                        Call.State.EarlyUpdatedByRemote -> {}
                        Call.State.EarlyUpdating -> {}
                        Call.State.Idle -> {}
                        Call.State.Updating -> {}
                        Call.State.UpdatedByRemote -> {}
                        Call.State.Referred -> {}
                        else -> {}
                    }
                }
            }
        } catch (_: Exception) {
        }
    }

    fun initSipModule(sipConfiguration: SipConfiguaration) {
        mCore.isKeepAliveEnabled = sipConfiguration.isKeepAlive
        if (mCore.defaultAccount?.params?.isRegisterEnabled == true) {
            unregisterSipAccount(result = null)
        } else {
            mCore.start()
        }

        mCore.removeListener(mCoreListener)
        mCore.addListener(mCoreListener)
        initSipAccount(
            ext = sipConfiguration.ext,
            password = sipConfiguration.password,
            domain = sipConfiguration.domain,
            port = sipConfiguration.port,
            transportType = sipConfiguration.toLpTransportType()
        )
    }

    private fun initSipAccount(
        ext: String,
        password: String,
        domain: String,
        port: Int,
        transportType: TransportType
    ) {
        val authInfo = Factory.instance().createAuthInfo(
            ext,
            "",
            password,
            "",
            "",
            domain
        )
        val accountParams = mCore.createAccountParams()
        val identity = Factory.instance().createAddress("sip:$ext@$domain")
        accountParams.identityAddress = identity
        val address = Factory.instance().createAddress("sip:$domain")
        address?.transport = transportType
        accountParams.serverAddress = address
        accountParams.isRegisterEnabled = true
        // Enable push notifications on this account
        accountParams.pushNotificationAllowed = true
        //accountParams.remotePushNotificationAllowed = true

        val account = mCore.createAccount(accountParams)
        mCore.addAuthInfo(authInfo)
        mCore.addAccount(account)
        mCore.defaultAccount = account
    }

    fun unregisterSipAccount(result: MethodChannel.Result?) {
        if (mCore.defaultAccount == null) {
            result?.success(false)
        } else {
            val account = mCore.defaultAccount!!
            val params = account.params
            val clonedParams = params.clone()
            clonedParams.isRegisterEnabled = false
            account.params = clonedParams
            mCore.clearProxyConfig()
            deleteSipAccount()
            result?.success(true)
        }
    }

    fun getCallId(result: MethodChannel.Result?) {
        val callId = mCore.currentCall?.callLog?.callId
        if (callId?.isEmpty() == true) {
            result?.success(callId)
        } else {
            result?.error("404", "Call ID not found", null)
        }
    }

    fun getMissCalls(result: MethodChannel.Result?) {
        result?.success(mCore.missedCallsCount)
    }

    fun getSipReistrationState(result: MethodChannel.Result?) {
        val state = mCore.defaultAccount?.state
        if (state != null) {
            result?.success(state.name)
        } else {
            result?.error("404", "Register state not found", null)
        }
    }

    fun isMicEnabled(result: MethodChannel.Result?) {
        result?.success(mCore.isMicEnabled)
    }

    fun isSpeakerEnabled(result: MethodChannel.Result?) {
        val currentAudioDevice = mCore.currentCall?.outputAudioDevice
        val speakerEnabled = currentAudioDevice?.type == AudioDevice.Type.Speaker
        result?.success(speakerEnabled)
    }

    fun removeListener() {
        mCore.removeListener(mCoreListener)
    }


    fun getAudioDevices(result: MethodChannel.Result?) {
        val audioDevices = mCore.audioDevices
        var mapAudioDevices = mutableMapOf<String, String>()
        for (audioDevice in audioDevices) {
            mapAudioDevices[audioDevice.type.name] = audioDevice.deviceName
        }

        result?.success(mapAudioDevices)
    }

    fun getCurrentAudioDevice(result: MethodChannel.Result?) {
        val audioDevice = mCore.currentCall?.outputAudioDevice?.type?.name
        result?.success(audioDevice)
    }

    private fun deleteSipAccount() {
        // To completely remove an Account
        mCore.defaultAccount?.let { account ->
            mCore.removeAccount(account)

            // To remove all accounts use
            mCore.clearAccounts()

            // Same for auth info
            mCore.clearAllAuthInfo()
        }
    }

    fun call(
        recipient: String,
        isRecording: Boolean,
        uuid: UUID? = null,
        result: MethodChannel.Result?
    ) {
        try {
            // As for everything we need to get the SIP URI of the remote and convert it sto an Address
            val domain: String? = mCore.defaultAccount?.params?.domain
            if (domain == null) {
                result?.error("500", "Can't create sip uri", null)
                return
            }

            val sipUri = "sip:$recipient@$domain"
            val remoteAddress = Factory.instance().createAddress(sipUri)

            // We also need a CallParams object
            // Create call params expects a Call object for incoming calls, but for outgoing we must use null safely
            val params = mCore.createCallParams(null)
            val uuid = uuid ?: UUID.randomUUID()

            // We can now configure it
            // Here we ask for no encryption but we could ask for ZRTP/SRTP/DTLS
            params?.mediaEncryption = MediaEncryption.None
            params?.addCustomHeader(X_UUID_HEADER, uuid.toString())

            if (isRecording) {
                recordFile = generateRecordingFile(uuid = uuid)
                params?.recordFile = recordFile
            } else {
                recordFile = null
            }

            // If we wanted to start the call with video directly
            //params.videoEnabled = true

            if (remoteAddress == null || params == null) {
                result?.error("500", "Create Call failed", null)
                return
            }

            // Finally we start the call
            val call = mCore.inviteAddressWithParams(remoteAddress, params)
            if (call != null) {
                this.isRecording = isRecording
                result?.success(true)
            } else {
                result?.error("500", "Create Call failed", null)
            }
        } catch (exception: Exception) {
            result?.error("500", exception.localizedMessage, null)
        }
    }

    fun generateRecordingFile(uuid: UUID): String? {
        /*try {
            val appSupportDir =
                FileManager.default.url(for:.applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            val filePath =
                appSupportDir.appendingPathComponent("\(uuid.uuidString).wav").path
            return filePath
        } catch (exception: Exception) {
            return null
        }*/

        return null
    }

    fun hangup(result: MethodChannel.Result?) {
        try {
            if (mCore.callsNb == 0) {
                result?.success(false)
                return
            }

            // If the call state isn't paused, we can get it using core.currentCall
            val coreCall = mCore.currentCall ?: mCore.calls[0]
            if (coreCall == null) {
                result?.success(false)
                return
            }

            if (coreCall.state == Call.State.IncomingReceived) {
                coreCall.decline(Reason.Declined)
                result?.success(false)
                return
            }

            // Terminating a call is quite simple
            coreCall.terminate()
            result?.success(true)
            // result("Hangup successful")
        } catch (exception: Exception) {
            result?.error("500", exception.localizedMessage, null)
        }
    }

    fun answer(result: MethodChannel.Result?) {
        try {
            val coreCall = mCore.currentCall
            if (coreCall == null) {
                result?.success(false)
                return
            }
            coreCall.accept()
            result?.success(true)
        } catch (exception: Exception) {
            result?.error("500", exception.localizedMessage, null)
        }
    }

    fun reject(result: MethodChannel.Result?) {
        try {
            val coreCall = mCore.currentCall
            if (coreCall == null) {
                result?.success(false)
                return
            }

            // Reject a call
            coreCall.decline(Reason.Forbidden)
            coreCall.terminate()
            result?.success(true)
            // result("Reject successful")
        } catch (exception: Exception) {
            result?.error("500", exception.localizedMessage, null)
        }
    }

    fun transfer(recipient: String, result: MethodChannel.Result?) {
        try {
            if (mCore.callsNb == 0) {
                result?.success(false)
                return
            }

            val coreCall = mCore.currentCall ?: mCore.calls[0]
            val domain: String? = mCore.defaultAccount?.params?.domain

            if (domain == null) {
                result?.success(false)
                return
            }

            val address = mCore.interpretUrl("sip:$recipient@$domain)")
            if (address == null) {
                result?.success(false)
                return
            }

            if (coreCall == null) {
                result?.success(false)
                return
            }

            // Transfer a call
            coreCall.transferTo(address)
            result?.success(true)
        } catch (exception: Exception) {
            result?.error("500", exception.localizedMessage, null)
        }
    }

    fun pause(result: MethodChannel.Result?) {
        try {
            if (mCore.callsNb == 0) {
                result?.success(false)
                return
            }

            val coreCall = mCore.currentCall ?: mCore.calls[0]

            if (coreCall == null) {
                result?.success(false)
                return
            }

            // Pause a call
            coreCall.pause()
            result?.success(true)
        } catch (exception: Exception) {
            result?.error("500", exception.localizedMessage, null)
        }
    }

    fun resume(result: MethodChannel.Result?) {
        try {
            if (mCore.callsNb == 0) {
                result?.success(false)
                return
            }

            val coreCall = mCore.currentCall ?: mCore.calls[0]

            if (coreCall == null) {
                result?.success(false)
                return
            }

            // Resume a call
            coreCall.resume()
            result?.success(true)
        } catch (exception: Exception) {
            result?.error("500", exception.localizedMessage, null)
        }
    }

    fun sendDTMF(dtmf: String, result: MethodChannel.Result?) {
        try {
            val coreCall = mCore.currentCall
            if (coreCall == null) {
                result?.success(false)
                return
            }

            // Send IVR
            coreCall.sendDtmf(dtmf[0])
            result?.success(true)
        } catch (exception: Exception) {
            result?.error("500", exception.localizedMessage, null)
        }
    }

    fun toggleSpeaker(kind: String, result: MethodChannel.Result?) {
        val coreCall = mCore.currentCall
        if (coreCall == null) {
            result?.error("404", "Current call not found", null)
            return
        }

        val currentAudioDevice = coreCall.outputAudioDevice
        val audioDeviceKind = AudioDevice.Type.values().first { it.name == kind }


        for (audioDevice in mCore.audioDevices) {
            if (audioDevice.type == audioDeviceKind) {
                coreCall.outputAudioDevice = audioDevice
                result?.success(true)
                return
            }
        }

        result?.error("404", "Audio Device Kind not found", null)
    }

    fun toggleMic(result: MethodChannel.Result?) {
        val coreCall = mCore.currentCall
        if (coreCall == null) {
            result?.error("404", "Current call not found", null)
            return
        }

        mCore.isMicEnabled = !mCore.isMicEnabled
        result?.success(mCore.isMicEnabled)
    }

    fun refreshSipAccount(result: MethodChannel.Result? = null) {
        mCore.refreshRegisters()
        result?.success(true)
    }

    fun startRecording() {
        mCore.currentCall?.startRecording()
    }

    private fun isMissed(callLog: CallLog?): Boolean {
        return (callLog?.dir == Call.Dir.Incoming && callLog.status == Call.Status.Missed)
    }

    private fun sendEvent(eventName: String, body: Map<String, Any?>?) {
        val data = createParams(eventName = eventName, body = body)
        VoipLinphoneSdkPlugin.eventSink?.success(data)
    }

    private fun createParams(eventName: String, body: Map<String, Any?>?): Map<String, Any?> {
        return if (body == null) {
            mutableMapOf("event" to eventName)
        } else {
            mutableMapOf("event " to eventName, "body" to body)
        }
    }

    companion object {
        private var _instance: SipManager? = null
        const val X_UUID_HEADER: String = "X-UUID"
        const val EXTENSTION_KEY: String = "extension"
        const val PHONE_NUMBER_KEY: String = "phoneNumber"
        const val CALL_TYPE_KEY: String = "callType"
        const val CALL_ID_KEY: String = "callId"
        const val DURATION_KEY: String = "duration"
        const val MESSAGE_KEY: String = "message"
        const val TOTAL_MISSED_KEY: String = "totalMissed"
        const val RECORD_FILE: String = "recordFile"

        fun instance(): SipManager {
            if (_instance == null) {
                _instance = SipManager()
            }

            return _instance!!
        }
    }
}