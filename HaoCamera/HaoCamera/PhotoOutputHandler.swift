//
//  PhotoOutputHandler.swift
//  HaoCamera
//
//  Created by 郝一鹏 on 2023/2/25.
//

import Foundation
import AVFoundation
import UIKit

enum PhotoTakeResultError: Error {
    case imageNotExist
}

enum PhotoTakeResult {
    case success(image: UIImage, livePhotoURL: URL?)
    case fail(error: Error)
}

class PhotoOutputHander: NSObject {
    private let didFinishPhotoTakeHandler: (PhotoOutputHander, PhotoTakeResult) -> Void
    private var image: UIImage?
    init(didFinishPhotoTakeHandler: @escaping (PhotoOutputHander, PhotoTakeResult) -> Void) {
        self.didFinishPhotoTakeHandler = didFinishPhotoTakeHandler
    }
}

extension PhotoOutputHander: AVCapturePhotoCaptureDelegate {
    
    
    
    // MARK: Monitoring Capture Progress
    // 因为是单独的一个对象去处理拍摄的，所以我们要让外部使用我们这个对象的地方感知到拍摄的过程是什么样的，因为外部可能需要通过这个去控制一些 UI 的展示
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
    
    // 如果是静态的图片拍摄的话，必须要实现这个方法
    // 因为是单独的一个对象去处理拍摄的，所以我们要让外部使用我们这个对象的地方感知到拍摄完成的结果
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        print(output)
        guard let cgImage = photo.cgImageRepresentation(),
              let orientationInt = photo.metadata[String(kCGImagePropertyOrientation)] as? UInt32,
              let imageOrientation = UIImage.Orientation.orientation(fromCGOrientationRaw: orientationInt)  else { return }
        // Create image with proper orientation
        image = UIImage(cgImage: cgImage,
                        scale: 1,
                        orientation: imageOrientation)
        
    }
    
    // MARK: Live Photo
    // 如果是 live photo 拍摄的话，必须要实现这个方法，这个方法是最终取回结果的那个方法
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL,
                     duration: CMTime, photoDisplayTime: CMTime,
                     resolvedSettings: AVCaptureResolvedPhotoSettings,
                     error: Error?) {
        print(output)
    }
    
    // 如果是 live photo 拍摄的话，可以用这个方法来获取到 live photo 的视频文件是否拍摄完成
    // 但是这里的完成仅仅代表拍摄完成了，视频文件可能还在处理，可能没有写到对应的位置
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishRecordingLivePhotoMovieForEventualFileAt outputFileURL: URL,
                     resolvedSettings: AVCaptureResolvedPhotoSettings) {
        print(output)
    }
    
    // MARK: 标记本次拍摄完成
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
                     error: Error?) {
        if let error {
            self.didFinishPhotoTakeHandler(self, PhotoTakeResult.fail(error: error))
            return
        }
        guard let image = image else {
            self.didFinishPhotoTakeHandler(self, PhotoTakeResult.fail(error: PhotoTakeResultError.imageNotExist))
            return
        }
        self.didFinishPhotoTakeHandler(self, PhotoTakeResult.success(image: image, livePhotoURL: nil))
        print(output)
    }
}

extension UIImage.Orientation {

    init(_ cgOrientation: CGImagePropertyOrientation) {
        // we need to map with enum values becuase raw values do not match
        switch cgOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        }
    }


    /// Returns a UIImage.Orientation based on the matching cgOrientation raw value
    static func orientation(fromCGOrientationRaw cgOrientationRaw: UInt32) -> UIImage.Orientation? {
        var orientation: UIImage.Orientation?
        if let cgOrientation = CGImagePropertyOrientation(rawValue: cgOrientationRaw) {
            orientation = UIImage.Orientation(cgOrientation)
        } else {
            orientation = nil // only hit if improper cgOrientation is passed
        }
        return orientation
    }
}
