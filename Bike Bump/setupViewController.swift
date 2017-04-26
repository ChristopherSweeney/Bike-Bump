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
                
        BikeInProgressController.setupListener?.delegate = self
        
        BikeInProgressController.setupListener?.startListening()
        
        self.listenBell.backgroundColor = UIColor.red

        
    }
    
    func returnToHome() {
        if(BikeInProgressController.setupListener?.isListening())!{
            BikeInProgressController.setupListener?.stopListening()
        }
        self.performSegue(withIdentifier: "returnHome", sender: self)
    }
    
    
    func ringDetected(centerFreq:Int) {
        DispatchQueue.main.async {
            self.listenBell.backgroundColor = UIColor.yellow
            self.listenBell.titleLabel!.text = "Calibrated!"
        }
        let fadeTime = DispatchTime.now() + .seconds(2)
        DispatchQueue.main.asyncAfter(deadline: fadeTime) {
            self.listenBell.backgroundColor = UIColor.green
            self.listenBell.titleLabel!.text = "Listen to Bell"

        }
        let defaults = UserDefaults.standard
        defaults.set(centerFreq, forKey: Constants.bikeBellFreq)
       
        BikeInProgressController.setupListener?.stopListening()
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
