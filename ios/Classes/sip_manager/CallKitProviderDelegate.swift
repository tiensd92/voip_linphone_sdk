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
    
    var incomingNotification : PushNotification?
    var isCallIncoming = false
    var timerIncoming: Timer?
    
    init(sipManager: SipManager) {
        self.sipManager = sipManager
        let providerConfiguration = CXProviderConfiguration(localizedName: Bundle.main.infoDictionary!["CFBundleName"] as! String)
        providerConfiguration.supportsVideo = true
        providerConfiguration.supportedHandleTypes = [.generic]
        
        providerConfiguration.maximumCallsPerCallGroup = 1
        providerConfiguration.maximumCallGroups = 1
        
        provider = CXProvider(configuration: providerConfiguration)
        super.init()
        //provider.setDelegate(self, queue: nil) // The CXProvider delegate will trigger CallKit related callbacks
        
    }
    
    func incomingCall(_ notification: PushNotification) {
        if isCallIncoming {
            timerIncoming?.invalidate()
            timerIncoming = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) {_ in
                self.stopCall()
            }
            return
        }
        
        timerIncoming?.invalidate()
        timerIncoming = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) {_ in
            self.stopCall()
        }
        
        self.incomingNotification = notification
        isCallIncoming = true
        
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type:.generic, value: notification.displayName)
        provider.reportNewIncomingCall(with: notification.uuid, update: update, completion: { error in })
    }
    
    func stopCall() {
        // Report to CallKit a call must end
        if let uuid = self.incomingNotification?.uuid {
            let endCallAction = CXEndCallAction(call: uuid)
            let transaction = CXTransaction(action: endCallAction)
            mCallController.request(transaction, completion: { error in })
        }
        
        isCallIncoming = false
        self.incomingNotification = nil
    }
}


// In this extension, we implement the action we want to be done when CallKit is notified of something.
// This can happen through the CallKit GUI in the app, or directly in the code (see, incomingCall(), stopCall() functions above)
extension CallKitProviderDelegate: CXProviderDelegate {
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        if let address = incomingNotification?.fromUri, let uuid = incomingNotification?.uuid, let caller = incomingNotification?.displayName {
            let url = URL(string: "rubiklab-2ndphone://2ndphone.com/call?address=\(address)&uuid=\(uuid)&caller=\(caller)")!
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        
        isCallIncoming = false
        action.fulfill()
        stopCall()
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
