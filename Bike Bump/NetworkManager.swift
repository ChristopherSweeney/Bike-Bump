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
import FirebaseStorage
let roadInfo = "api/road/ROADID"
let baseURL = "https://bikebump.media.mit.edu/"


let sharedNetworkManager = NetworkManager()

public class NetworkManager: NSObject {

    
    override init() {
        
    }
    
    //firebase
    static func sendToServer(path: URL) -> Bool {
        
        let storage = FIRStorage.storage().reference()
        
        let soundRef = storage.child("soundClips/" + path.lastPathComponent)
        
        let uploadTask = soundRef.putFile(path, metadata: nil) { metadata, error in
            if let error = error {
                print("error")
            }
            else {
                do {
                    try FileManager.default.removeItem(at: path)
                }
                catch {
                    print("couldnt delete file")
                }
                // Metadata contains file metadata such as size, content-type, and download URL.
                let downloadURL = metadata!.downloadURL()
            }
        }
        return true
    
    
}
    func getEndpointForCoordinates(lat:Float, long:Float) -> String {
        return baseURL + "api/road/closest?lng=" + String(long) + "&lat=-" + String(lat)

    }
    
    //REST
    func get(url:String, rest:String) {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = rest
        let session = URLSession.shared
        session.dataTask(with: request) {data, response, err in
            print("Entered the completionHandler")
            }.resume()
    }
}
