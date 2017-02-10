//
//  ViewController.swift
//  Bike Bump
//
//  Created by Chris Sweeney on 1/11/17.
//  Copyright © 2017 Chris Sweeney. All rights reserved.
//
import FirebaseAuth
import FirebaseCore
import FirebaseDatabase
import UIKit
import AVFoundation
import CoreLocation
import FirebaseRemoteConfig


class AuthenticationController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var user: UITextField!
    @IBOutlet weak var password: UITextField!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var signUp: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loginButton.addTarget(self, action: #selector(self.login), for:  UIControlEvents.touchUpInside)
        signUp.addTarget(self, action: #selector(self.createUser), for:  UIControlEvents.touchUpInside)
        user.delegate = self
        password.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        //block if network is not connected- > in Future, allow local storage and push sound clips when eventually connected with network
        //callback to see if logged in
        //prevent loging in until server params are set
        let isConnected = FIRDatabase.database().reference(withPath: ".info/connected")
        isConnected.observe(.value, with: { snapshot in
            if let connected = snapshot.value as? Bool , connected {
                //pull Firebase info
                FIRRemoteConfig.remoteConfig().fetch(withExpirationDuration: 0) {
                    (status, error) in
                    print("params fetched")
                    FIRAuth.auth()!.addStateDidChangeListener() { auth, user in
                        if user != nil {
                            self.performSegue(withIdentifier: "main", sender: self)
                        }
                    }
                }

            } else {
                let alert = UIAlertController(title: "Network connection", message: "Network connection required. Please connect to network.", preferredStyle: UIAlertControllerStyle.alert)
                alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        })
          }

   override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func login() {
        print("login function")
        FIRAuth.auth()!.signIn(withEmail: user.text!,
                               password:  password.text!)
    }
    
    func createUser() {
        print("create User")
        FIRAuth.auth()!.createUser(withEmail: self.user.text!,
                                   password: self.password.text!) { user, error in
                                    if error == nil {
                                        FIRAuth.auth()!.signIn(withEmail: self.user.text!,
                                                               password: self.password.text!)
                                    }
                        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }
}


