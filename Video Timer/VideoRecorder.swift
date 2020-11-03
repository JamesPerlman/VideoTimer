//
//  VideoRecorder.swift
//  Video Timer
//
//  Created by James Perlman on 11/1/20.
//

import Foundation
import AVFoundation
import UIKit
import Photos

class VideoRecorder: NSObject {
    private var movieFileOutput: AVCaptureMovieFileOutput?
    private let sessionQueue = DispatchQueue(label: "session queue")
    private var backgroundRecordingID: UIBackgroundTaskIdentifier?
    private var fileName: String?
    
    func requestPermissions() {
        PHPhotoLibrary.requestAuthorization() { (status) in
            print("Photos auth status: \(status)")
        }
        AVCaptureDevice.requestAccess(for: .video) { (granted) in
            print("AV Capture granted: \(granted)")
        }
    }
    
    func startRecording(fileName: String) {
        guard let movieFileOutput = self.movieFileOutput else {
            return
        }
        
        if movieFileOutput.isRecording {
            return
        }
        
        sessionQueue.async {
            if !movieFileOutput.isRecording {
                if UIDevice.current.isMultitaskingSupported {
                    self.backgroundRecordingID = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
                }
                
                guard let outputConnection = movieFileOutput.connection(with: .video) else {
                    print("Failed to start output connection")
                    return
                }
                outputConnection.videoOrientation = .portrait
                
                let availableCodecs = movieFileOutput.availableVideoCodecTypes
                
                if availableCodecs.contains(.proRes422LT) {
                    movieFileOutput.setOutputSettings(([AVVideoCodecKey: AVVideoCodecType.proRes422LT]), for: outputConnection)
                }
                
                self.fileName = fileName
                let filePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((fileName as NSString).appendingPathExtension("mov")!)
                movieFileOutput.startRecording(to: URL(fileURLWithPath: filePath), recordingDelegate: self)
            }
        }
    }
    
    func stopRecording() {
        guard let movieFileOutput = self.movieFileOutput else {
            return
        }
        
        if movieFileOutput.isRecording {
            movieFileOutput.stopRecording()
        }
    }
    
    func cleanupRecording(fileURL: URL) {
        let path = fileURL.path
        
        if FileManager.default.fileExists(atPath: path) {
            do {
                try FileManager.default.removeItem(atPath: path)
            } catch {
                print("Could not remove file at url: \(fileURL)")
            }
        }
        
        if let currentBackgroundRecordingID = backgroundRecordingID {
            backgroundRecordingID = .invalid
            
            if currentBackgroundRecordingID != .invalid {
                UIApplication.shared.endBackgroundTask(currentBackgroundRecordingID)
            }
        }
    }
}

extension VideoRecorder: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        var success = true
        
        if error != nil {
            success = (((error! as NSError).userInfo[AVErrorRecordingSuccessfullyFinishedKey] as AnyObject).boolValue)!
        }
        
        if success {
            PHPhotoLibrary.shared().performChanges({
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = true
                
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .video, fileURL: outputFileURL, options: options)
            }, completionHandler: { (success, error) in
                if !success {
                    print("Something went terribly wrong when trying to save the video to photos: \(String(describing: error))")
                } else {
                    print("Successfully made video file \(outputFileURL)")
                }
                self.cleanupRecording(fileURL: outputFileURL)
            })
        } else {
            cleanupRecording(fileURL: outputFileURL)
        }
    }
}
