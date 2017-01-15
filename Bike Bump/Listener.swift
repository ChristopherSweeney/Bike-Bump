//
//  Listener.swift
//  Bike Bump
//
//  Created by Chris Sweeney on 1/15/17.
//  Copyright © 2017 Chris Sweeney. All rights reserved.
//

import UIKit
import AVFoundation

/* The Listener object buffers mic input and sends a sound clip if a central frequency is heard at a certain frequency */

class Listener: NSObject {
    
    //constants
    let audioEngine:AVAudioEngine = AVAudioEngine()
    let audioSession = AVAudioSession.sharedInstance()
    let ioBufferDuration = 128.0 / 44100.0
    
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
            
            self.inputNode.installTap(onBus: 0, bufferSize: 2048, format: inputNode.inputFormat(forBus: 0)) {
                (buffer: AVAudioPCMBuffer!, time: AVAudioTime!) -> Void in
                Swift.print(buffer.frameLength)
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
                    self.audioEngine.prepare()
                    try self.audioEngine.start()
                    print("started engine")
                    print(self.inputNode.inputFormat(forBus: 0).description)

                }
                catch {
                    print("Audio Failure")
                }
            }
         })
    }
    
    public func stopListening() {
        audioEngine.stop()
    }
    
    
}
