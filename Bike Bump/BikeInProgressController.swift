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
    let listener = Listener(samplingRate: 44100,soundClipDuration: 5,targetFrequncy: 3000,targetFrequncyThreshold: 50, bufferLength: 8192)
    let localizer = LocationManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        isRideInProgress = false
        endRide.isEnabled = false
        startRide.layer.cornerRadius = 4
        endRide.layer.cornerRadius = 4
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //one functoin with toggling state
    func start() {
        listener.startListening()
        rideInProgress.isHidden = false
        rideInProgress.startAnimating()
        startRide.isEnabled = false
        endRide.isEnabled = true
    }
    
    func end() {
        listener.stopListening()
        rideInProgress.isHidden = true
        rideInProgress.stopAnimating()
        startRide.isEnabled = true
        endRide.isEnabled = false

    }
}
