//
//  HAOCameraModel.swift
//  HaoCamera
//
//  Created by Me55a on 2020/10/19.
//

import UIKit
import AVFoundation
class Camera: NSObject {

    enum CameraConfigError: Error {
        case canNotAddInput
        case canNotAddOutput
    }

    enum CameraMode {
        case video
        case photo
    }

    private var captureSession : AVCaptureSession!
    var currentCameraPosition : AVCaptureDevice.Position
    var currentVideoInput: AVCaptureInput?
    var photoOutput: AVCapturePhotoOutput?
    var photoHandlerMap = [Int64: PhotoOutputHander]()
    var videoDataOutput: AVCaptureVideoDataOutput?
    
    lazy var cameraPreviewView : HAOCameraPreviewView = HAOCameraPreviewView(frame: .zero)
    var isCapturing: Bool {
        return self.captureSession.isRunning
    }

    var cameraConfig: CameraConfig = CameraConfig()

    var cameraMode: CameraMode

    // 需要一个操作 camera 的队列
    var cameraOperationQueue = DispatchQueue(label: "com.pandada.HAOCameraOperationQueue")

    override init() {
        captureSession = AVCaptureSession.init()
        currentCameraPosition = .back
        cameraMode = .photo
    }

    func setupCaptureSession(with containerView: UIView) throws {
        defer {
            captureSession.commitConfiguration()
        }
        captureSession.beginConfiguration()

        // 1. 添加 input
        //   1.1根据相机位置添加 video input
        if self.currentCameraPosition == .front {
            self.changeToFrontCameraInput()
        } else if self.currentCameraPosition == .back {
            self.changeToBackCameraInput()
        }

        //   1.2添加 audio input
        let audioDevice = AVCaptureDevice.default(for: .audio)
        guard let audioDeviceInput = try?
                AVCaptureDeviceInput(device: audioDevice!),
              captureSession.canAddInput(audioDeviceInput)
        else {
            return
        }
        captureSession.addInput(audioDeviceInput)

        // 2. 添加 output
        //   2.1 添加 photo output
        let photoOutput = AVCapturePhotoOutput()
        guard captureSession.canAddOutput(photoOutput) else { return }
        captureSession.sessionPreset = cameraConfig.photoPreset
        captureSession.addOutput(photoOutput)
        self.photoOutput = photoOutput
        

        // 3. 设置预览视图
        self.cameraPreviewView.videoPreviewLayer.session = captureSession
        self.cameraPreviewView.removeFromSuperview()
        self.cameraPreviewView.frame = containerView.bounds
        containerView.addSubview(self.cameraPreviewView)
    }
}

// MARK: Swap Camera Position
extension Camera {
    /// 切换到摄像头位置
    func swapCameraPosition() {
        if self.currentCameraPosition == .back {
            self.changeToFrontCameraInput()
        } else if self.currentCameraPosition == .front {
            self.changeToBackCameraInput()
        }
    }


    /// 切换到后置摄像头
    func changeToBackCameraInput() {
        captureSession.beginConfiguration()
        defer {
            captureSession.commitConfiguration()
        }
        if let videoInput = self.currentVideoInput {
            self.captureSession.removeInput(videoInput)
        }
        self.currentCameraPosition = .back
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession.init(deviceTypes: cameraConfig.preferredBackCamera,
                                                                           mediaType: .video,
                                                                           position: .back)
        guard let firstDevice: AVCaptureDevice = deviceDiscoverySession.devices.first else { return }
        guard let backVideoDeviceInput =
                try? AVCaptureDeviceInput(device: firstDevice),
              captureSession.canAddInput(backVideoDeviceInput) else { return }
        captureSession.addInput(backVideoDeviceInput)
        self.currentVideoInput = backVideoDeviceInput
    }

    /// 切换到后置摄像头
    func changeToFrontCameraInput() {
        defer {
            captureSession.commitConfiguration()
        }
        captureSession.beginConfiguration()

        if let videoInput = self.currentVideoInput {
            self.captureSession.removeInput(videoInput)
        }
        self.currentCameraPosition = .front
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession.init(deviceTypes: cameraConfig.preferredFrontCamera,
                                                                           mediaType: .video,
                                                                           position: .front)
        guard let firstDevice: AVCaptureDevice = deviceDiscoverySession.devices.first else { return }
        guard let frontVideoDeviceInput =
                try? AVCaptureDeviceInput(device: firstDevice),
              captureSession.canAddInput(frontVideoDeviceInput) else { return }
        captureSession.addInput(frontVideoDeviceInput)
        self.currentVideoInput = frontVideoDeviceInput
    }
}

// MARK: Capture
extension Camera {

    /// 开始摄像头画面采集
    func startCapture() {
        self.cameraOperationQueue.async() {
            self.captureSession.startRunning()
        }
    }

    /// 关闭摄像头画面采集
    func stopCapture() {
        self.cameraOperationQueue.async {
            self.captureSession.stopRunning()
        }
    }
}

// MARK: Photo take
extension Camera {
    func takePicture(with photoSettings: AVCapturePhotoSettings, completion:@escaping (PhotoTakeResult) -> Void) {
        guard let photoOutput = self.photoOutput else { return }
        let photoOutputHandler = PhotoOutputHander { [weak self] handler, result in
            guard let self else { return }
            self.photoHandlerMap[photoSettings.uniqueID] = nil
            completion(result)
        }
        photoHandlerMap[photoSettings.uniqueID] = photoOutputHandler
        self.cameraOperationQueue.async {
            photoOutput.capturePhoto(with: photoSettings,
                                     delegate: photoOutputHandler)
        }
    }
}

extension Camera: AVCapturePhotoCaptureDelegate {
    
    // MARK: Monitoring Capture Progress
    func photoOutput(_ output: AVCapturePhotoOutput,
                     willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        print(output)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput,
                     willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        print(output)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        print(output)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        print(output)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
                     error: Error?) {
        print(output)
    }
    
    
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL,
                     duration: CMTime, photoDisplayTime: CMTime,
                     resolvedSettings: AVCaptureResolvedPhotoSettings,
                     error: Error?) {
        print(output)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishRecordingLivePhotoMovieForEventualFileAt outputFileURL: URL,
                     resolvedSettings: AVCaptureResolvedPhotoSettings) {
        print(output)
    }
}
