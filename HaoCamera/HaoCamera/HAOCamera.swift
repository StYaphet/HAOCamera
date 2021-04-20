//
//  HAOCameraModel.swift
//  HaoCamera
//
//  Created by Me55a on 2020/10/19.
//

import UIKit
import AVFoundation
class HAOCamera {
    private var captureSession : AVCaptureSession!
    var currentCameraPosition : AVCaptureDevice.Position
    var currentVideoInput: AVCaptureInput?
    lazy var cameraPreviewView : HAOCameraPreviewView = HAOCameraPreviewView(frame: .zero)
    var isCapturing: Bool {
        return self.captureSession.isRunning
    }

    enum CameraConfigError: Error {
        case canNotAddInput
        case canNotAddOutput
    }

    init() {
        captureSession = AVCaptureSession.init()
        currentCameraPosition = .back
    }

    func setupCaptureSession(with containerView: UIView) throws {

        captureSession.beginConfiguration()

        if self.currentCameraPosition == .front {
            self.changeToFrontCameraInput()
        } else if self.currentCameraPosition == .back {
            self.changeToBackCameraInput()
        }

        let audioDevice = AVCaptureDevice.default(for: .audio)
        guard let audioDeviceInput = try?
                AVCaptureDeviceInput(device: audioDevice!),
              captureSession.canAddInput(audioDeviceInput)
        else {
            return
        }
        captureSession.addInput(audioDeviceInput)

        let photoOutput = AVCapturePhotoOutput()
        guard captureSession.canAddOutput(photoOutput) else { return }
        captureSession.sessionPreset = .photo
        captureSession.addOutput(photoOutput)

        self.cameraPreviewView.videoPreviewLayer.session = captureSession

        self.cameraPreviewView.removeFromSuperview()
        self.cameraPreviewView.frame = containerView.bounds
        containerView.addSubview(self.cameraPreviewView)

        captureSession.commitConfiguration()
    }

    func changeToBackCameraInput() {
        captureSession.beginConfiguration()

        if let videoInput = self.currentVideoInput {
            self.captureSession.removeInput(videoInput)
        }

        let backVideoDevice = AVCaptureDevice.default(.builtInDualCamera,
                                                      for: .video,
                                                      position: .back)
        guard let backVideoDeviceInput = try?
                AVCaptureDeviceInput(device: backVideoDevice!),
              captureSession.canAddInput(backVideoDeviceInput)
        else {
            return
        }
        captureSession.addInput(backVideoDeviceInput)
        self.currentVideoInput = backVideoDeviceInput
        self.currentCameraPosition = .back
        captureSession.commitConfiguration()
    }

    func changeToFrontCameraInput() {
        captureSession.beginConfiguration()

        if let videoInput = self.currentVideoInput {
            self.captureSession.removeInput(videoInput)
        }

        let frontVideoDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                       for: .video,
                                                       position: .front)

        guard let frontVideoDeviceInput = try?
                AVCaptureDeviceInput(device: frontVideoDevice!),
              captureSession.canAddInput(frontVideoDeviceInput)
        else {
            return
        }
        captureSession.addInput(frontVideoDeviceInput)
        self.currentVideoInput = frontVideoDeviceInput
        self.currentCameraPosition = .front
        captureSession.commitConfiguration()
    }

    func swapCameraPosition() {
        if self.currentCameraPosition == .back {
            self.changeToFrontCameraInput()
        } else if self.currentCameraPosition == .front {
            self.changeToBackCameraInput()
        }
    }

    func startCapture() {
        self.captureSession.startRunning()
    }

    func stopCapture() {
        self.captureSession.stopRunning()
    }
}

class HAOCameraPreviewView: UIView {
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}