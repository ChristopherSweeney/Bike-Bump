//
//  LocationManager.swift
//  Bike Bump
//
//  Created by Chris Sweeney on 1/15/17.
//  Copyright © 2017 Chris Sweeney. All rights reserved.
//

import UIKit
import CoreLocation

class LocationManager: NSObject {
    
//    let sharedLocationManager = LocationManager()
    
    let location = CLLocationManager()
    
    override init() {
        location.requestAlwaysAuthorization()
        location.desiredAccuracy = kCLLocationAccuracyBest
        location.startUpdatingLocation()
    }
    
    func getLocation() -> CLLocation {
        return location.location!
    }
    
    
    
}
