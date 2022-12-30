//
//  HAOCameraConfig.swift
//  HaoCamera
//
//  Created by Me55a on 2021/5/24.
//

import Foundation
import AVFoundation

struct CameraConfig {
    var videoPreset: AVCaptureSession.Preset = .high
    var photoPreset: AVCaptureSession.Preset = .photo
    
    var preferredFrontCamera: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
    var preferredBackCamera: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
}
