//
//  HAOAuthorizationUtils.swift
//  HaoCamera
//
//  Created by me55a on 2020/10/19.
//

import Foundation
import AVFoundation
import Photos

struct HAOAuthorizationUtils {
    
    static var cameraAuthorized: Bool {
        return authorizedStatus(for: .video) == .authorized
    }
    
    static var microphoneAuthorized: Bool {
        return authorizedStatus(for: .audio) == .authorized
    }
    
    static func requestCameraAuthorization(callback:@escaping (Bool) -> Void) {
        self.requestAuthorization(for: .video, with: callback)
    }

    static func requestMicphoneAuthorization(callback: @escaping (Bool) -> Void) {
        self.requestAuthorization(for: .audio, with: callback)
    }

    static func requestPhotoLibraryAuthorization(callback: @escaping (Bool) -> Void) {
        switch PHPhotoLibrary.authorizationStatus() {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { (status) in
                switch status {
                case .notDetermined, .restricted, .denied:
                    callback(false)
                case .authorized, .limited:
                    callback(true)
                @unknown default:
                    fatalError()
                }
            }
        case .restricted, .denied:
            callback(false)
        case .authorized, .limited:
            callback(true)
        @unknown default:
            fatalError()
        }
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
    
    private static func authorizedStatus(for type: AVMediaType) -> AVAuthorizationStatus {
        return AVCaptureDevice.authorizationStatus(for: type)
    }
}

