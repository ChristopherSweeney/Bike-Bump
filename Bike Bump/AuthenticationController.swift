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
    
    @IBOutlet weak var user: UITextField!
    //encrypt dots
    @IBOutlet weak var password: UITextField!
    @IBOutlet weak var loginButton: UIButton!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

   override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

