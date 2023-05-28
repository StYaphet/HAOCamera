//
//  HAOCameraPreviewView.swift
//  HaoCamera
//
//  Created by 郝一鹏 on 2023/2/25.
//

import UIKit
import AVFoundation

class CameraPreviewView: UIView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentMode = .scaleAspectFit
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        contentMode = .scaleAspectFit
    }
}
