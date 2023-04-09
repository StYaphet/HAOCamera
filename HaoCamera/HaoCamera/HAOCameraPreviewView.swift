//
//  HAOCameraPreviewView.swift
//  HaoCamera
//
//  Created by 郝一鹏 on 2023/2/25.
//

import UIKit
import AVFoundation

class HAOCameraPreviewView: UIView {
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}
