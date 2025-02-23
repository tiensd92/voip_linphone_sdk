import Flutter
import AVFAudio
import UIKit
import PushKit
import CallKit

public class VoipLinphoneSdkPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var sipManager: SipManager = SipManager.instance
    static var eventSink: FlutterEventSink?
    private var provider: CXProvider?
    private var voipRegistry: PKPushRegistry?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = VoipLinphoneSdkPlugin()
        let channel = FlutterMethodChannel(name: "voip_linphone_sdk", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        let eventChannel = FlutterEventChannel(name: "voip_linphone_sdk_event_channel", binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(instance)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch(call.method) {
        case "initSipModule":
            if let arguments = call.arguments as? [String:Any],
               let jsonString = arguments["sipConfiguration"] as? [String:Any],
               let jsonData = toJson(from: jsonString),
               let sipConfiguration = SipConfiguaration.toObject(JSONString: jsonData){
                do {
                    try sipManager.initSipModule(sipConfiguration: sipConfiguration)
                    initPushKit()
                } catch(let error) {
                    NSLog(error.localizedDescription)
                    result(FlutterError(code: "500", message: error.localizedDescription, details: nil))
                }
            } else {
                result(FlutterError(code: "500", message: "Sip configuration is not valid", details: nil))
            }
            break
        case "call":
            if let arguments = call.arguments as? [String:Any], let phoneNumber = arguments["recipient"] as? String, let isRecording = arguments["isRecording"] as? Bool {
                sipManager.call(recipient: phoneNumber, isRecording: isRecording, result: result)
            } else {
                result(FlutterError(code: "404", message: "Recipient is not valid", details: nil))
            }
            break
        case "hangup":
            sipManager.hangup(result: result)
            break
        case "answer":
            sipManager.answer(result: result)
            break
        case "reject":
            sipManager.reject(result: result)
            break
        case "transfer":
            if let arguments = call.arguments as? [String:Any], let ext = arguments["extension"] as? String {
                sipManager.transfer(recipient: ext, result: result)
            } else {
                result(FlutterError(code: "404", message: "Extension is not valid", details: nil))
            }
            
            break
        case "pause":
            sipManager.pause(result: result)
            break
        case "resume":
            sipManager.resume(result: result)
            break
        case "sendDTMF":
            if let arguments = call.arguments as? [String:Any], let dtmf = arguments["recipient"] as? String {
                sipManager.sendDTMF(dtmf: dtmf, result: result)
            } else {
                result(FlutterError(code: "404", message: "DTMF is not valid", details: nil))
            }
            
            break
        case "toggleSpeaker":
            if let arguments = call.arguments as? [String:Any], let kind = arguments["kind"] as? String {
                sipManager.toggleSpeaker(kind: kind, result: result)
            } else {
                result(FlutterError(code: "404", message: "Audio Device Kind is not valid", details: nil))
            }
            break
        case "toggleMic":
            sipManager.toggleMic(result: result)
            break
        case "refreshSipAccount":
            sipManager.refreshSipAccount(result: result)
            break
        case "unregisterSipAccount":
            sipManager.unregisterSipAccount(result: result)
            break
        case "getCallId":
            sipManager.getCallId(result: result)
            break
        case "getMissedCalls":
            sipManager.getMissCalls(result: result)
            break
        case "getSipRegistrationState":
            sipManager.getSipReistrationState(result: result)
            break
        case "isMicEnabled":
            sipManager.isMicEnabled(result: result)
            break
        case "isSpeakerEnabled":
            sipManager.isSpeakerEnabled(result: result)
            break
        case "removeListener":
            sipManager.removeListener()
            break
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
            break
        case "registerPush":
            registerPush()
            break
        case "audioDevices":
            sipManager.getAudioDevices(result: result)
        case "currentAudioDevice":
            sipManager.getCurrentAudioDevice(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        VoipLinphoneSdkPlugin.eventSink = events
        NSLog("onListen")
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        VoipLinphoneSdkPlugin.eventSink = nil
        NSLog("onCancel")
        return nil
    }
    
    private func registerPush() {
        voipRegistry = PKPushRegistry(queue: nil)
        voipRegistry?.delegate = self
        voipRegistry?.desiredPushTypes = [.voIP]
    }
    
    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _  in
                print(">> requestNotificationAuthorization granted: \(granted)")
            }
    }
    
    private func initPushKit() {
        UNUserNotificationCenter.current().delegate = self
        requestNotificationAuthorization()
        
        let config = CXProviderConfiguration(localizedName: "2ndPhone")
        config.supportsVideo = false
        config.supportedHandleTypes = [.generic]
        config.maximumCallsPerCallGroup = 1
        config.maximumCallGroups = 1
        self.provider = CXProvider(configuration: config)
    }
}

extension VoipLinphoneSdkPlugin: PKPushRegistryDelegate {
    
    public func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        if type == .voIP {
            let voipToken = registry.pushToken(for: .voIP)?.map { String(format: "%02X", $0) }.joined() ?? ""
            print("Voip token: \(voipToken)")
            let data = ["event": SipEvent.PushToken.rawValue, "body": ["voip_token": voipToken]] as [String: Any]
            Self.eventSink?(data)
        }
    }
    
    public func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        if type == .voIP {
            let uuid = UUID()
            let caller = payload.dictionaryPayload["from_number"] as? String ?? ""
            let callee = payload.dictionaryPayload["to_number"] as? String ?? ""
            let data = ["event": SipEvent.PushReceive.rawValue, "body": ["call_id": "\(uuid)", "from_number": caller, "callee": callee]] as [String: Any]
            Self.eventSink?(data)
            
            reportIncommingCall(uuid, caller, completion: completion)
        }
    }
    
    public func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        
    }
    
    private func reportIncommingCall(_ uuid: UUID, _ caller: String, completion: @escaping () -> Void) {
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .phoneNumber,
                                       value: "1077")
        update.localizedCallerName = "1077"
        
        self.provider?.reportNewIncomingCall(with: uuid, update: update , completion: { [weak self] error in
            completion()
        })
    }
}

extension VoipLinphoneSdkPlugin: UNUserNotificationCenterDelegate {
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: (UNNotificationPresentationOptions) -> Void
    ) {
        print(">> willPresent: \(notification)")
        completionHandler([.alert, .sound, .badge])
    }
}
