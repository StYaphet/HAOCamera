//
//  ViewController.swift
//  HaoCamera
//
//  Created by Me55a on 2020/10/19.
//

import UIKit
import AVFoundation
import SnapKit

class ViewController: UIViewController {

    var cameraModel: HAOCamera?

    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var previewView: HAOCameraPreviewView!
    @IBOutlet weak var swapButton: UIButton!

    @IBAction func swapButtonClicked(_ sender: UIButton) {
        self.cameraModel?.swapCameraPosition()
    }
    @IBAction func recordButtonClicked(_ sender: UIButton) {

        guard let camera = self.cameraModel else {
            return
        }

        if camera.isCapturing {
            camera.stopCapture()
        } else {
            camera.startCapture()
        }
    }

    override func viewDidLoad() {
        self.recordButton.setTitle("Pause", for: .normal)
    }

    override func viewDidAppear(_ animated: Bool) {
        HAOAuthorizationUtils.requestCameraAuthorization { (granted) in
            print("Camera \(granted ? "granted" : "not granted")")
        }
        
        HAOAuthorizationUtils.requestMicphoneAuthorization { (granted) in
            print("Micphone \(granted ? "granted" : "not granted")")
        }
        HAOAuthorizationUtils.requestPhotoLibraryAuthorization { (granted) in
            print("Photo Library \(granted ? "granted" : "not granted")")
        }

        cameraModel = HAOCamera()
        guard let cameraModel = self.cameraModel else {
            return
        }
        try? cameraModel.setupCaptureSession(with: self.previewView)
        cameraModel.startCapture()
    }

    func getFrontCamera() -> [AVCaptureDevice] {

        let deviceType = [
            AVCaptureDevice.DeviceType.builtInWideAngleCamera,
            AVCaptureDevice.DeviceType.builtInTelephotoCamera,
            AVCaptureDevice.DeviceType.builtInUltraWideCamera,
        ]
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: deviceType, mediaType: .video, position: .front)
        return discoverySession.devices
    }
}

