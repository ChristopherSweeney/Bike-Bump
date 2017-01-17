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

public class Listener: NSObject {
    
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
        let n = NSInteger(soundClip.frameLength)
        let n2 = vDSP_Length(n/2)
        let log_n = vDSP_Length(log2(Float(soundClip.frameLength)))

        let fftSetup: FFTSetupD = vDSP_create_fftsetup(log_n, FFTRadix(kFFTRadix2))!
        
              
        var tempSplitComplexReal : [Float] = [Float](repeating: 0.0, count: n/2)
        var tempSplitComplexImag : [Float] = [Float](repeating: 0.0, count: n/2)
        var tempSplitComplex : DSPSplitComplex = DSPSplitComplex(realp: &tempSplitComplexReal, imagp: &tempSplitComplexImag)
        var splitComplex : DSPSplitComplex = DSPSplitComplex(realp: soundClip.floatChannelData![0], imagp: &tempSplitComplexImag)
        
        // ----------------------------------------------------------------
        // Forward FFT
        // ----------------------------------------------------------------
        
        
        // Do real->complex forward FFT
        vDSP_fft_zript(fftSetup, &splitComplex, vDSP_Stride(1), &tempSplitComplex, log_n, FFTDirection(FFT_FORWARD));
       
        var fftMagnitudes = [Float](repeating:0.0, count:n/2)
        vDSP_zvmags(&splitComplex, 1, &fftMagnitudes, 1, n2);
        
        // vDSP_zvmagsD returns squares of the FFT magnitudes, so take the root here
        let roots = fftMagnitudes.map {sqrtf($0)}
        
        // Normalize the Amplitudes
        var fullSpectrum = [Float](repeating:0.0, count:Int(n2)/2)
        print(roots)
        vDSP_vsmul(roots, vDSP_Stride(1), [1.0 / Float(n)], &fullSpectrum, 1, n2)
        
        print(fullSpectrum)
        
        
        return true
        
    }
//    func fileProcessingFormat() -> Dictionary<String, Any>
//    {
//        return Nill
//    }
    
}
