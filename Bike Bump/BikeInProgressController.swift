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
    
    static var listener:Listener?
    static var setupListener:Listener?
    
    //state
    var isRideInProgress:Bool = false
    
    //UI elements
    @IBOutlet weak var settings: UIButton!
    @IBOutlet weak var inProgressDescription: UITextField!
    @IBOutlet weak var rideInProgress: UIActivityIndicatorView!
    @IBOutlet weak var welcomeField: UITextField!
    @IBOutlet weak var rideButton: UIButton!
    
    //firebase
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //dont setup every time, navigation popup controller?
        let user = FIRAuth.auth()?.currentUser
        if let name = user?.displayName {
            self.welcomeField.text = "Welcome " + name
        }
        
        BikeInProgressController.setupListener = BikeInProgressController.createAudioEngineWithRemoteParams()
        
        //setup audio
        BikeInProgressController.setupListener?.initializeAudio()
        
        //setup processing graph
        BikeInProgressController.setupListener?.installSetUpTap()
        
        BikeInProgressController.listener = BikeInProgressController.createAudioEngineWithRemoteParams()
        
        //setup audio
        BikeInProgressController.listener?.initializeAudio()
        
        //setup processing graph
        BikeInProgressController.listener?.installTaps()
        
        //setup outlit for callback to UI from listener class
        BikeInProgressController.listener?.delegate = self
        
        //setup UI
        isRideInProgress = false
        rideButton.frame = CGRect(x: rideButton.frame.origin.x/2, y: rideButton.frame.origin.y, width: 300, height: 300)
        rideButton.layer.cornerRadius = rideButton.bounds.size.width * 0.5
        rideButton.addTarget(self, action: #selector(self.rideAction), for:  UIControlEvents.touchUpInside)
        rideButton.addTarget(self, action: #selector(self.didTouch), for:  UIControlEvents.touchDown)
        rideButton.addTarget(self, action: #selector(self.didLift), for:  UIControlEvents.touchUpInside)
        settings.addTarget(self, action: #selector(self.settingsPage), for: UIControlEvents.touchUpInside)

    }
    
    override func viewDidAppear(_ animated: Bool) {
        let defaults = UserDefaults.standard
        if defaults.string(forKey: Constants.bikeBellFreq) == nil {
            self.performSegue(withIdentifier: "settingsPage", sender: self)
        }

    }
    
    static func createAudioEngineWithRemoteParams() -> Listener {
        //get firebase info
        let param:FIRRemoteConfig? = FIRRemoteConfig.remoteConfig()
        param!.activateFetched()
        
        //get server audio params
        var samplingRate:Int = (param!.configValue(forKey: "samplingRate").numberValue as? Int)!
        if samplingRate <= 0 || samplingRate % 2 != 0 {
            samplingRate = 44100
        }
        var soundClipDuration:Int = param!.configValue(forKey: "soundClipDuration").numberValue as! Int
        if soundClipDuration <= 0 {
            soundClipDuration = 5
        }
        var targetFreq:Int = param!.configValue(forKey: "bellTargetFreq").numberValue as! Int
        if targetFreq <= 0 {
            targetFreq = 3000
        }
        var lowPassFreq:Int = param!.configValue(forKey: "lowPassFreq").numberValue as! Int
        if lowPassFreq <= 0 {
            lowPassFreq = 4000
        }
        var bufferLength:Int = param!.configValue(forKey: "fftListenLength").numberValue as! Int
        if bufferLength <= 0 || bufferLength % 2 != 0 {
            bufferLength = 8192
        }
        var grabAllSoundRecordings:Int = param!.configValue(forKey: "grabAllSoundRecordings").numberValue as! Int
        if grabAllSoundRecordings < 0 || grabAllSoundRecordings > 1 {
            grabAllSoundRecordings = 0
        }
        var targetFrequencyThreshold:Int = param!.configValue(forKey: "targetFrequencyThreshold").numberValue as! Int
        if targetFrequencyThreshold < 0 {
            targetFrequencyThreshold = 100
        }
        var slopeWidth:Int = param!.configValue(forKey: "slopeWidth").numberValue as! Int
        if slopeWidth < 0 {
            slopeWidth = 100
        }
        var targetSlope:Float = param!.configValue(forKey: "targetSlope").numberValue as! Float
        if targetSlope <= 0 {
            targetSlope = 1
        }
        
        //initialize audio listening pipeline
        return Listener(samplingRate: samplingRate, soundClipDuration: Double(soundClipDuration),targetFrequncy: targetFreq, targetFrequncyThreshold: targetFrequencyThreshold, bufferLength: bufferLength, lowPassFreq: lowPassFreq, grabAllSoundRecordings :grabAllSoundRecordings, slopeWidth: slopeWidth, targetSlope:targetSlope)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func rideAction() {
        
        let defaults = UserDefaults.standard
        if defaults.string(forKey: Constants.bikeBellFreq) == nil {
            self.performSegue(withIdentifier: "settingsPage", sender: self)
        }
        else{
            if isRideInProgress {
                isRideInProgress = false
                BikeInProgressController.listener?.stopListening()
                rideButton.setTitle("Start Ride", for: UIControlState.normal)
                rideButton.backgroundColor = UIColor.green
                rideInProgress.isHidden = true
                rideInProgress.stopAnimating()
                inProgressDescription.isHidden = true
                isRideInProgress = false
            }
            else {
                isRideInProgress = true
                BikeInProgressController.listener?.startListening()
                rideButton.setTitle("End Ride", for: UIControlState.normal)
                rideButton.backgroundColor = UIColor.red
                rideInProgress.isHidden = false
                rideInProgress.startAnimating()
                inProgressDescription.isHidden = false
            }
        }
    }
    
    func didTouch()  {
        UIView.animate(withDuration: 0.2,
                      animations: {
                        self.rideButton.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            })
    }
    
    func didLift() {
        UIView.animate(withDuration: 0.025,
                       animations: {
                        self.rideButton.transform = CGAffineTransform.identity
        })
    }
    
    func settingsPage() {
        BikeInProgressController.listener?.stopListening()
        self.performSegue(withIdentifier: "settingsPage", sender: self)
    }


    //delegate methods for UI triggers
    
    func ringDetected(centerFreq:Int) {
        self.rideButton.backgroundColor = UIColor.yellow
        let fadeTime = DispatchTime.now() + .seconds(1)
        DispatchQueue.main.asyncAfter(deadline: fadeTime) {
            if (BikeInProgressController.listener?.isListening())!{
                self.rideButton.backgroundColor = UIColor.red
            }
            else {
                self.rideButton.backgroundColor = UIColor.green
            }
        }
    }

}
