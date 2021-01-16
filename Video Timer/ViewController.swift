//
//  ViewController.swift
//  Video Timer
//
//  Created by James Perlman on 10/31/20.
//

import UIKit
import HomeKit

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
    @IBOutlet weak var videoNumberLabel: UILabel!
    @IBOutlet weak var toggleFocusButton: UIButton!
    @IBOutlet weak var toggleExposureButton: UIButton!
    
    let homeManager = HMHomeManager()
    var home: HMHome? {
        didSet {
            guard let home = home else {
                return
            }
            
            humidifier = home.accessories.first(where: { $0.name == "Humidifier" })
        }
    }
    let accessoryBrowser = HMAccessoryBrowser()
    var humidifier: HMAccessory?
    
    func setupHomeKit() {
        homeManager.delegate = self
        accessoryBrowser.delegate = self
    }
    
    func setHumidifierOn(_ toggleState: Bool) {
        
        guard let characteristic = humidifier?.find(serviceType: HMServiceTypeOutlet, characteristicType: HMCharacteristicMetadataFormatBool) else {
            return
        }
        
        characteristic.writeValue(NSNumber(value: toggleState)) { error in
            if error != nil {
                print("Something went wrong when trying access the humidifier")
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupHomeKit()
        
        videoNumberLabel.layer.shadowColor = UIColor.black.cgColor
        videoNumberLabel.layer.shadowRadius = 2.0
        videoNumberLabel.layer.shadowOpacity = 1.0
        videoNumberLabel.layer.shadowOffset = CGSize(width: 0, height: 0)
        videoNumberLabel.layer.masksToBounds = false
        
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
        invalidateTimers()
        guard let duration = TimeInterval(durationField.text ?? ""), let interval = TimeInterval(intervalField.text ?? "") else {
            return
        }
        
        self.videoNumber = 0
        self.videoNumberLabel.isHidden = false
        
        func recordVideo() {
            DispatchQueue.main.async {
                self.videoNumberLabel.text = "Recording (\(self.videoNumber))"
            }
            self.setHumidifierOn(false)
            self.videoRecorder.startRecording(fileName: "\(videoNumber)_\(dateFormatter.string(from: Date()))")
            self.videoNumber += 1
            
            Timer.scheduledTimer(withTimeInterval: duration, repeats: false, block: { (timer) in
                self.videoRecorder.stopRecording()
                DispatchQueue.main.async {
                    self.videoNumberLabel.text = "Waiting (\(self.videoNumber))"
                }
                self.setHumidifierOn(true)
            })
        }
        
        // turn off humidifier 10s before filming starts
        
        recordVideo()
        self.timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true, block: { (timer) in
            recordVideo()
        })
        
        
        startButton.isHidden = true
        stopButton.isHidden = false
        self.settingsButton.isHidden = true
    }
    
    @IBAction func stopRecording(_ sender: Any?) {
        invalidateTimers()
        self.videoNumberLabel.isHidden = true
        startButton.isHidden = false
        stopButton.isHidden = true
        settingsButton.isHidden = false
        self.videoNumberLabel.text = ""
    }
    
    @IBAction func showSettings(_ sender: Any?) {
        settingsView.isHidden = false
    }
    
    @IBAction func hideSettings(_ sender: Any?) {
        self.settingsView.isHidden = true
        view.endEditing(true)
    }
    
    @IBAction func toggleFocusLock(_ sender: Any?) {
        if videoRecorder.isFocusLocked {
            videoRecorder.unlockFocus()
            toggleFocusButton.setTitle("Lock Focus", for: .normal)
        } else {
            videoRecorder.lockFocus()
            toggleFocusButton.setTitle("Unlock Focus", for: .normal)
        }
    }
    
    @IBAction func toggleExposureLock(_ sender: Any?) {
        if videoRecorder.isExposureLocked {
            videoRecorder.unlockExposure()
            toggleExposureButton.setTitle("Lock Exposure", for: .normal)
        } else {
            videoRecorder.lockExposure()
            toggleExposureButton.setTitle("Unlock Exposure", for: .normal)
        }
    }
    
    func invalidateTimers() {
        self.timer?.invalidate()
    }
}

extension ViewController: HMHomeManagerDelegate {
    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        home = manager.primaryHome
    }
}

extension ViewController: HMAccessoryBrowserDelegate {
    func accessoryBrowser(_ browser: HMAccessoryBrowser, didFindNewAccessory accessory: HMAccessory) {
        print("\(accessory)")
    }
}
