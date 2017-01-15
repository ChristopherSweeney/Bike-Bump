//
//  ViewController.swift
//  Bike Bump
//
//  Created by Chris Sweeney on 1/11/17.
//  Copyright © 2017 Chris Sweeney. All rights reserved.
//

import UIKit
import AVFoundation
import CoreLocation

class ViewController: UIViewController {
    
 let listener = Listener(samplingRate: 48000,soundClipDuration: 10,targetFrequncy: 3000,targetFrequncyThreshold: 50)
 let localizer = LocationManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //listener.startListening()
        print((localizer.getLocation() as CLLocation).coordinate)
    }

   override func didReceiveMemoryWarning() {78
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

