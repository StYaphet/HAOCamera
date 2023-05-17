//
//  FilePathUtils.swift
//  HaoCamera
//
//  Created by 郝一鹏 on 2023/5/17.
//

import Foundation

struct FilePathUtils {
    
    static func documentDirectoryURL() -> URL? {
        
        let fileManager = FileManager.default
        guard let documentDirectory = fileManager.urls(for: .documentDirectory,
                                                       in: .userDomainMask).first else {
            return nil
        }
        return documentDirectory
    }
    
    
    static func tmpDirectoryURL() -> URL {
        
        let tmpDirectoryPath = NSTemporaryDirectory()
        return URL(fileURLWithPath: tmpDirectoryPath)
    }
    
    
    static func imageDirectoryURL() -> URL? {
        
        let fileManager = FileManager.default
        guard let documentDirectoryURL = documentDirectoryURL() else { return nil }
        let imageDirectoryURL = documentDirectoryURL.appendingPathComponent("Images")
        if !fileManager.fileExists(atPath: imageDirectoryURL.absoluteString) {
            do {
                try fileManager.createDirectory(at: imageDirectoryURL, withIntermediateDirectories: true)
            } catch {
                return nil
            }
        }
        return imageDirectoryURL
    }
    
    
    static func todayImageDirectoryURL() -> URL? {
        
        guard let imageDirectoryURL = imageDirectoryURL() else { return nil }
        let todayDateFormatter = DateFormatter()
        todayDateFormatter.dateFormat = "yyyy-MM-dd"
        let todayDateString = todayDateFormatter.string(from: Date())
        let todayImageDirectoryURL = imageDirectoryURL.appendingPathComponent("\(todayDateString)")
        return todayImageDirectoryURL
    }
    
    static func imageURLForCurrentTime() -> URL? {
        
        guard let todayImageDirectoryURL = todayImageDirectoryURL() else { return nil }
        let imageNamePath = imageNameForCurrentTime()
        let url = todayImageDirectoryURL.appendingPathComponent(imageNamePath)
        return url
    }
    
    static func videoURLForCurrentTime() -> URL? {
        guard let todayImageDirectoryURL = todayImageDirectoryURL() else { return nil }
        let videoNamePath = videoNameForCurrentTime()
        let url = todayImageDirectoryURL.appendingPathComponent(videoNamePath)
        return url
    }
    
    private static func videoNameForCurrentTime() -> String {
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.sss"
        let dateString = dateFormatter.string(from: Date())
        return "VID-\(dateString).mp4"
    }
    
    private static func imageNameForCurrentTime() -> String {
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.sss"
        let dateString = dateFormatter.string(from: Date())
        return "IMG-\(dateString).jpg"
    }
}
