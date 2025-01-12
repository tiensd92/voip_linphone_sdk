//
//  SipEvent.swift
//  voip24h_sdk_mobile
//
//  Created by Phát Nguyễn on 15/08/2022.
//

import Foundation

enum SipEvent : String {
    /// Status ring when has action call in, call out
    case Ring = "Sip.Ring"
    /// Status up when accept calling
    case Up = "Sip.Up"
    /// Status connected when accepted calling
    case Connected = "Sip.Connected"
    /// Status pause calling
    case Paused = "Sip.Paused"
    /// Status resume calling
    case Resuming = "Sip.Resuming"
    /// Status call missed
    case Missed = "Sip.Missed"
    /// Status hangup calling
    case Hangup = "Sip.Hangup"
    /// Status call error
    case Error = "Sip.Error"
    /// Status call release
    case Released = "Sip.Released"
    case PushReceive = "Sip.PushReceive"
    ///  Token receivce
    case PushToken = "Sip.PushToken"
}
