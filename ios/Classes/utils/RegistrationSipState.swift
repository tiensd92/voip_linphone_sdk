//
//  RegistrationSipState.swift
//  voip24h_sdk_mobile
//
//  Created by Phát Nguyễn on 15/08/2022.
//

import Foundation
import linphonesw

extension RegistrationState {
    var name: String {
        switch self {
        case .None: return "Registration.None"
        case .Progress: return "Registration.Progress"
        case .Ok: return "Registration.Ok"
        case .Cleared: return "Registration.Cleared"
        case .Failed: return "Registration.Failed"
        case .Refreshing: return "Registration.Refreshing"
        }
    }
}
