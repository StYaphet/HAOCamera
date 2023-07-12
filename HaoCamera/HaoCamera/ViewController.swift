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
    
    var cameraModel: Camera?
    
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var previewView: CameraPreviewView!
    @IBOutlet weak var swapButton: UIButton!
    
    private var isRecording = false
    
    override var prefersStatusBarHidden: Bool {
        get { return true }
    }
    override var prefersHomeIndicatorAutoHidden: Bool {
        get { return true }
    }

    // MARK: - Life Cycle
    override func viewDidLoad() {
        
        super.viewDidLoad()
        setupUI()
        addGestureRecognizers()
    }

    
    override func viewDidAppear(_ animated: Bool) {
        
        super.viewDidAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
        // 首先检查是否授权
        // 如果已经授权，创建 camera 并开启采集
        if AuthorizationUtils.cameraAuthorized && AuthorizationUtils.microphoneAuthorized {
            if createCameraIfHadAuthorized() {
                self.tryStartCameraCapture()
            }
        } else { // 如果没有授权
            // 申请相机权限
            //   如果是未授权状态，申请权限
            AuthorizationUtils.requestCameraAuthorization { [weak self] (granted) in
                guard let self else { return }
                guard granted else { // 如果没有授权，弹 toast 让用户去设置页去进行授权
                    self.showJumpToSystemSettingsAppToGiveAuthorizationAlert()
                    return
                }
                if self.createCameraIfHadAuthorized() { // 尝试创建相机
                    self.tryStartCameraCapture() // 尝试开启采集
                }
            }
            // 申请麦克风权限
            AuthorizationUtils.requestMicphoneAuthorization { [weak self] (granted) in
                guard let self else { return }
                guard granted else { // 如果没有授权，弹 toast 让用户去设置页去进行授权
                    self.showJumpToSystemSettingsAppToGiveAuthorizationAlert()
                    return
                }
                if self.createCameraIfHadAuthorized() { // 尝试创建相机
                    self.tryStartCameraCapture()
                }
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.cameraModel?.startCapture()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        
        super.viewWillDisappear(animated)
        self.cameraModel?.stopCapture()
        UIApplication.shared.isIdleTimerDisabled = false
    }
}

// MARK: UI
extension ViewController {
    
    private func setupUI() {
        
        self.recordButton.setTitle("Take Picture", for: .normal)
    }
    
    
    private func addGestureRecognizers() {
        // Tap Gesture
        let tapGesture = UITapGestureRecognizer(target: self,
                                                action: #selector(handleTapGestureRecognizer(gesture:)))
        self.view.addGestureRecognizer(tapGesture)
    }
}

// MARK: - Actions
extension ViewController {
    
    @IBAction func swapButtonClicked(_ sender: UIButton) {
        
        self.cameraModel?.swapCameraPosition()
    }
    
    
    @IBAction func recordButtonClicked(_ sender: UIButton) {
        
        guard let cameraModel = cameraModel else { return }
        
        if cameraModel.isRecording {
            cameraModel.stopRecording()
        } else {
            cameraModel.startVideoRecord()
        }
//        takePicture()
    }
    
    
    @objc func handleTapGestureRecognizer(gesture: UITapGestureRecognizer) {
        
//        guard let cameraModel = cameraModel else { return }
//
//        if cameraModel.isRecording {
//            cameraModel.stopRecording()
//        } else {
//            cameraModel.startVideoRecord()
//        }
        
//        takePicture()
    }
}

// MARK: - Camera Handler
extension ViewController {
    
    private func createCameraIfHadAuthorized() -> Bool {
        // 已经创建好相机了，直接返回
        if cameraModel != nil { return true }
        guard AuthorizationUtils.cameraAuthorized,
                AuthorizationUtils.microphoneAuthorized else {
            return false
        }
        let cameraConfig = CameraConfig(notDisplayPreview: true)
        cameraModel = Camera(cameraConfig)
        guard let cameraModel = self.cameraModel else {
            return false
        }
        do {
            try cameraModel.setupCaptureSession(with: self.previewView)
        } catch {
            return false
        }
        return true
    }
    
    
    private func tryStartCameraCapture() {
        
        guard let cameraModel = self.cameraModel else { return }
        cameraModel.startCapture()
    }
    
    
    private func takePicture() {
        
        guard let camera = self.cameraModel else {
            return
        }
        
        // TODO: 因为暂时还没有添加其他的设置，所以这里暂时就直接创建一个默认的 PhotoSettings
        let photoSettings = getPhotoSettingWithCurrentConfig()
        camera.takePicture(with: photoSettings) {[weak self] result in
            switch result {
            case .success(let image, _):
                guard let self else { return }
                self.writeImageToDisk(image: image)
            case .fail(let error):
                print(error)
            }
        }
    }
    
    private func getPhotoSettingWithCurrentConfig() -> AVCapturePhotoSettings {
        // TODO: 因为暂时还没有添加其他的设置，所以这里暂时就直接创建一个默认的 PhotoSettings
        return AVCapturePhotoSettings()
    }
}

extension ViewController {
    
    private func writeImageToDisk(image: UIImage) {
        
        guard let imageData = image.jpegData(compressionQuality: 1) else { return }
        guard let imageURL = FilePathUtils.imageURLForCurrentTime() else { return }
        
        let nsImageData = NSData(data: imageData)
        nsImageData.write(to: imageURL, atomically: true)
    }
    
    
    private func showJumpToSystemSettingsAppToGiveAuthorizationAlert() {
        
        let alertVC = AuthorizationUtils.getJumpToSystemSettingsAppToGiveAuthorizationAlert()
        self.present(alertVC, animated: true)
    }
}
