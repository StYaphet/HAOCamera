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
        // 首先检查是否授权
        // 如果已经授权，创建 camera 并开启采集
        if HAOAuthorizationUtils.cameraAuthorized && HAOAuthorizationUtils.microphoneAuthorized {
            if createCameraIfHadAuthorized() {
                self.tryStartCameraCapture()
            }
        } else { // 如果没有授权
            // 申请相机权限
            //   如果是未授权状态，申请权限
            HAOAuthorizationUtils.requestCameraAuthorization { [weak self] (granted) in
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
            HAOAuthorizationUtils.requestMicphoneAuthorization { [weak self] (granted) in
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
        guard HAOAuthorizationUtils.cameraAuthorized,
                HAOAuthorizationUtils.microphoneAuthorized else {
            return false
        }
        cameraModel = HAOCamera()
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

