//
//  ViewController.swift
//  Video Timer
//
//  Created by James Perlman on 10/31/20.
//

import UIKit

class ViewController: UIViewController {
    
    let videoRecorder = VideoRecorder()
    var timer: Timer? = nil
    var videoPrefix: String = ""
    var videoNumber: Int = 0
    lazy var dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd_hh-mm-ss"
        return df
    }()
    
    @IBOutlet weak var durationField: UITextField!
    @IBOutlet weak var intervalField: UITextField!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var settingsView: UIView!
    @IBOutlet weak var settingsButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        videoRecorder.requestPermissions {
            self.videoRecorder.setup()
        }
        
        view.insertSubview(videoRecorder.previewView, at: 0)
        videoRecorder.previewView.translatesAutoresizingMaskIntoConstraints = false
        view.addConstraints([
            videoRecorder.previewView.leftAnchor.constraint(equalTo: view.leftAnchor),
            videoRecorder.previewView.topAnchor.constraint(equalTo: view.topAnchor),
            videoRecorder.previewView.rightAnchor.constraint(equalTo: view.rightAnchor),
            videoRecorder.previewView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        view.setNeedsLayout()
        videoRecorder.previewView.videoPreviewLayer.frame = UIScreen.main.bounds
        
        self.settingsView.backgroundColor = UIColor(white: 0, alpha: 0.5)
        
    }
    
    @IBAction func startRecording(_ sender: Any?) {
        invalidateTimer()
        guard let duration = Int(durationField.text ?? ""), let interval = Int(durationField.text ?? "") else {
            return
        }
        self.timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(interval), repeats: true, block: { (timer) in
            self.videoRecorder.startRecording(fileName: self.dateFormatter.string(from: Date()))
            
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(duration)) {
                self.videoRecorder.stopRecording()
            }
        })
        
        startButton.isHidden = true
        stopButton.isHidden = false
        self.settingsButton.isHidden = true
        
    }
    
    @IBAction func stopRecording(_ sender: Any?) {
        invalidateTimer()
        startButton.isHidden = false
        stopButton.isHidden = true
        settingsButton.isHidden = false
    }
    
    @IBAction func showSettings(_ sender: Any?) {
        settingsView.isHidden = false
    }
    
    @IBAction func hideSettings(_ sender: Any?) {
        self.settingsView.isHidden = true
        view.endEditing(true)
    }
    
    func invalidateTimer() {
        if let timer = self.timer {
            timer.invalidate()
        }
    }
}

