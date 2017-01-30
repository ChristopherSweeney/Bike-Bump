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

let roadInfo = "api/dings/add?"
let baseURL = "https://bikebump.media.mit.edu/"

public class NetworkManager {

    //firebase storage
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
    
    //user name?
//   static func getParams(lat:Float, lng:Float, timeStamp:String) {
//        let url:String = NetworkManager.getEndpointForCoordinates(lat: lat, lng: lng)
//        var request = URLRequest(url: URL(string: url)!)
//        request.httpMethod = "GET"
//        //is this initialzed everytime?
//        let session = URLSession.shared
//        session.dataTask(with: request) {data, response, err in
//            print("storing user data results to Firebase")
//            FIRDatabase.database().reference().child("dings").updateChildValues(["test2":234])
//
//
//            let httpResponse = response as! HTTPURLResponse
//            let statusCode = httpResponse.statusCode
//            print(httpResponse.description)
//            }.resume()
//
//    }
    
    static func sendDing(lat:Float, lng:Float, timeStamp:String) {
        
        //should have user authenticated
        let user = FIRAuth.auth()?.currentUser
        let uid = user?.uid
        let params:[URLQueryItem] = ["lat":lat,"long":lng,"timestamp":timeStamp,"uid":uid!].map {(key, value) in (URLQueryItem(name: key, value: String(describing: value)))}
        var url = URLComponents(string: baseURL)!
        url.queryItems = params
        let query = url.url
        var request = URLRequest(url: query!)
        request.httpMethod = "PUT"
        
        //is this initialzed everytime?
        let session = URLSession.shared
        session.dataTask(with: request) {data, response, err in
            print("storing user data results to Firebase")
            let httpResponse = response as! HTTPURLResponse
            let statusCode = httpResponse.statusCode
            print(statusCode)
            }.resume()
        
    }

}
