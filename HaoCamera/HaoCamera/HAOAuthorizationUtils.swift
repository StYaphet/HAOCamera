//
//  HAOAuthorizationUtils.swift
//  HaoCamera
//
//  Created by me55a on 2020/10/19.
//

import Foundation
import AVFoundation

struct HAOAuthorizationUtils {
    
    static func requestCameraAuthorization(callback:@escaping (Bool) -> Void) {
        self.requestAuthorization(for: .video, with: callback)
    }

    static func requestMicphoneAuthorization(callback: @escaping (Bool) -> Void) {
        self.requestAuthorization(for: .audio, with: callback)
    }
    
    private static func requestAuthorization(for type: AVMediaType,with callback:@escaping (Bool) -> (Void)) {
        switch AVCaptureDevice.authorizationStatus(for: type) {
            case .authorized:
                callback(true)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: type, completionHandler: callback)
            case .denied, .restricted:
                callback(false)
        @unknown default:
            fatalError()
        }
    }
}

