//
//  BikeInProgressController.swift
//  Bike Bump
//
//  Created by Chris Sweeney on 1/20/17.
//  Copyright © 2017 Chris Sweeney. All rights reserved.
//

import UIKit

//TODO add bike bell detetion call back
class BikeInProgressController: UIViewController {
    
    //state
    var isRideInProgress:Bool = false
    
    //UI elements
    @IBOutlet weak var inProgressDescription: UITextField!
    @IBOutlet weak var rideInProgress: UIActivityIndicatorView!
    @IBOutlet weak var endRide: UIButton!
    @IBOutlet weak var startRide: UIButton!
    
    //moniters
    let listener = Listener(samplingRate: 44100,soundClipDuration: 5,targetFrequncy: 3000,targetFrequncyThreshold: 50, bufferLength: 8192, lowPassFreq: 4000)
    let localizer = LocationManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //setup audio processing graph
        listener.initializeAudio()
        
        //setup UI
        isRideInProgress = false
        endRide.isEnabled = false
        startRide.layer.cornerRadius = 10
        endRide.layer.cornerRadius = 10
        startRide.addTarget(self, action: #selector(self.start), for:  UIControlEvents.touchUpInside)
        endRide.addTarget(self, action: #selector(self.end), for:  UIControlEvents.touchUpInside)
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //one function with toggling state
    func start() {
        listener.startListening()
        rideInProgress.isHidden = false
        rideInProgress.startAnimating()
        startRide.isEnabled = false
        endRide.isEnabled = true
        inProgressDescription.isHidden = false
    }
    
    func end() {
        listener.stopListening()
        rideInProgress.isHidden = true
        rideInProgress.stopAnimating()
        startRide.isEnabled = true
        endRide.isEnabled = false
        inProgressDescription.isHidden = true


    }
}
