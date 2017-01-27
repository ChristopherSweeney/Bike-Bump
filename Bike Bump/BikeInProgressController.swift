//
//  BikeInProgressController.swift
//  Bike Bump
//
//  Created by Chris Sweeney on 1/20/17.
//  Copyright © 2017 Chris Sweeney. All rights reserved.
//

import FirebaseRemoteConfig
import UIKit
import FirebaseAuth

//TODO add bike bell detetion call back
class BikeInProgressController: UIViewController, AudioEvents {
    
    //state
    var isRideInProgress:Bool = false
    
    //UI elements
    @IBOutlet weak var inProgressDescription: UITextField!
    @IBOutlet weak var rideInProgress: UIActivityIndicatorView!
    @IBOutlet weak var endRide: UIButton!
    @IBOutlet weak var startRide: UIButton!
    @IBOutlet weak var welcomeField: UITextField!
    
    //firebase
    var param:FIRRemoteConfig?
    
    //moniter
    var listener:Listener?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //get firebase info
        let user = FIRAuth.auth()?.currentUser
        if let name = user?.displayName {
            self.welcomeField.text = "Welcome " + name
        }
        param = FIRRemoteConfig.remoteConfig()
        param!.activateFetched()
        
        //get server audio params
        var samplingRate:Int = (param!.configValue(forKey: "samplingRate").numberValue as? Int)!
        if samplingRate <= 0 || samplingRate % 2 != 0 {
            samplingRate = 44100
        }
        var soundClipDuration:Int = param!.configValue(forKey: "soundClipDuration").numberValue as! Int
        if soundClipDuration <= 0 {
            soundClipDuration = 44100
        }
        var targetFreq:Int = param!.configValue(forKey: "bellTargetFreq").numberValue as! Int
        if targetFreq <= 0 {
            targetFreq = 3000
        }
        var lowPassFreq:Int = param!.configValue(forKey: "bellTargetFreq").numberValue as! Int
        if lowPassFreq <= 0 {
            lowPassFreq = 4000
        }
        var bufferLength:Int = param!.configValue(forKey: "fftListenLength").numberValue as! Int
        if bufferLength <= 0 || bufferLength % 2 != 0 {
            bufferLength = 8192
        }
        
        //initialize audio listening pipeline
         self.listener = Listener(samplingRate: samplingRate, soundClipDuration: Double(soundClipDuration),targetFrequncy: targetFreq, targetFrequncyThreshold: 1000, bufferLength: bufferLength, lowPassFreq: lowPassFreq)
        
        //setup audio processing graph
        listener?.initializeAudio()
        listener?.delegate = self
        
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
        listener?.startListening()
        rideInProgress.isHidden = false
        rideInProgress.startAnimating()
        startRide.isEnabled = false
        endRide.isEnabled = true
        inProgressDescription.isHidden = false
    }
    
    func end() {
        listener?.stopListening()
        rideInProgress.isHidden = true
        rideInProgress.stopAnimating()
        startRide.isEnabled = true
        endRide.isEnabled = false
        inProgressDescription.isHidden = true
    }
    
    //delegate methods
    func ringDetected() {
        self.inProgressDescription.backgroundColor = UIColor.yellow
        
        let fadeTime = DispatchTime.now() + .seconds(1)
        DispatchQueue.main.asyncAfter(deadline: fadeTime) {
            print("test")
            self.inProgressDescription.backgroundColor = UIColor.white

        }
    }

}
