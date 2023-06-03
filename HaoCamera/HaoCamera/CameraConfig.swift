//
//  HAOCameraConfig.swift
//  HaoCamera
//
//  Created by Me55a on 2021/5/24.
//

import Foundation
import AVFoundation

struct CameraConfig {
    var videoPreset: AVCaptureSession.Preset = .hd4K3840x2160
    var photoPreset: AVCaptureSession.Preset = .photo
    
    var preferredFrontCamera: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
    var preferredBackCamera: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
    
    var videoFrontStabilizationMode: AVCaptureVideoStabilizationMode = .standard
    var videoBackStabilizationMode: AVCaptureVideoStabilizationMode = .standard
}
