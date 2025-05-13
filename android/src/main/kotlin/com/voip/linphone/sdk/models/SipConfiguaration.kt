package com.voip.linphone.sdk.models

import com.squareup.moshi.JsonClass
import org.linphone.core.TransportType

@JsonClass(generateAdapter = true)
data class SipConfiguaration(
    var ext: String,
    var password: String,
    var domain: String,
    var port: Int = 5060,
    var transportType: String = "",
    var isKeepAlive: Boolean = false
) {
    fun toLpTransportType(): TransportType {
        return when (transportType) {
            "Tcp" -> TransportType.Tcp
            "Ddp" -> TransportType.Udp
            "Tls" -> TransportType.Tls
            else -> TransportType.Udp
        }
    }
}