//
//  ViewController.swift
//  Bike Bump
//
//  Created by Chris Sweeney on 1/11/17.
//  Copyright © 2017 Chris Sweeney. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
 let listener = Listener(samplingRate: 48000,soundClipDuration: 10,targetFrequncy: 3000,targetFrequncyThreshold: 50)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        listener.startListening()
    }

   override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

