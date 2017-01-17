//
//  NetworkManager.swift
//  Bike Bump
//
//  Created by Chris Sweeney on 1/15/17.
//  Copyright © 2017 Chris Sweeney. All rights reserved.
//

import UIKit
import AVFoundation

public class NetworkManager: NSObject {

    let sharedNetweorkManager = NetworkManager()
    
    //return type clousure to signal successs
    func sendToServer(file: AVAudioFile) -> Bool {
        return true
    }
}
