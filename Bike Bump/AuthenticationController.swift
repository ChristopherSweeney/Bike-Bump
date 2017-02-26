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
    
    //UI
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
        //periodic alert for no network connection
        let networkChecker = Timer.scheduledTimer(timeInterval: 10.0, target: self, selector: #selector(networkAlert), userInfo: nil, repeats: true)
        
        let connectedRef = FIRDatabase.database().reference(withPath: ".info/connected")
        connectedRef.observe(.value, with: { (connected) in
            //connected!
            if let boolean = connected.value as? Bool, boolean == true {
                networkChecker.invalidate()
                //pull Firebase params, requires internet connection: WARNING, change expration to larger number in production
                    FIRAuth.auth()!.addStateDidChangeListener() { auth, user in
                        if user != nil {
                            FIRRemoteConfig.remoteConfig().fetch(withExpirationDuration: 0) {
                                (status, error) in
                                print("params fetched")
                                self.performSegue(withIdentifier: "main", sender: self)
                        }
                }
            }
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
    
    func networkAlert() {
        let alert = UIAlertController(title: "Network connection", message: "Network connection required. Please connect to network.", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: nil))
        self.present(alert, animated: true, completion: nil)

    }
}


