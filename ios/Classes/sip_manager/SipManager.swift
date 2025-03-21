//
//  SipManager.swift
//  voip24h_sdk_mobile
//
//  Created by Phát Nguyễn on 12/08/2022.

import Foundation
import linphonesw
import Flutter
import CallKit
import PushKit
import AVFAudio

class SipManager: NSObject {
    
    static let instance = SipManager()
    var mCore: Core!
    private var timeStartStreamingRunning: Int64 = 0
    private var isPause: Bool = false
    private var isRecording: Bool = false
    private var coreDelegate : CoreDelegate!
    private var provider: CXProvider?
    var mCall: Call?
    var isCallRunning: Bool = false
    var isCallIncoming: Bool = false
    var incomingCallName: String?
    var remoteAddress : String = "Nobody yet"
    
    static let X_UUID_HEADER: String = "X-UUID"
    static let EXTENSTION_KEY: String = "extension"
    static let PHONE_NUMBER_KEY: String = "phoneNumber"
    static let CALL_TYPE_KEY: String = "callType"
    static let CALL_ID_KEY: String = "callId"
    static let DURATION_KEY: String = "duration"
    static let MESSAGE_KEY: String = "message"
    static let TOTAL_MISSED_KEY: String = "totalMissed"
    
    var mProviderDelegate: CallKitProviderDelegate!
    var timerIncoming: Timer?
    
    public override init() {
        super.init()
        
        do {
            try mCore = Factory.Instance.createCore(configPath: "", factoryConfigPath: "", systemContext: nil)
            mCore.pushNotificationEnabled = true
            mProviderDelegate = CallKitProviderDelegate(sipManager: self)
            coreDelegate = CoreDelegateStub(
                onPushNotificationReceived: {(core: Core, payload: String) in
                    if let jsonData = payload.data(using: .utf8) {
                        do {
                            let pushNotification = try JSONDecoder().decode(PushNotification.self, from: jsonData)
                            //self.mCore.processPushNotification(callId: pushNotification.aps.alert.incoming_caller_id)
                            self.mProviderDelegate?.incomingCallUUID = UUID(uuidString: pushNotification.aps.alert.uuid)
                        } catch { }
                    }
                },
                onCallStateChanged: {(
                    core: Core,
                    call: Call,
                    state: Call.State?,
                    message: String
                ) in
                    
                    print("state: \(state) - message: \(message)")
                    
                    switch (state) {
                    case .PushIncomingReceived:
                        self.timerIncoming?.invalidate()
                        self.timerIncoming = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) {
                            timer in
                            self.isCallIncoming = false
                            self.isCallRunning = false
                            self.mProviderDelegate?.stopCall()
                        }
                        
                        if !self.isCallIncoming {
                            self.mProviderDelegate?.incomingCall()
                        }
                        
                        self.mCall = call
                        self.isCallIncoming = true
                        
                        do {
                            try self.mCall?.accept()
                        } catch {
                            print(error)
                        }
                        break
                    case .IncomingReceived:
                        // If app is in foreground, it's likely that we will receive the SIP invite before the Push notification
                        if !self.isCallIncoming {
                            self.mProviderDelegate?.incomingCall()
                        }
                        
                        self.mCall = call
                        self.isCallIncoming = true
                        self.remoteAddress = call.remoteAddress!.asStringUriOnly()
                        break
                    case .OutgoingEarlyMedia:
                        let ext = core.defaultAccount?.contactAddress?.username ?? ""
                        let phoneNumber = call.remoteAddress?.username ?? ""
                        self.sendEvent(eventName: SipEvent.Ring.rawValue, body: [SipManager.EXTENSTION_KEY: ext, SipManager.PHONE_NUMBER_KEY: phoneNumber, SipManager.CALL_TYPE_KEY: CallType.inbound.rawValue])
                        break
                    case .OutgoingInit, .OutgoingRinging, .OutgoingProgress:
                        // First state an outgoing call will go through
                        let ext = core.defaultAccount?.contactAddress?.username ?? ""
                        let phoneNumber = call.remoteAddress?.username ?? ""
                        self.sendEvent(eventName: SipEvent.Ring.rawValue, body: [SipManager.EXTENSTION_KEY: ext, SipManager.PHONE_NUMBER_KEY: phoneNumber, SipManager.CALL_TYPE_KEY: CallType.outbound.rawValue])
                        break
                    case .Connected:
                        self.timerIncoming?.invalidate()
                        self.isCallIncoming = false
                        self.isCallRunning = true

                        let callId = call.callLog?.callId ?? ""
                        self.sendEvent(eventName: SipEvent.Connected.rawValue, body: [SipManager.CALL_ID_KEY: callId])
                        break
                    case .StreamsRunning:
                        if self.timeStartStreamingRunning <= 0 {
                            self.timeStartStreamingRunning = Int64(Date().timeIntervalSince1970 * 1000)
                        }
                        
                        if self.isRecording {
                            self.startRecording()
                        }
                        
                        self.isPause = false
                        let callId = call.callLog?.callId ?? ""
                        self.sendEvent(eventName: SipEvent.Up.rawValue, body: [SipManager.CALL_ID_KEY: callId])
                        break
                    case .Pausing, .PausedByRemote, .Paused:
                        self.isPause = true
                        self.sendEvent(eventName: SipEvent.Paused.rawValue, body: nil)
                        break
                    case .Resuming:
                        self.sendEvent(eventName: SipEvent.Resuming.rawValue, body: nil)
                        break
                    case .Released:
                        if(self.isMissed(callLog: call.callLog)) {
                            let callee = call.remoteAddress?.username ?? ""
                            let totalMissed = core.missedCallsCount
                            self.sendEvent(eventName: SipEvent.Missed.rawValue, body: [SipManager.PHONE_NUMBER_KEY: callee, SipManager.TOTAL_MISSED_KEY: totalMissed])
                        }
                        
                        if (self.isCallRunning) {
                            self.mProviderDelegate?.stopCall()
                        }
                        break
                    case .End:
                        let duration = self.timeStartStreamingRunning == 0 ? 0 : Int64(Date().timeIntervalSince1970 * 1000) - self.timeStartStreamingRunning
                        self.sendEvent(eventName: SipEvent.Hangup.rawValue, body: [SipManager.DURATION_KEY: duration])
                        self.timeStartStreamingRunning = 0
                        
                        if (self.isCallRunning) {
                            self.mProviderDelegate?.stopCall()
                        }
                        break
                    case .Error:
                        self.sendEvent(eventName: SipEvent.Error.rawValue, body: [SipManager.MESSAGE_KEY: message])
                        
                        if (self.isCallRunning) {
                            self.mProviderDelegate?.stopCall()
                        }
                        break
                    case .IncomingEarlyMedia: break
                    case .EarlyUpdatedByRemote: break
                    case .EarlyUpdating: break
                    case .Idle: break
                    case .Updating: break
                    case .UpdatedByRemote: break
                    case .Referred: break
                    case .none: break
                    }
                    
                },
                //                onAudioDevicesListUpdated: { (core: Core) in
                //                    let currentAudioDeviceType = core.currentCall?.outputAudioDevice?.type
                //                    if(currentAudioDeviceType != AudioDevice.Kind.Speaker && currentAudioDeviceType != AudioDevice.Kind.Earpiece) {
                //                        return
                //                    }
                //                    let audioOutputType = AudioOutputType.allCases[currentAudioDeviceType!.rawValue].rawValue
                //                    self.sendEvent(withName: "AudioDevicesChanged", body: ["audioOutputType": audioOutputType])
                //                },
                onAccountRegistrationStateChanged: { (core: Core, account: Account, state: RegistrationState, message: String) in
                    self.sendEvent(eventName: state.name, body: [SipManager.MESSAGE_KEY: message])
                }
            )
        } catch {
            NSLog(error.localizedDescription)
        }
    }
    
    private func createParams(eventName: String, body: [String: Any]?) -> [String:Any] {
        if body == nil {
            return [
                "event": eventName
            ] as [String: Any]
        } else {
            return [
                "event": eventName,
                "body": body!
            ] as [String: Any]
        }
    }
    
    private func sendEvent(eventName: String, body: [String: Any]?) {
        let data = createParams(eventName: eventName, body: body)
        VoipLinphoneSdkPlugin.eventSink?(data)
    }
    
    public func initSipModule(sipConfiguration: SipConfiguaration) throws {
        mCore.keepAliveEnabled = sipConfiguration.isKeepAlive
        if mCore.defaultAccount?.params?.registerEnabled == true {
            unregisterSipAccount(result: nil)
        } else {
            try mCore.start()
        }
        
        mCore.removeDelegate(delegate: coreDelegate)
        mCore.addDelegate(delegate: coreDelegate)
        try initSipAccount(ext: sipConfiguration.ext, password: sipConfiguration.password, domain: sipConfiguration.domain, port: sipConfiguration.port, transportType: sipConfiguration.toLpTransportType())
    }
    
    private func initSipAccount(ext: String, password: String, domain: String, port: Int, transportType: TransportType) throws {
        let authInfo = try Factory.Instance.createAuthInfo(username: ext, userid: "", passwd: password, ha1: "", realm: "", domain: domain)
        let accountParams = try mCore.createAccountParams()
        let identity = try Factory.Instance.createAddress(addr: String("sip:" + ext + "@" + domain))
        try! accountParams.setIdentityaddress(newValue: identity)
        let address = try Factory.Instance.createAddress(addr: String("sip:" + domain))
        try address.setTransport(newValue: transportType)
        try accountParams.setServeraddress(newValue: address)
        accountParams.registerEnabled = true
        // Enable push notifications on this account
        //accountParams.pushNotificationAllowed = true
        // We're in a sandbox application, so we must set the provider to "apns.dev" since it will be "apns" by default, which is used only for production apps
        // accountParams.pushNotificationConfig?.provider = "apns.dev"
        let account = try mCore.createAccount(params: accountParams)
        mCore.addAuthInfo(info: authInfo)
        try mCore.addAccount(account: account)
        mCore.defaultAccount = account
    }
    
    func call(recipient: String, isRecording: Bool, result: FlutterResult?) {
        NSLog("Try to call")
        do {
            // As for everything we need to get the SIP URI of the remote and convert it sto an Address
            let domain: String? = mCore.defaultAccount?.params?.domain
            if (domain == nil) {
                NSLog("Can't create sip uri")
                result?(FlutterError(code: "500", message: "Can't create sip uri", details: nil))
                return
            }
            let sipUri = String("sip:" + recipient + "@" + domain!)
            let remoteAddress = try Factory.Instance.createAddress(addr: sipUri)
            
            // We also need a CallParams object
            // Create call params expects a Call object for incoming calls, but for outgoing we must use null safely
            let params = try mCore.createCallParams(call: nil)
            
            // We can now configure it
            // Here we ask for no encryption but we could ask for ZRTP/SRTP/DTLS
            params.mediaEncryption = MediaEncryption.None
            params.addCustomHeader(headerName: SipManager.X_UUID_HEADER, headerValue: UUID().uuidString)
            
            // If we wanted to start the call with video directly
            //params.videoEnabled = true
            
            // Finally we start the call
            if let call = mCore.inviteAddressWithParams(addr: remoteAddress, params: params) {
                NSLog("Call successful")
                result?(true)
            } else {
                NSLog("Create Call failed")
                result?(FlutterError(code: "500", message: "Create Call failed", details: nil))
            }
        } catch {
            NSLog(error.localizedDescription)
            result?(FlutterError(code: "500", message: error.localizedDescription, details: nil))
        }
    }
    
    func answer(result: FlutterResult) {
        NSLog("Try to answer")
        do {
            let coreCall = mCore.currentCall
            if(coreCall == nil) {
                NSLog("Current call not found")
                return result(false)
            }
            try coreCall!.accept()
            NSLog("Answer successful")
            result(true)
        } catch {
            NSLog(error.localizedDescription)
            result(FlutterError(code: "500", message: error.localizedDescription, details: nil))
        }
    }
    
    func hangup(result: FlutterResult) {
        NSLog("Try to hangup")
        do {
            if (mCore.callsNb == 0) {
                NSLog("Current call not found")
                return result(false)
            }
            
            // If the call state isn't paused, we can get it using core.currentCall
            let coreCall = (mCore.currentCall != nil) ? mCore.currentCall : mCore.calls[0]
            if(coreCall == nil) {
                NSLog("Current call not found")
                return result(false)
            }
            
            if(coreCall!.state == Call.State.IncomingReceived) {
                try coreCall!.decline(reason: Reason.Declined)
                NSLog("Hangup successful")
                return result(true)
            }
            
            // Terminating a call is quite simple
            try coreCall!.terminate()
            NSLog("Hangup successful")
            result(true)
            // result("Hangup successful")
        } catch {
            NSLog(error.localizedDescription)
            result(FlutterError(code: "500", message: error.localizedDescription, details: nil))
        }
    }
    
    func reject(result: FlutterResult) {
        NSLog("Try to reject")
        do {
            let coreCall = mCore.currentCall
            if(coreCall == nil) {
                NSLog("Current call not found")
                return result(false)
            }
            
            // Reject a call
            try coreCall!.decline(reason: Reason.Forbidden)
            try coreCall!.terminate()
            NSLog("Reject successful")
            result(true)
            // result("Reject successful")
        } catch {
            NSLog(error.localizedDescription)
            result(FlutterError(code: "500", message: error.localizedDescription, details: nil))
        }
    }
    
    func pause(result: FlutterResult) {
        NSLog("Try to pause")
        do {
            if (mCore.callsNb == 0) {
                NSLog("Current call not found")
                return result(false)
            }
            
            let coreCall = (mCore.currentCall != nil) ? mCore.currentCall : mCore.calls[0]
            
            if(coreCall == nil) {
                // result(FlutterError(code: "404", message: "No call to pause", details: nil))
                NSLog("Current call not found")
                return result(false)
            }
            
            // Pause a call
            try coreCall!.pause()
            NSLog("Pause successful")
            result(true)
            // result("Pause successful")
        } catch {
            NSLog(error.localizedDescription)
            result(FlutterError(code: "500", message: error.localizedDescription, details: nil))
        }
    }
    
    func resume(result: FlutterResult) {
        NSLog("Try to resume")
        do {
            if (mCore.callsNb == 0) {
                NSLog("Current call not found")
                return result(false)
            }
            
            let coreCall = (mCore.currentCall != nil) ? mCore.currentCall : mCore.calls[0]
            
            if(coreCall == nil) {
                // result(FlutterError(code: "404", message: "No to call to resume", details: nil))
                NSLog("Current call not found")
                result(false)
            }
            
            // Resume a call
            try coreCall!.resume()
            NSLog("Resume successful")
            result(true)
            // result("Resume successful")
        } catch {
            NSLog(error.localizedDescription)
            result(FlutterError(code: "500", message: error.localizedDescription, details: nil))
        }
    }
    
    func transfer(recipient: String, result: FlutterResult) {
        NSLog("Try to transfer")
        do {
            if (mCore.callsNb == 0) { return }
            
            let coreCall = (mCore.currentCall != nil) ? mCore.currentCall : mCore.calls[0]
            
            let domain: String? = mCore.defaultAccount?.params?.domain
            
            if (domain == nil) {
                // result(FlutterError(code: "404", message: "Can't create sip uri", details: nil))
                NSLog("Can't create sip uri")
                return result(false)
            }
            
            let address = mCore.interpretUrl(url: String("sip:\(recipient)@\(domain!)"))
            if(address == nil) {
                // result(FlutterError(code: "404", message: "Can't create address", details: nil))
                NSLog("Can't create address")
                return result(false)
            }
            
            if(coreCall == nil) {
                // result(FlutterError(code: "404", message: "No call to transfer", details: nil))
                NSLog("Current call not found")
                result(false)
            }
            
            // Transfer a call
            try coreCall!.transferTo(referTo: address!)
            NSLog("Transfer successful")
            result(true)
            // result("Transfer successful")
        } catch {
            NSLog(error.localizedDescription)
            result(FlutterError(code: "500", message: error.localizedDescription, details: nil))
        }
    }
    
    func sendDTMF(dtmf: String, result: FlutterResult) {
        do {
            let coreCall = mCore.currentCall
            if(coreCall == nil) {
                NSLog("Current call not found")
                result(FlutterError(code: "500", message: "Current call not found", details: nil))
                return
            }
            
            // Send IVR
            try coreCall!.sendDtmf(dtmf: dtmf.utf8CString[0])
            NSLog("Send DTMF successful")
            result(true)
        } catch {
            NSLog(error.localizedDescription)
            result(FlutterError(code: "500", message: error.localizedDescription, details: nil))
        }
    }
    
    func toggleSpeaker(kind: String, result: FlutterResult) {
        let coreCall = mCore.currentCall
        if(coreCall == nil) {
            return result(FlutterError(code: "404", message: "Current call not found", details: nil))
        }
        
        let currentAudioDevice = coreCall!.outputAudioDevice
        let audioDeviceKind = AudioDevice.Kind.allValues.first{ $0.name == kind} ?? .Unknown
        
        for audioDevice in mCore.audioDevices {
            if audioDevice.type == audioDeviceKind {
                coreCall!.outputAudioDevice = audioDevice
                return result(true)
            }
        }
        
        result(FlutterError(code: "404", message: "Audio Device Kind not found", details: nil))
    }
    
    func toggleMic(result: FlutterResult) {
        let coreCall = mCore.currentCall
        if(coreCall == nil) {
            result(FlutterError(code: "404", message: "Current call not found", details: nil))
            return
        }
        
        mCore.micEnabled = !mCore.micEnabled
        result(mCore.micEnabled)
    }
    
    func refreshSipAccount(result: FlutterResult? = nil) {
        mCore.refreshRegisters()
        result?(true)
    }
    
    func unregisterSipAccount(result: FlutterResult?) {
        NSLog("Try to unregister")
        if let account = mCore.defaultAccount {
            let params = account.params
            let clonedParams = params?.clone()
            clonedParams?.registerEnabled = false
            account.params = clonedParams
            mCore.clearProxyConfig()
            deleteSipAccount()
            result?(true)
        } else {
            // result(FlutterError(code: "404", message: "Sip account not found", details: nil))
            NSLog("Sip account not found")
            result?(false)
        }
    }
    
    private func deleteSipAccount() {
        // To completely remove an Account
        if let account = mCore.defaultAccount {
            mCore.removeAccount(account: account)
            
            // To remove all accounts use
            mCore.clearAccounts()
            
            // Same for auth info
            mCore.clearAllAuthInfo()
        }
    }
    
    func getCallId(result: FlutterResult) {
        let callId = mCore.currentCall?.callLog?.callId
        if (callId != nil && !callId!.isEmpty) {
            result(callId)
        } else {
            result(FlutterError(code: "404", message: "Call ID not found", details: nil))
        }
    }
    
    func getMissCalls(result: FlutterResult) {
        result(mCore.missedCallsCount)
    }
    
    func getSipReistrationState(result: FlutterResult) {
        let state = mCore.defaultAccount?.state
        if(state != nil) {
            result(state?.name)
        } else {
            result(FlutterError(code: "404", message: "Register state not found", details: nil))
        }
    }
    
    func isMicEnabled(result: FlutterResult) {
        result(mCore.micEnabled)
    }
    
    func isSpeakerEnabled(result: FlutterResult) {
        let currentAudioDevice = mCore.currentCall?.outputAudioDevice
        let speakerEnabled = currentAudioDevice?.type == AudioDevice.Kind.Speaker
        result(speakerEnabled)
    }
    
    func removeListener() {
        mCore.removeDelegate(delegate: coreDelegate)
    }
    
    private func isMissed(callLog: CallLog?) -> Bool {
        return (callLog?.dir == Call.Dir.Incoming && callLog?.status == Call.Status.Missed)
    }
    
    func getAudioDevices(result: FlutterResult) {
        let audioDevices = mCore.audioDevices
        var mapAudioDevices = [String : String]()
        for audioDevice in audioDevices {
            mapAudioDevices[audioDevice.type.name] = audioDevice.deviceName
        }
        
        result(mapAudioDevices)
    }
    
    func getCurrentAudioDevice(result: FlutterResult) {
        let audioDevice = mCore.currentCall?.outputAudioDevice?.type.name
        result(audioDevice)
    }
    
    func startRecording() {
        if let uuidString = mCore.currentCall?.params?.getCustomHeader(headerName: SipManager.X_UUID_HEADER) {
            let duration = self.timeStartStreamingRunning == 0 ? 0 : Int64(Date().timeIntervalSince1970 * 1000) - self.timeStartStreamingRunning
            if let appFolder = Bundle.main.resourceURL {
                let pathFile = appFolder.appendingPathComponent("\(uuidString)_\(duration).mp3")
                mCore.recordFile = pathFile.absoluteString
                mCore.currentCall?.startRecording()
            }
        }
    }
    
    func stopRecording() {
        mCore.currentCall?.stopRecording()
    }
}

extension AudioDevice.Kind {
    var name: String {
        switch(self) {
        case .Unknown:
            return "Unknown"
        case .Microphone:
            return "Microphone"
        case .Earpiece:
            return "Earpiece"
        case .Speaker:
            return "Speaker"
        case .Bluetooth:
            return "Bluetooth"
        case .BluetoothA2DP:
            return "BluetoothA2DP"
        case .Telephony:
            return "Telephony"
        case .AuxLine:
            return "AuxLine"
        case .GenericUsb:
            return "GenericUsb"
        case .Headset:
            return "Headset"
        case .Headphones:
            return "Headphones"
        case .HearingAid:
            return "HearingAid"
        }
    }
    
    static var allValues: [AudioDevice.Kind] {
        return [.Unknown, .Microphone, .Earpiece, .Speaker, .Bluetooth, .BluetoothA2DP, .Telephony, .AuxLine, .GenericUsb, .Headset, .Headphones, .HearingAid]
    }
}

struct APS: Codable {
    let alert: Alert
}

struct Alert: Codable {
    let incoming_caller_id: String
    let incoming_caller_name: String
    let uuid: String
}

struct PushNotification: Codable {
    let aps: APS
}


