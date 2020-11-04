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
    private var videoDevice: AVCaptureDevice?
    @objc dynamic var videoDeviceInput: AVCaptureDeviceInput!
    
    let session = AVCaptureSession()
    let previewView = VideoPreviewView()
    
    override init() {
        super.init()
        previewView.session = session
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sessionWasInterrupted),
                                               name: .AVCaptureSessionWasInterrupted,
                                               object: session)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sessionInterruptionEnded),
                                               name: .AVCaptureSessionInterruptionEnded,
                                               object: session)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func requestPermissions(completion: @escaping () -> Void) {
        PHPhotoLibrary.requestAuthorization() { (status) in
            print("Photos auth status: \(status)")
            AVCaptureDevice.requestAccess(for: .video) { (granted) in
                print("AV Capture granted: \(granted)")
                completion()
            }
        }
    }
    
    func startRecording(fileName: String) {
        guard let movieFileOutput = self.movieFileOutput else {
            return
        }
        
        if movieFileOutput.isRecording {
            return
        }
        
        guard let videoDevice = self.videoDevice else {
            return
        }
        print("Starting recording: \(fileName)")
        
        try! videoDevice.lockForConfiguration()
        videoDevice.focusMode = .locked
        videoDevice.exposureMode = .locked
        videoDevice.unlockForConfiguration()
        
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
        
        guard let videoDevice = self.videoDevice else {
            return
        }
        
        try! videoDevice.lockForConfiguration()
        videoDevice.focusMode = .continuousAutoFocus
        videoDevice.exposureMode = .continuousAutoExposure
        videoDevice.unlockForConfiguration()
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
    
    func setup() {
        sessionQueue.async {
            self.configureSession()
            self.session.startRunning()
            DispatchQueue.main.async {
                self.previewView.session = self.session
            }
        }
    }
    
    private func configureSession() {
        
        session.beginConfiguration()
        
        /*
         Do not create an AVCaptureMovieFileOutput when setting up the session because
         Live Photo is not supported when AVCaptureMovieFileOutput is added to the session.
         */
        session.sessionPreset = .hd4K3840x2160
        
        // Add video input.
        do {
            // Choose the back dual camera, if available, otherwise default to a wide angle camera.
            if let dualCameraDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
                self.videoDevice = dualCameraDevice
            } else if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                // If a rear dual camera is not available, default to the rear wide angle camera.
                self.videoDevice = backCameraDevice
            }
            guard let videoDevice = self.videoDevice else {
                print("Default video device is unavailable.")
                session.commitConfiguration()
                return
            }
            
            try! videoDevice.lockForConfiguration()
            videoDevice.focusMode = .continuousAutoFocus
            videoDevice.exposureMode = .continuousAutoExposure
            videoDevice.unlockForConfiguration()
            
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
                print("Added device \(videoDeviceInput) to session.")
            } else {
                print("Couldn't add video device input to the session.")
                session.commitConfiguration()
                return
            }
            
            let movieFileOutput = AVCaptureMovieFileOutput()
            
            if session.canAddOutput(movieFileOutput) {
                session.addOutput(movieFileOutput)
            }
            
            self.movieFileOutput = movieFileOutput
            
        } catch {
            print("Couldn't create video device input: \(error)")
            session.commitConfiguration()
            return
        }
        session.commitConfiguration()
        print("Completed setup")
    }
    
    /// - Tag: HandleRuntimeError
    @objc func sessionRuntimeError(notification: NSNotification) {
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else { return }
        
        print("Capture session runtime error: \(error)")
        // If media services were reset, and the last start succeeded, restart the session.
        if error.code == .mediaServicesWereReset {
            sessionQueue.async {
                if self.session.isRunning {
                    self.session.startRunning()
                }
            }
        }
    }
    
    @objc func sessionWasInterrupted(notification: NSNotification) {
        if !session.isRunning {
            sessionQueue.async {
                self.session.startRunning()
            }
        }
    }
    @objc func sessionInterruptionEnded(notification: NSNotification) {
        if !session.isRunning {
            sessionQueue.async {
                self.session.startRunning()
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
