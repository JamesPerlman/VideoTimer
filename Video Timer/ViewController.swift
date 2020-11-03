//
//  ViewController.swift
//  Video Timer
//
//  Created by James Perlman on 10/31/20.
//

import UIKit

class ViewController: UIViewController {
    let recorder = VideoRecorder()
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        recorder.requestPermissions()
    }
}

