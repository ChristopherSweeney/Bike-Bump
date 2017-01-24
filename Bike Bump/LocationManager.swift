//
//  LocationManager.swift
//  Bike Bump
//
//  Created by Chris Sweeney on 1/15/17.
//  Copyright © 2017 Chris Sweeney. All rights reserved.
//

import UIKit
import CoreLocation


public class LocationManager: NSObject {
    
    static let sharedLocationManager = LocationManager()

    //timestamp format
    let formatter = DateFormatter()
    
    //location manager
    let location = CLLocationManager()
    
    override init() {
        location.requestAlwaysAuthorization()
        location.desiredAccuracy = kCLLocationAccuracyBest
        location.startUpdatingLocation()
        formatter.dateFormat = "dd-MM-yyyy-mm-ss"
    }
    
    func getLocation() -> CLLocation {
        return location.location!
    }
    
    func getCurrentTime() -> String {
        return self.formatter.string(from: Date())
    }
    
    
    
}
