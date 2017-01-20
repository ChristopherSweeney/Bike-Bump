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

class AuthenticationController: UIViewController {
    //store crudentials locally
    @IBOutlet weak var user: UITextField!
    //encrypt dots
    @IBOutlet weak var password: UITextField!
    @IBOutlet weak var loginButton: UIButton!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loginButton.addTarget(self, action: #selector(self.login), for:  UIControlEvents.touchUpInside)
    }

   override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func login() {
        let storyboard = self.storyboard
        let controller = storyboard?.instantiateViewController(withIdentifier: "BikeInProgressController")
        self.present(controller!, animated: true, completion: nil)    }
}

