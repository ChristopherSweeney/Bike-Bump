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
    var inputNode:AVAudioInputNode//microphone node
    var filter:AVAudioUnitEQ//lowpass filter
    
    //params
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
        self.filter = AVAudioUnitEQ(numberOfBands:1)
    }
    
    private func initializeAudio() {
        do {
            try audioSession.setActive(true)
            try audioSession.setCategory(AVAudioSessionCategoryRecord)
            try audioSession.setPreferredSampleRate(self.samplingRate)
            // try audioSession.setPreferredIOBufferDuration(ioBufferDuration)
            try audioSession.setMode(AVAudioSessionModeMeasurement)
            self.setupFilter()
            self.audioEngine.attach(self.filter)
            //keep track of how to control audio processing format -changing sample rate
            self.audioEngine.connect(inputNode, to:self.filter , format: self.filter.inputFormat(forBus: 0))
            self.filter.installTap(onBus: 0, bufferSize: 8192, format: self.filter.inputFormat(forBus: 0)) {
                //get l4oc
                (buffer: AVAudioPCMBuffer!, time: AVAudioTime!) -> Void in
                if(self.detectFrequency(buffer: buffer)){
                    
                }
            }
        }
        //cancel recording if any problems
        catch {
            print("something went wrong")
        }
        
    
    }
    
    private func setupFilter(){
         filter.bands[0].filterType = AVAudioUnitEQFilterType.lowPass
         filter.bands[0].frequency = 3000;
    }
    
    public func startListening() {
        audioSession.requestRecordPermission({(permissionGranted: Bool) -> Void in
            if permissionGranted {
                self.initializeAudio()
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
         return fft(soundClip: buffer)
    }
    
    func fft(soundClip:AVAudioPCMBuffer) -> Bool {
        print("fft")
        var buffer:UnsafeBufferPointer = UnsafeBufferPointer(start: soundClip.floatChannelData, count: Int(soundClip.frameLength));
        //let buffer = UnsafeBufferPointer(soundClip.audioBufferList[0].mBuffers)
        let n = NSInteger(soundClip.frameLength)
        let n2 = vDSP_Length(n/2)
        let log_n = vDSP_Length(log2(Float(soundClip.frameLength)))

        let fftSetup: FFTSetupD = vDSP_create_fftsetupD(log_n, FFTRadix(kFFTRadix2))!
        
        // We need complex buffers in two different formats!
        var tempComplex : [DSPDoubleComplex] = [DSPDoubleComplex](repeating: DSPDoubleComplex(), count: n/2)
        
        var tempSplitComplexReal : [Double] = [Double](repeating: 0.0, count: n/2)
        var tempSplitComplexImag : [Double] = [Double](repeating: 0.0, count: n/2)
        var tempSplitComplex : DSPDoubleSplitComplex = DSPDoubleSplitComplex(realp: &tempSplitComplexReal, imagp: &tempSplitComplexImag)
        
        // For polar coordinates
        var mag : [Double] = [Double](repeating: 0.0, count: n/2)
        var phase : [Double] = [Double](repeating: 0.0, count: n/2)
        
        // ----------------------------------------------------------------
        // Forward FFT
        // ----------------------------------------------------------------
        
        var valuesAsComplex : UnsafeMutablePointer<DSPDoubleComplex>?
//      valuesAsComplex = UnsafeMutablePointer<DSPDoubleComplex>(buffer.baseAddress)
        var numbers:[DSPDoubleComplex] = Array(buffer).map{(DSPDoubleComplex(real: Double($0),imag: 0))}
        valuesAsComplex = &numbers

        
        // Scramble-pack the real data into complex buffer in just the way that's
        // required by the real-to-complex FFT function that follows.
        vDSP_ctozD(valuesAsComplex!, 2, &tempSplitComplex, 1, n2);
        
        // Do real->complex forward FFT
        vDSP_fft_zripD(fftSetup, &tempSplitComplex, 1, log_n, FFTDirection(FFT_FORWARD));
       
        let magnitudes = Array(zip(Array(UnsafeBufferPointer(start: tempSplitComplex.realp, count:Int(n2))),Array(UnsafeBufferPointer(start: tempSplitComplex.imagp, count:Int(n2)))).map { (sqrt(pow($0,2)+pow($1,2)))})
        print(magnitudes)
        
    }
//    func fileProcessingFormat() -> Dictionary<String, Any>
//    {
//        return Nill
//    }
    
}
