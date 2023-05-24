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
    private var lastSampleTime = CMTime.zero
    
    var cameraOperationQueue = DispatchQueue(label: "com.pandada.HAOCameraOperationQueue")
    var sampleBufferQueue: DispatchQueue = DispatchQueue(label: "com.pandada.HAOCameraVideoDataQueue")
    
    lazy var cameraPreviewView : HAOCameraPreviewView = HAOCameraPreviewView(frame: .zero)
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
        // let audioDataOutput = AVCaptureAudioDataOutput()
        // guard captureSession.canAddOutput(audioDataOutput) else { return }
        // audioDataOutput.setSampleBufferDelegate(self, queue: self.sampleBufferQueue)
        // captureSession.addOutput(audioDataOutput)
        // self.audioDataOutput = audioDataOutput
        
         configVideoStabilizationModeForCurrentCameraPosition()

        // 3. 设置预览视图
        self.cameraPreviewView.videoPreviewLayer.session = captureSession
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
        
        configVideoStabilizationModeForCurrentCameraPosition()
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
        
        configVideoStabilizationModeForCurrentCameraPosition()
    }
    
    private func configVideoStabilizationModeForCurrentCameraPosition() {
        
        guard let videoDataOutput = videoDataOutput else { return }
        guard let connection = videoDataOutput.connection(with: .video) else { return }
        guard connection.isVideoStabilizationSupported else { return }
        if currentCameraPosition == .back {
            connection.preferredVideoStabilizationMode = cameraConfig.videoBackStabilizationMode
        }
        if currentCameraPosition == .front {
            connection.preferredVideoStabilizationMode = cameraConfig.videoFrontStabilizationMode
        }
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
            
            assetWriter.finishWriting { [weak self] in
                if assetWriter.status == .completed {
                    print("Video writing completed")
                } else {
                    print("Video writing failed: \(assetWriter.error?.localizedDescription ?? "")")
                }
                
                self?.assetWriter = nil
                self?.videoWriterInput = nil
                self?.isWritingStarted = false
                self?.lastSampleTime = CMTime.zero
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
}

extension Camera: AVCaptureVideoDataOutputSampleBufferDelegate,
                    AVCaptureAudioDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) { // 每一帧都回调
        
        guard let assetWriter = assetWriter else { return }
        if CMSampleBufferDataIsReady(sampleBuffer) == false { return }
        if !isWritingStarted  { return }
        
        if lastSampleTime == CMTime.zero {
            lastSampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            assetWriter.startSession(atSourceTime: lastSampleTime)
        }
        
        if assetWriter.status == .writing {
            
            if output is AVCaptureVideoDataOutput,
                let videoInput = videoWriterInput,
                videoInput.isReadyForMoreMediaData {
                
                // Synchronize video and audio tracks by using the same presentation timestamp
                let videoSampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                let adjustedSampleBuffer = adjustSampleBuffer(sampleBuffer, with: videoSampleTime)
                
                videoInput.append(adjustedSampleBuffer)
                print("video sample appended")
                
            } else if output is AVCaptureAudioDataOutput,
                        let audioInput = audioWriterInput,
                        audioInput.isReadyForMoreMediaData {
                
                // Synchronize video and audio tracks by using the same presentation timestamp
                let audioSampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                let adjustedSampleBuffer = adjustSampleBuffer(sampleBuffer, with: audioSampleTime)
                
                audioInput.append(adjustedSampleBuffer)
                print("audio sample appended")
            }
        }
    }

    private func adjustSampleBuffer(_ sampleBuffer: CMSampleBuffer, with presentationTimeStamp: CMTime) -> CMSampleBuffer {
        return sampleBuffer
    }
    
    func captureOutput(_ output: AVCaptureOutput,
                       didDrop sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
                        let videoSampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        print("drop video sample: \(videoSampleTime)")
    }
}
