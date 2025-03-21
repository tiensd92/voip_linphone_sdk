//
//  CallKitProviderDelegate.swift
//  Pods
//
//  Created by Dino on 18/3/25.
//

import Foundation
import CallKit
import linphonesw
import AVFoundation


class CallKitProviderDelegate : NSObject
{
    private let provider: CXProvider
    let mCallController = CXCallController()
    var sipManager : SipManager!
    
    var incomingCallUUID : UUID?
    
    init(sipManager: SipManager) {
        self.sipManager = sipManager
        let providerConfiguration = CXProviderConfiguration(localizedName: Bundle.main.infoDictionary!["CFBundleName"] as! String)
        providerConfiguration.supportsVideo = true
        providerConfiguration.supportedHandleTypes = [.generic]
        
        providerConfiguration.maximumCallsPerCallGroup = 1
        providerConfiguration.maximumCallGroups = 1
        
        provider = CXProvider(configuration: providerConfiguration)
        super.init()
        provider.setDelegate(self, queue: nil) // The CXProvider delegate will trigger CallKit related callbacks
        
    }
    
    func incomingCall() {
        guard let uuid = incomingCallUUID else {
            return
        }
        
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type:.generic, value: sipManager.incomingCallName ?? "")
        
        provider.reportNewIncomingCall(with: uuid, update: update, completion: { error in }) // Report to CallKit a call is incoming
    }
    
    func stopCall() {
        // Report to CallKit a call must end
        if let uuid = incomingCallUUID {
            let endCallAction = CXEndCallAction(call: uuid)
            let transaction = CXTransaction(action: endCallAction)
            
            mCallController.request(transaction, completion: { error in })
        }
    }
}


// In this extension, we implement the action we want to be done when CallKit is notified of something.
// This can happen through the CallKit GUI in the app, or directly in the code (see, incomingCall(), stopCall() functions above)
extension CallKitProviderDelegate: CXProviderDelegate {
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        do {
            if (sipManager.mCall?.state != .End && sipManager.mCall?.state != .Released)  {
                try sipManager.mCall?.terminate()
            }
        } catch { NSLog(error.localizedDescription) }
        
        sipManager.isCallRunning = false
        sipManager.isCallIncoming = false
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        do {
            // The audio stream is going to start shortly: the AVAudioSession must be configured now.
            // It is worth to note that an application does not have permission to configure the
            // AVAudioSession outside of this delegate action while it is running in background,
            // which is usually the case in an incoming call scenario.
            sipManager.mCore.configureAudioSession();
            try sipManager.mCall?.accept()
            sipManager.isCallRunning = true
        } catch {
            print(error)
        }
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {}
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        // This tutorial is not doing outgoing calls. If it had to do so,
        // configureAudioSession() shall be called from here, just before launching the
        // call.
        // tutorialContext.mCore.configureAudioSession();
        // tutorialContext.mCore.invite("sip:bob@example.net");
        // action.fulfill();
    }
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {}
    func provider(_ provider: CXProvider, perform action: CXPlayDTMFCallAction) {}
    func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {}
    func providerDidReset(_ provider: CXProvider) {}
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        // The linphone Core must be notified that CallKit has activated the AVAudioSession
        // in order to start streaming audio.
        sipManager.mCore.activateAudioSession(activated: true)
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        // The linphone Core must be notified that CallKit has deactivated the AVAudioSession.
        sipManager.mCore.activateAudioSession(activated: false)
    }
}
