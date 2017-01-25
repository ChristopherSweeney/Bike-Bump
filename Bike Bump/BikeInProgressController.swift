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
    var user:String = ""
    
    //UI elements
    @IBOutlet weak var inProgressDescription: UITextField!
    @IBOutlet weak var rideInProgress: UIActivityIndicatorView!
    @IBOutlet weak var endRide: UIButton!
    @IBOutlet weak var startRide: UIButton!
    
    //firebase
    var param:FIRRemoteConfig?
    
    //moniter
    var listener:Listener?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        param = FIRRemoteConfig.remoteConfig()
        param?.fetch(withExpirationDuration: 0) {
            (status, error) in
            
        }
        let fetched:Bool = param!.activateFetched()
        print(fetched)
        //get server audio params
        //use guard let to assign default value
        let samplingRate:Int = param!.configValue(forKey: "samplingRate").numberValue as! Int
        let soundClipDuration:Int = param!.configValue(forKey: "soundClipDuration").numberValue as! Int
        let targetFreq:Int = param!.configValue(forKey: "bellTargetFreq").numberValue as! Int
        let lowPassFreq:Int = param!.configValue(forKey: "bellTargetFreq").numberValue as! Int
        let bufferLength:Int = param!.configValue(forKey: "fftListenLength").numberValue as! Int
        print(samplingRate)
        print("here")

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
        
//        FIRAuth.auth()!.addStateDidChangeListener { auth, user in
//            self.user = (user?.displayName)!
//            
//        }
        
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
        self.inProgressDescription.backgroundColor = UIColor.blue
        
        let fadeTime = DispatchTime.now() + .seconds(1)
        DispatchQueue.main.asyncAfter(deadline: fadeTime) {
            print("test")
            self.inProgressDescription.backgroundColor = UIColor.white

        }
    }

}
