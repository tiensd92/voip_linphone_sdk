//
//  SipManager.swift
//  voip24h_sdk_mobile
//
//  Created by Phát Nguyễn on 12/08/2022.

import Foundation
import linphonesw
import Flutter
import CallKit

class SipManager {
    
    static let instance = SipManager()
    private var mCore: Core!
    private var timeStartStreamingRunning: Int64 = 0
    private var isPause: Bool = false
    private var coreDelegate : CoreDelegate!
    
    public init() {
        do {
            try mCore = Factory.Instance.createCore(configPath: "", factoryConfigPath: "", systemContext: nil)
            coreDelegate = CoreDelegateStub(
                onCallStateChanged: {(
                    core: Core,
                    call: Call,
                    state: Call.State?,
                    message: String
                ) in
                    NSLog("state: \(String(describing: state)) - \(message)")
                    switch (state) {
                    case .IncomingReceived:
                        // Immediately hang up when we receive a call. There's nothing inherently wrong with this
                        // but we don't need it right now, so better to leave it deactivated.
                        // try! call.terminate()
                        let ext = core.defaultAccount?.contactAddress?.username ?? ""
                        let phoneNumber = call.remoteAddress?.username ?? ""
                        self.sendEvent(eventName: EventRing, body: ["extension": ext, "phoneNumber": phoneNumber, "callType": CallType.inbound.rawValue])
                        break
                    case .OutgoingInit:
                        // First state an outgoing call will go through
                        break
                    case .OutgoingProgress:
                        // First state an outgoing call will go through
                        let ext = core.defaultAccount?.contactAddress?.username ?? ""
                        let phoneNumber = call.remoteAddress?.username ?? ""
                        self.sendEvent(eventName: EventRing, body: ["extension": ext, "phoneNumber": phoneNumber, "callType": CallType.outbound.rawValue])
                        break
                    case .OutgoingRinging:
                        // Once remote accepts, ringing will commence (180 response)
                        break
                    case .Connected:
                        break
                    case .StreamsRunning:
                        // This state indicates the call is active.
                        // You may reach this state multiple times, for example after a pause/resume
                        // or after the ICE negotiation completes
                        // Wait for the call to be connected before allowing a call update
                        if(!self.isPause) {
                            self.timeStartStreamingRunning = Int64(Date().timeIntervalSince1970 * 1000)
                        }
                        self.isPause = false
                        let callId = call.callLog?.callId ?? ""
                        self.sendEvent(eventName: EventUp, body: ["callId": callId])
                        break
                    case .Paused:
                        self.isPause = true
                        self.sendEvent(eventName: EventPaused, body: nil)
                        break
                    case .Resuming:
                        self.sendEvent(eventName: EventResuming, body: nil)
                        break
                    case .PausedByRemote:
                        break
                    case .Updating:
                        // When we request a call update, for example when toggling video
                        break
                    case .UpdatedByRemote:
                        break
                    case .Released:
                        if(self.isMissed(callLog: call.callLog)) {
                            let callee = call.remoteAddress?.username ?? ""
                            let totalMissed = core.missedCallsCount
                            self.sendEvent(eventName: EventMissed, body: ["phoneNumber": callee, "totalMissed": totalMissed])
                        }
                        break
                    case .End:
                        let duration = self.timeStartStreamingRunning == 0 ? 0 : Int64(Date().timeIntervalSince1970 * 1000) - self.timeStartStreamingRunning
                        self.sendEvent(eventName: EventHangup, body: ["duration": duration])
                        self.timeStartStreamingRunning = 0
                        break
                    case .Error:
                        if let uuidString = call.params?.getCustomHeader(headerName: "X-UUID"), let uuid = UUID.init(uuidString: uuidString)  {
                            let callController = CXCallController()
                            let endCallAction = CXEndCallAction(call: uuid)
                            let transaction = CXTransaction(action: endCallAction)
                            callController.request(transaction) { _ in
                                
                            }
                        }
                        
                        self.sendEvent(eventName: EventError, body: ["message": message])
                        break
                    default:
                        break
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
                    NSLog("state: \(state), message: \(message)")
                    self.sendEvent(eventName: EventAccountRegistrationStateChanged, body: ["registrationState": state.rawValue >= RegisterSipState.allCases.count ? RegisterSipState.Failed.rawValue : RegisterSipState.allCases[state.rawValue].rawValue, "message": message])
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
    
    func call(recipient: String, result: FlutterResult) {
        NSLog("Try to call")
        do {
            // As for everything we need to get the SIP URI of the remote and convert it sto an Address
            let domain: String? = mCore.defaultAccount?.params?.domain
            if (domain == nil) {
                NSLog("Can't create sip uri")
                result(FlutterError(code: "500", message: "Can't create sip uri", details: nil))
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
            params.addCustomHeader(headerName: "X-UUID", headerValue: UUID().uuidString)
            
            // If we wanted to start the call with video directly
            //params.videoEnabled = true
            
            // Finally we start the call
            if let call = mCore.inviteAddressWithParams(addr: remoteAddress, params: params) {
                NSLog("Call successful")
                result(true)
            } else {
                NSLog("Create Call failed")
                result(FlutterError(code: "500", message: "Create Call failed", details: nil))
            }
        } catch {
            NSLog(error.localizedDescription)
            result(FlutterError(code: "500", message: error.localizedDescription, details: nil))
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
            // if(coreCall!.state == Call.State.IncomingReceived) {
                // try coreCall!.decline(reason: Reason.Forbidden)
                // NSLog("Hangup successful")
                // return result(true)
            // }
            
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
            // try coreCall!.decline(reason: Reason.Forbidden)
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
    
    func toggleSpeaker(result: FlutterResult) {
        let coreCall = mCore.currentCall
        if(coreCall == nil) {
            return result(FlutterError(code: "404", message: "Current call not found", details: nil))
        }
        let currentAudioDevice = coreCall!.outputAudioDevice
        let speakerEnabled = currentAudioDevice?.type == AudioDevice.Kind.Speaker
        
        // We can get a list of all available audio devices using
        // Note that on tablets for example, there may be no Earpiece device
        for audioDevice in mCore.audioDevices {
            // For IOS, the Speaker is an exception, Linphone cannot differentiate Input and Output.
            // This means that the default output device, the earpiece, is paired with the default phone microphone.
            // Setting the output audio device to the microphone will redirect the sound to the earpiece.
            if (speakerEnabled && audioDevice.type == AudioDevice.Kind.Microphone) {
                coreCall!.outputAudioDevice = audioDevice
                return result(false)
            } else if (!speakerEnabled && audioDevice.type == AudioDevice.Kind.Speaker) {
                coreCall!.outputAudioDevice = audioDevice
                return result(true)
            }
            /* If we wanted to route the audio to a bluetooth headset
             else if (audioDevice.type == AudioDevice.Type.Bluetooth) {
             core.currentCall?.outputAudioDevice = audioDevice
             }*/
        }
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
            result(RegisterSipState.allCases[state!.rawValue].rawValue)
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
}
