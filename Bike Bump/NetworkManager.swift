//
//  NetworkManager.swift
//  Bike Bump
//
//  Created by Chris Sweeney on 1/15/17.
//  Copyright © 2017 Chris Sweeney. All rights reserved.
//
import FirebaseCore
import FirebaseDatabase
import FirebaseAuth
import UIKit
import AVFoundation
import FirebaseStorage

let addDing = "api/dings/add?"
let baseURL = "https://bikebump.media.mit.edu/"

public class NetworkManager {

    //firebase direct storage for audio files
    static func sendToServer(path: URL) {
        
        let storage = FIRStorage.storage().reference()
        
        let soundRef = storage.child("soundClips/" + path.lastPathComponent)
        
        _ = soundRef.putFile(path, metadata: nil) { metadata, error in
            if error != nil {
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
                _ = metadata!.downloadURL()
            }
        }    
    }
    
     private static func getEndpointForCoordinates(lat:Float, lng:Float) -> String {
        return baseURL + "api/road/closest?lng=" + String(lng) + "&lat=-" + String(lat)

    }
    
    
    static func sendDing(lat:Float, lng:Float, timeStamp:Int, value:Int) {
        
        //should have user authenticated
        let user = FIRAuth.auth()?.currentUser
        let uid = user?.uid
        let params:[String:Any] = ["lat":lat,"lng":lng,"timestamp":timeStamp,"uid":uid!,"value":String(value)]
        let paramArray:[String] = params.map {(key, value) in
            key + "=" + String(describing: value) + "&"}
        let paramString:String = paramArray.reduce("", +)
        var request = URLRequest(url: URL(string:baseURL+addDing)!)
        request.httpBody = paramString.data(using: String.Encoding.utf8);
        
        request.httpMethod = "POST"
        
        //is this initialzed everytime?
        let session = URLSession.shared
        session.dataTask(with: request) {data, response, err in
            print("storing user data results to Firebase")
            //protect against null network return
            guard let httpResponse = response as? HTTPURLResponse else {
                print("network connection issues")
                return
            }
            let statusCode = httpResponse.statusCode
            print(statusCode)
            }.resume()
        
    }

}
