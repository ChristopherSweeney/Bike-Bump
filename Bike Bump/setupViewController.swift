//
//  setupViewController.swift
//  Bike Bump
//
//  Created by Chris Sweeney on 4/3/17.
//  Copyright © 2017 Chris Sweeney. All rights reserved.
//

import UIKit

class setupViewController: UIViewController,AudioEvents {

    @IBOutlet weak var returnHome: UIButton!
    @IBOutlet weak var listenBell: UIButton!
    //make factory singleton in listener
    
    override func viewDidLoad() {
        super.viewDidLoad()
        listenBell.addTarget(self, action: #selector(self.didPressListenBell), for: UIControlEvents.touchUpInside)
        returnHome.addTarget(self, action: #selector(self.returnToHome), for: UIControlEvents.touchUpInside)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func didPressListenBell() {
        
        BikeInProgressController.listener = BikeInProgressController.createAudioEngineWithRemoteParams()
        //setup audio
        
        BikeInProgressController.setupListener?.delegate = self
        
        BikeInProgressController.setupListener?.startListening()
        
        self.listenBell.backgroundColor = UIColor.red

        
    }
    
    func returnToHome() {
        self.performSegue(withIdentifier: "returnHome", sender: self)
    }
    
    
    func ringDetected(centerFreq:Int) {
        self.listenBell.backgroundColor = UIColor.yellow
        let fadeTime = DispatchTime.now() + .seconds(1)
        DispatchQueue.main.asyncAfter(deadline: fadeTime) {
            self.listenBell.backgroundColor = UIColor.green
        }
        let defaults = UserDefaults.standard
        defaults.set(centerFreq, forKey: Constants.bikeBellFreq)
       
        BikeInProgressController.listener?.stopListening()
        self.returnToHome()
    }

    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
