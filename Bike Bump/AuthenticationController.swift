//
//  ViewController.swift
//  Bike Bump
//
//  Created by Chris Sweeney on 1/11/17.
//  Copyright © 2017 Chris Sweeney. All rights reserved.
//
import FirebaseAuth
import UIKit
import AVFoundation
import CoreLocation
import FirebaseRemoteConfig


class AuthenticationController: UIViewController {
    //store crudentials locally
    
    @IBOutlet weak var user: UITextField!
    //encrypt dots
    @IBOutlet weak var password: UITextField!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var signUp: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loginButton.addTarget(self, action: #selector(self.login), for:  UIControlEvents.touchUpInside)
        signUp.addTarget(self, action: #selector(self.createUser), for:  UIControlEvents.touchUpInside)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        //callback to see if logged in
        //prevent loging in until server params are set
       FIRRemoteConfig.remoteConfig().fetch(withExpirationDuration: 0) {
            (status, error) in
            print("params fetched")
            FIRAuth.auth()!.addStateDidChangeListener() { auth, user in
                if user != nil {
                    self.performSegue(withIdentifier: "main", sender: nil)
                    }
            }
        }
    }

   override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func login() {
        FIRAuth.auth()!.signIn(withEmail: user.text!,
                               password:  password.text!)
    }
    
    func createUser() {
        FIRAuth.auth()!.createUser(withEmail: self.user.text!,
                                   password: self.password.text!) { user, error in
                                    if error == nil {
                                        FIRAuth.auth()!.signIn(withEmail: self.user.text!,
                                                               password: self.password.text!)
                                    }
                        }
    }
}


