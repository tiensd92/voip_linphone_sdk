package com.voip.linphone.sdk.utils

enum class CallType(val rawValue: String) {
    /// call out
    outbound("Call.Outbound"),
    /// call in
    inbound("Call.Inbound");
}
