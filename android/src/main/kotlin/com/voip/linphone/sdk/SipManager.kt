package com.voip.linphone.sdk

import android.content.Context
import androidx.annotation.WorkerThread
import com.voip.linphone.sdk.models.SipConfiguaration
import com.voip.linphone.sdk.utils.CallType
import com.voip.linphone.sdk.utils.SipEvent
import org.linphone.core.AudioDevice
import org.linphone.core.Call
import org.linphone.core.CallLog
import org.linphone.core.Core
import org.linphone.core.CoreListener
import org.linphone.core.CoreListenerStub
import org.linphone.core.Factory
import org.linphone.core.LogCollectionState
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

    fun getConfigPath(context: Context): String {
        return context.filesDir.absolutePath + "/" + CONFIG_FILE_NAME
    }

    fun getFactoryConfigPath(context: Context): String {
        return context.filesDir.absolutePath + "/linphonerc"
    }

    @WorkerThread
    fun initialize(context: Context, sipConfiguration: SipConfiguaration) {
        try {
            Factory.instance().setLogCollectionPath(context.filesDir.absolutePath)
            Factory.instance().enableLogCollection(LogCollectionState.Enabled)
            // For VFS
            Factory.instance().setCacheDir(context.cacheDir.absolutePath)
            mCore = Factory.instance().createCore(null, null, context)
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
            initSipModule(sipConfiguration)
        } catch (exception: Exception) {
            throw exception
        }
    }

    @WorkerThread
    private fun initSipModule(sipConfiguration: SipConfiguaration) {
        mCore.isKeepAliveEnabled = sipConfiguration.isKeepAlive
        if (mCore.defaultAccount?.params?.isRegisterEnabled == true) {
            unregisterSipAccount()
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
        mCore.start()
    }

    @WorkerThread
    private fun initSipAccount(
        ext: String,
        password: String,
        domain: String,
        port: Int,
        transportType: TransportType
    ) {
        val authInfo = Factory.instance().createAuthInfo(
            ext,
            null,
            password,
            null,
            null,
            domain,
            null,
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

    @WorkerThread
    fun unregisterSipAccount(): Boolean {
        if (mCore.defaultAccount == null) {
            return false
        } else {
            val account = mCore.defaultAccount!!
            val params = account.params
            val clonedParams = params.clone()
            clonedParams.isRegisterEnabled = false
            account.params = clonedParams
            mCore.clearProxyConfig()
            deleteSipAccount()
            return true
        }
    }

    @WorkerThread
    fun getCallId(): String? {
        val callId = mCore.currentCall?.callLog?.callId
        if (callId?.isEmpty() == true) {
            return callId
        }

        throw Exception("Call ID not found")
    }

    @WorkerThread
    fun getMissCalls(): Int {
        return mCore.missedCallsCount
    }

    @WorkerThread
    fun getSipReistrationState(): String {
        val state = mCore.defaultAccount?.state
        if (state != null) {
            return state.name
        }

        throw Exception("Register state not found")
    }

    @WorkerThread
    fun isMicEnabled(): Boolean {
        return mCore.isMicEnabled
    }

    @WorkerThread
    fun isSpeakerEnabled(): Boolean {
        val currentAudioDevice = mCore.currentCall?.outputAudioDevice
        val speakerEnabled = currentAudioDevice?.type == AudioDevice.Type.Speaker
        return speakerEnabled
    }

    @WorkerThread
    fun removeListener() {
        mCore.removeListener(mCoreListener)
    }

    @WorkerThread
    fun getAudioDevices(): Map<String, String> {
        val audioDevices = mCore.audioDevices
        var mapAudioDevices = mutableMapOf<String, String>()
        for (audioDevice in audioDevices) {
            mapAudioDevices[audioDevice.type.name] = audioDevice.deviceName
        }

        return mapAudioDevices
    }

    @WorkerThread
    fun getCurrentAudioDevice(): String? {
        val audioDevice = mCore.currentCall?.outputAudioDevice?.type?.name
        return audioDevice
    }

    @WorkerThread
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

    @WorkerThread
    fun call(
        recipient: String,
        isRecording: Boolean,
        uuid: UUID? = null,
    ) {
        // As for everything we need to get the SIP URI of the remote and convert it sto an Address
        val domain: String? = mCore.defaultAccount?.params?.domain
        if (domain == null) {
            throw Exception("Can't create sip uri")
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
            throw Exception("Create Call failed")
        }

        // Finally we start the call
        val call = mCore.inviteAddressWithParams(remoteAddress, params)
        if (call != null) {
            this.isRecording = isRecording
        } else {
            throw Exception("Create Call failed")
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

    @WorkerThread
    fun hangup(): Boolean {
        if (mCore.callsNb == 0) {
            return false
        }

        // If the call state isn't paused, we can get it using core.currentCall
        val coreCall = mCore.currentCall ?: mCore.calls[0]
        if (coreCall == null) {
            return false
        }

        if (coreCall.state == Call.State.IncomingReceived) {
            coreCall.decline(Reason.Declined)
            return false
        }

        // Terminating a call is quite simple
        coreCall.terminate()
        return true
        // result("Hangup successful")

    }

    @WorkerThread
    fun answer(): Boolean {
        val coreCall = mCore.currentCall
        if (coreCall == null) {
            return false
        }
        coreCall.accept()
        return true
    }

    @WorkerThread
    fun reject(): Boolean {
        val coreCall = mCore.currentCall
        if (coreCall == null) {
            return false
        }

        // Reject a call
        coreCall.decline(Reason.Forbidden)
        coreCall.terminate()
        return true
        // result("Reject successful")

    }

    @WorkerThread
    fun transfer(recipient: String): Boolean {
        if (mCore.callsNb == 0) {
            return false
        }

        val coreCall = mCore.currentCall ?: mCore.calls[0]
        val domain: String? = mCore.defaultAccount?.params?.domain

        if (domain == null) {
            return false
        }

        val address = mCore.interpretUrl("sip:$recipient@$domain)")
        if (address == null) {
            return false
        }

        if (coreCall == null) {
            return false
        }

        // Transfer a call
        coreCall.transferTo(address)
        return true
    }

    @WorkerThread
    fun pause(): Boolean {
        if (mCore.callsNb == 0) {
            return false
        }

        val coreCall = mCore.currentCall ?: mCore.calls[0]

        if (coreCall == null) {
            return false
        }

        // Pause a call
        coreCall.pause()
        return true
    }

    @WorkerThread
    fun resume(): Boolean {
        if (mCore.callsNb == 0) {
            return false
        }

        val coreCall = mCore.currentCall ?: mCore.calls[0]

        if (coreCall == null) {
            return false
        }

        // Resume a call
        coreCall.resume()
        return true
    }

    @WorkerThread
    fun sendDTMF(dtmf: String): Boolean {
        val coreCall = mCore.currentCall
        if (coreCall == null) {
            return false
        }

        // Send IVR
        coreCall.sendDtmf(dtmf[0])
        return true
    }

    @WorkerThread
    fun toggleSpeaker(kind: String): Boolean {
        val coreCall = mCore.currentCall
        if (coreCall == null) {
            throw Exception("Current call not found")
        }

        val currentAudioDevice = coreCall.outputAudioDevice
        val audioDeviceKind = AudioDevice.Type.entries.first { it.name == kind }

        for (audioDevice in mCore.audioDevices) {
            if (audioDevice.type == audioDeviceKind) {
                coreCall.outputAudioDevice = audioDevice
                return true
            }
        }

        throw Exception("Audio Device Kind not found")
    }

    @WorkerThread
    fun toggleMic(): Boolean {
        val coreCall = mCore.currentCall
        if (coreCall == null) {
            throw Exception("Current call not found")
        }

        mCore.isMicEnabled = !mCore.isMicEnabled
        return mCore.isMicEnabled
    }

    @WorkerThread
    fun refreshSipAccount(): Boolean {
        try {
            mCore.refreshRegisters()
        } catch (ignore: Exception) {
        }
        return true
    }

    @WorkerThread
    fun startRecording() {
        mCore.currentCall?.startRecording()
    }

    @WorkerThread
    private fun isMissed(callLog: CallLog?): Boolean {
        return (callLog?.dir == Call.Dir.Incoming && callLog.status == Call.Status.Missed)
    }

    private fun sendEvent(eventName: String, body: Map<String, Any?>?) {
        val data = createParams(eventName = eventName, body = body)
        VoipLinphoneSdkPlugin.sendEvent(data)
    }

    private fun createParams(eventName: String, body: Map<String, Any?>?): Map<String, Any?> {
        return if (body == null) {
            mutableMapOf("event" to eventName)
        } else {
            mutableMapOf("event" to eventName, "body" to body)
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
        const val CONFIG_FILE_NAME = ".linphonerc"

        fun instance(): SipManager {
            if (_instance == null) {
                _instance = SipManager()
            }

            return _instance!!
        }
    }
}