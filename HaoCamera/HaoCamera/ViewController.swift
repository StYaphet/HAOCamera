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
    
    override var prefersStatusBarHidden: Bool {
        get {
            return true
        }
    }

    var cameraModel: Camera?

    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var previewView: HAOCameraPreviewView!
    @IBOutlet weak var swapButton: UIButton!

    @IBAction func swapButtonClicked(_ sender: UIButton) {
        self.cameraModel?.swapCameraPosition()
    }
    @IBAction func recordButtonClicked(_ sender: UIButton) {
        takePicture()
    }

    override func viewDidLoad() {
        self.recordButton.setTitle("Pause", for: .normal)
    }

    override func viewDidAppear(_ animated: Bool) {
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
                    self.jumpToSystemSettingsAppToGiveAuthorization()
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
                    self.jumpToSystemSettingsAppToGiveAuthorization()
                    return
                }
                if self.createCameraIfHadAuthorized() { // 尝试创建相机
                    self.tryStartCameraCapture()
                }
            }
        }
    }
    
    private func jumpToSystemSettingsAppToGiveAuthorization () {
        let alert = UIAlertController(title: "去给相机、麦克风授权吧~",
                                      message: nil,
                                      preferredStyle: .alert)
        let confirmAction = UIAlertAction(title: "走着", style:.default) { _ in
            guard let settingsURL = URL(string:UIApplication.openSettingsURLString) else { return }
            guard UIApplication.shared.canOpenURL(settingsURL) else { return }
            UIApplication.shared.open(settingsURL)
        }
        let cancelAction = UIAlertAction(title: "还是算了", style: .destructive)
        alert.addAction(cancelAction)
        alert.addAction(confirmAction)
        self.present(alert, animated: true)
    }
    
    private func createCameraIfHadAuthorized() -> Bool {
        guard AuthorizationUtils.cameraAuthorized,
                AuthorizationUtils.microphoneAuthorized else {
            return false
        }
        cameraModel = Camera()
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

    func getFrontCamera() -> [AVCaptureDevice] {

        let deviceType = [
            AVCaptureDevice.DeviceType.builtInWideAngleCamera,
            AVCaptureDevice.DeviceType.builtInTelephotoCamera,
            AVCaptureDevice.DeviceType.builtInUltraWideCamera,
        ]
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: deviceType,
                                                                mediaType: .video,
                                                                position: .front)
        return discoverySession.devices
    }
}


extension ViewController {
    private func takePicture() {
        guard let camera = self.cameraModel else {
            return
        }
        
        // TODO: 因为暂时还没有添加其他的设置，所以这里暂时就直接创建一个默认的 PhotoSettings
        let photoSettings = AVCapturePhotoSettings()
        
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
    
    private func writeImageToDisk(image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 1) else { return }
        let nsImageData = NSData(data: imageData)
        
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let imageDirectory = documentDirectory.appendingPathComponent("Images")
        if !FileManager.default.fileExists(atPath: imageDirectory.absoluteString) {
            do {
                try FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
            } catch {
                print(error)
                return
            }
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        let imageFileName = dateFormatter.string(from: Date())
        nsImageData.write(to: imageDirectory.appendingPathComponent("\(imageFileName).jpg"), atomically: true)
    }
}
