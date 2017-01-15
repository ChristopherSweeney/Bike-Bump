//
//  Listener.swift
//  Bike Bump
//
//  Created by Chris Sweeney on 1/15/17.
//  Copyright © 2017 Chris Sweeney. All rights reserved.
//

import UIKit
import AVFoundation
import Accelerate

/* The Listener object buffers mic input and sends a sound clip if a central frequency is heard at a certain frequency */

class Listener: NSObject {
    
    //constants
    let ioBufferDuration = 128.0 / 44100.0
    var audioEngine:AVAudioEngine = AVAudioEngine()
    var audioSession = AVAudioSession.sharedInstance()
    
    //params
    var inputNode:AVAudioInputNode//microphone node
    var samplingRate:Double //hz
    var soundClipDuration:Double //seconds
    var targetFrequncy:Double //hz
    var targetFrequncyThreshold:Double //hz
    
    init(samplingRate:Double,
         soundClipDuration:Double,
         targetFrequncy:Double,
         targetFrequncyThreshold:Double) {
        
        self.samplingRate = samplingRate
        self.soundClipDuration = soundClipDuration
        self.targetFrequncy = targetFrequncy
        self.targetFrequncyThreshold = targetFrequncyThreshold
        self.inputNode = audioEngine.inputNode!
    }
    
    private func initializeAudioSession() {
        do {
            try audioSession.setActive(true)
            try audioSession.setCategory(AVAudioSessionCategoryRecord)
            try audioSession.setPreferredSampleRate(self.samplingRate)
            // try audioSession.setPreferredIOBufferDuration(ioBufferDuration)
            try audioSession.setMode(AVAudioSessionModeMeasurement)
            self.inputNode.installTap(onBus: 0, bufferSize: 8192, format: self.inputNode.inputFormat(forBus: 0)) {
                (buffer: AVAudioPCMBuffer!, time: AVAudioTime!) -> Void in
                if(self.detectFrequency(buffer: buffer)){
                    //send data to server
                }
            }
        }
        //cancel recording if any problems
        catch {
            print("something went wrong")
        }
        
    
    }
    
    public func startListening() {
        audioSession.requestRecordPermission({(permissionGranted: Bool) -> Void in
            if permissionGranted {
                self.initializeAudioSession()
                do {
                    try self.audioEngine.start()
                    print("started engine")
                }
                catch {
                    print("Audio Failure")
                }
            }
         })
    }
    
    public func stopListening() {
        audioEngine.stop()
        do {
          try audioSession.setActive(false)
        }
        catch {
            print("could not end session")
        }
    }
    
    func detectFrequency(buffer:AVAudioPCMBuffer) -> Bool {
         return true
    }
    
    func fft(soundClip:Double) -> Bool {
        return true
    }
    
    
}
