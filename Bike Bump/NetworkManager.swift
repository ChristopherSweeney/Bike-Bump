//
//  NetworkManager.swift
//  Bike Bump
//
//  Created by Chris Sweeney on 1/15/17.
//  Copyright © 2017 Chris Sweeney. All rights reserved.
//
import FirebaseCore
import UIKit
import AVFoundation

let sharedNetweorkManager = NetworkManager()

public class NetworkManager: NSObject {

    
    override init() {
        
    }
    
    //return type clousure to signal successs
    func sendToServer(file: AVAudioFile) -> Bool {
//        let storageRef = storage.reference()
        return true
    
}
}
