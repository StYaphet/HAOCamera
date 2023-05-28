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
    
    enum CameraConfigWriterError: Error {
        case canNotAddVideoDataInput
        case canNotAddAudioDataInput
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
    var audioDataOutput: AVCaptureAudioDataOutput?
    
    private var assetWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    private var audioWriterInput: AVAssetWriterInput?
    
    var isRecording: Bool {
        return self.isWritingStarted
    }
    private var isWritingStarted = false
    private var firstSampleTime: CMTime = CMTime.invalid
    private var lastSampleBuffer: CMSampleBuffer?
    
    var cameraOperationQueue = DispatchQueue(label: "com.pandada.HAOCameraOperationQueue")
    var sampleBufferQueue: DispatchQueue = DispatchQueue(label: "com.pandada.HAOCameraVideoDataQueue")
    
    lazy var cameraPreviewView : CameraPreviewView = CameraPreviewView(frame: .zero)
    var isCapturing: Bool {
        return self.captureSession.isRunning
    }

    var cameraConfig: CameraConfig = CameraConfig()

    var cameraMode: CameraMode

    // 需要一个操作 camera 的队列
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override init() {
        
        captureSession = AVCaptureSession.init()
        currentCameraPosition = .back
        cameraMode = .photo
        
        super.init()
        
        addObservers()
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

//        // 2. 添加 output
//        //   2.1 添加 photo output
//        let photoOutput = AVCapturePhotoOutput()
//        guard captureSession.canAddOutput(photoOutput) else { return }
//        captureSession.sessionPreset = cameraConfig.photoPreset
//        captureSession.addOutput(photoOutput)
//        self.photoOutput = photoOutput
        
        //   2.2 添加 video data output
        let videoDataOutput = AVCaptureVideoDataOutput()
        let videoSettings: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        videoDataOutput.videoSettings = videoSettings
        guard captureSession.canAddOutput(videoDataOutput) else { return }
        videoDataOutput.setSampleBufferDelegate(self, queue: self.sampleBufferQueue)
        captureSession.addOutput(videoDataOutput)
        self.videoDataOutput = videoDataOutput
        
        
        //   2.3 添加 audio data output
//         let audioDataOutput = AVCaptureAudioDataOutput()
//         guard captureSession.canAddOutput(audioDataOutput) else { return }
//         audioDataOutput.setSampleBufferDelegate(self, queue: self.sampleBufferQueue)
//         captureSession.addOutput(audioDataOutput)
//         self.audioDataOutput = audioDataOutput
        
        configVideoConnection()

        // 3. 设置预览视图
        self.cameraPreviewView.removeFromSuperview()
        self.cameraPreviewView.frame = containerView.bounds
        containerView.addSubview(self.cameraPreviewView)
    }
}

extension Camera {
    
    private func addObservers() {
        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification,
                                               object: nil,
                                               queue: OperationQueue.main) { [weak self] _ in
            guard let self else { return }
            guard self.isRecording else { return }
            self.stopRecording()
        }
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
        
        configVideoConnection()
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
        
        configVideoConnection()
    }
    
    private func configVideoConnection() {
        
        guard let videoDataOutput = videoDataOutput else { return }
        guard let connection = videoDataOutput.connection(with: .video) else { return }
        configVideoStabilizationMode(for: connection)
        configVideoOrientation(for: connection)
    }
    
    private func configVideoStabilizationMode(for connection: AVCaptureConnection) {
        guard connection.isVideoStabilizationSupported else { return }
        if currentCameraPosition == .back {
            connection.preferredVideoStabilizationMode = cameraConfig.videoBackStabilizationMode
        }
        if currentCameraPosition == .front {
            connection.preferredVideoStabilizationMode = cameraConfig.videoFrontStabilizationMode
        }
    }
    
    private func configVideoOrientation(for connection: AVCaptureConnection) {
        guard connection.isVideoOrientationSupported else {
            return
        }
        connection.videoOrientation = AVCaptureVideoOrientation.portrait
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

extension Camera {
    
    func startVideoRecord() {
        // 每次开始录制都应该创建一个新的 AVAssetWriter
        cameraOperationQueue.async {
            guard let videoFileURL = FilePathUtils.videoURLForCurrentTime() else { return }
            
            let assistant = AVOutputSettingsAssistant(preset: .hevc3840x2160)
            
            let videoSettings: [String: Any]? = assistant?.videoSettings
            
            let audioSettings: [String: Any]? = assistant?.audioSettings
            
            do {
                try self.setupAssetWriter(outputURL: videoFileURL,
                                          videoSettings: videoSettings,
                                          audioSettings: audioSettings)
            } catch {
                print("Setup AssetWriter error: \(error)")
            }
            
            if self.assetWriter?.startWriting() == false {
                print("Failed to start writing")
                return
            }
            
            self.isWritingStarted = true
        }
    }
    
    func stopRecording() {
        guard let assetWriter = assetWriter else {
            return
        }
        cameraOperationQueue.async {
            
            self.videoWriterInput?.markAsFinished()
            self.audioWriterInput?.markAsFinished()
            
            if self.lastSampleBuffer == nil {
                print("Failed to get the last sample buffer, cancelling writing")
                assetWriter.cancelWriting()
                
                self.cleanupWriter()
                return
            }
            
            let lastSampleTime = CMSampleBufferGetPresentationTimeStamp(self.lastSampleBuffer!)
            assetWriter.endSession(atSourceTime: lastSampleTime)
            
            assetWriter.finishWriting { [weak self] in
                if assetWriter.status == .completed {
                    print("Video writing completed")
                } else {
                    print("Video writing failed: \(assetWriter.error?.localizedDescription ?? "")")
                }
                
                self?.cleanupWriter()
            }
        }
    }
    
    private func setupAssetWriter(outputURL: URL,
                                  videoSettings: [String: Any]?,
                                  audioSettings: [String: Any]?) throws {
        do {
            assetWriter = try AVAssetWriter(outputURL: outputURL,
                                            fileType: .mp4)
        } catch {
            print("Error creating asset writer: \(error)")
            throw error
        }

        videoWriterInput = AVAssetWriterInput(mediaType: .video,
                                              outputSettings: videoSettings)
        videoWriterInput?.expectsMediaDataInRealTime = true

        if let assetWriter = assetWriter,
           let videoWriterInput = videoWriterInput,
            assetWriter.canAdd(videoWriterInput) {
            assetWriter.add(videoWriterInput)
        } else {
            print("Cannot add video input to asset writer")
            throw CameraConfigWriterError.canNotAddVideoDataInput
        }
        
        // Audio input setup
        audioWriterInput = AVAssetWriterInput(mediaType: .audio,
                                              outputSettings: audioSettings)
        audioWriterInput?.expectsMediaDataInRealTime = true
        
        if let assetWriter = assetWriter,
           let audioWriterInput = audioWriterInput,
           assetWriter.canAdd(audioWriterInput) {
            assetWriter.add(audioWriterInput)
        } else {
            print("Cannot add audio input to asset writer")
            throw CameraConfigWriterError.canNotAddAudioDataInput
        }
    }
    
    private func cleanupWriter() {
        assetWriter = nil
        videoWriterInput = nil
        isWritingStarted = false
        firstSampleTime = CMTime.invalid
        lastSampleBuffer = nil
    }
    
}

extension Camera: AVCaptureVideoDataOutputSampleBufferDelegate,
                    AVCaptureAudioDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) { // 每一帧都回调
        
        if output is AVCaptureVideoDataOutput {
            let videoOrientation = output.connection(with: .video)?.videoOrientation
            displayVideoSampleBufferInPreview(sampleBuffer,
                                              videoOrientation:videoOrientation)
        }
        
        guard let assetWriter = assetWriter else {
            print("asset writer is nil")
            return
            
        }
        if CMSampleBufferDataIsReady(sampleBuffer) == false {
            if output is AVCaptureVideoDataOutput {
                print("video sample buffer is not ready")
            }
            if output is AVCaptureAudioDataOutput {
                print("audio sample buffer is not ready")
            }
            return
        }
        if !isWritingStarted  { return }
        
        if firstSampleTime == CMTime.invalid {
            firstSampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            assetWriter.startSession(atSourceTime: firstSampleTime)
        }
        
        if assetWriter.status == .writing {
            if output is AVCaptureVideoDataOutput,
               let videoInput = videoWriterInput,
               videoInput.isReadyForMoreMediaData {
                videoInput.append(sampleBuffer)
                lastSampleBuffer = sampleBuffer
            } else if output is AVCaptureAudioDataOutput,
                      let audioInput = audioWriterInput,
                      audioInput.isReadyForMoreMediaData {
                audioInput.append(sampleBuffer)
            }
            
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput,
                       didDrop sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
                        let videoSampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        print("drop video sample: \(videoSampleTime)")
    }
    
    private func displayVideoSampleBufferInPreview(_ sampleBuffer: CMSampleBuffer,
                                                   videoOrientation: AVCaptureVideoOrientation?) {
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // 创建 CIImage 对象
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        // 将 CIImage 转换为 CGImage
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        DispatchQueue.main.async {
            self.cameraPreviewView.layer.contents = cgImage
        }
    }
    
    
}
