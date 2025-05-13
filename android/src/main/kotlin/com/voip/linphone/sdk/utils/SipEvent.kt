package com.voip.linphone.sdk.utils

enum class SipEvent(val rawValue: String) {
    /// Status ring when has action call in, call out
    Ring("Sip.Ring"),

    /// Status up when accept calling
    Up("Sip.Up"),

    /// Status connected when accepted calling
    Connected("Sip.Connected"),

    /// Status pause calling
    Paused("Sip.Paused"),

    /// Status resume calling
    Resuming("Sip.Resuming"),

    /// Status call missed
    Missed("Sip.Missed"),

    /// Status hangup calling
    Hangup("Sip.Hangup"),

    /// Status call error
    Error("Sip.Error"),

    /// Status call release
    Released("Sip.Released"),

    /// Status call release
    PushReceive("Sip.PushReceive"),

    /// Token receivce
    PushToken("Sip.PushToken");
}