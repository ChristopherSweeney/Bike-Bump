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
    
    //timestamp format
    let formatter = DateFormatter()

        //fft params
    var n: NSInteger
    var n2:vDSP_Length
    var log_n:vDSP_Length
    var fftSetup: FFTSetup?
    
    //temp storage
    var currentSoundBuffers:[AVAudioPCMBuffer]
    var soundClipDuration:Double
    var numBufferPerClip:Int
    
    
    //audio graph params
    var audioEngine:AVAudioEngine = AVAudioEngine()
    var audioSession = AVAudioSession.sharedInstance()
    var inputNode:AVAudioInputNode//microphone node
    var filter:AVAudioUnitEQ//lowpass filter
    
    //microphone harware params
    // let ioBufferDuration = 128.0 / 44100.0
    var samplingRate:Double //hz
    var targetFrequncy:Double //hz
    var targetFrequncyThreshold:Double //hz
    
    init(samplingRate:Double,
         soundClipDuration:Double,
         targetFrequncy:Double,
         targetFrequncyThreshold:Double,
         bufferLength:Int) {
        
        self.samplingRate = samplingRate
        self.targetFrequncy = targetFrequncy
        self.targetFrequncyThreshold = targetFrequncyThreshold
        self.inputNode = audioEngine.inputNode!
        self.filter = AVAudioUnitEQ(numberOfBands:1)
        
        self.n = NSInteger(bufferLength)
        self.n2 = vDSP_Length(bufferLength/2)
        self.log_n = vDSP_Length(log2(Float(bufferLength)))
        self.fftSetup = nil
        
        self.soundClipDuration = soundClipDuration
        self.currentSoundBuffers = []
        self.numBufferPerClip = Int(soundClipDuration*samplingRate/Double(bufferLength))
        
        formatter.dateFormat = "dd.MM.yyyy.mm.ss"


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
            self.filter.installTap(onBus: 0, bufferSize: AVAudioFrameCount(self.n), format: self.filter.inputFormat(forBus: 0)) {
                //get l4oc
                (buffer: AVAudioPCMBuffer!, time: AVAudioTime!) -> Void in
                if(self.currentSoundBuffers.count < self.numBufferPerClip){
                    self.currentSoundBuffers.append(buffer)
                }
                else {
                    self.currentSoundBuffers.remove(at: 0)
                    self.currentSoundBuffers.append(buffer)
                    if(self.detectFrequency(buffer: buffer)){
                        self.currentSoundBuffers.removeAll()
                        var file:AVAudioFile = AVAudioFile(forWriting: URL("audio_sample_" + formatter.string(from: Date())), settings: self.audioFileSettings())
                        DispatchQueue.global(qos: .background).async {
                            print("This is run on the background queue")
                            
                                                    }
                        
                    }

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
                    self.fftSetup = vDSP_create_fftsetup(self.log_n, FFTRadix(kFFTRadix2))!
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
           vDSP_destroy_fftsetup(fftSetup)

        }
        catch {
            print("could not end session")
        }
        
    }
    
    private func detectFrequency(buffer:AVAudioPCMBuffer) -> Bool {
         return fft(soundClip: buffer)
    }
    
    private func fft(soundClip:AVAudioPCMBuffer) -> Bool {
        // create vectors
        var tempSplitComplexReal : [Float] = [Float](repeating: 0.0, count: n/2)
        var tempSplitComplexImag : [Float] = [Float](repeating: 0.0, count: n/2)
        var tempSplitComplex : DSPSplitComplex = DSPSplitComplex(realp: &tempSplitComplexReal, imagp: &tempSplitComplexImag)
        var splitComplex : DSPSplitComplex = DSPSplitComplex(realp: soundClip.floatChannelData![0], imagp: &tempSplitComplexImag)
        
        // FFT
        vDSP_fft_zript(fftSetup!, &splitComplex, vDSP_Stride(1), &tempSplitComplex, log_n, FFTDirection(FFT_FORWARD));
        
       //analyze results
        var fftMagnitudes = [Float](repeating:0.0, count:n)
        vDSP_zvmags(&splitComplex, 1, &fftMagnitudes, 1, vDSP_Length(n));
        let roots = fftMagnitudes.map {sqrtf($0)}
        // Normalize the Amplitudes
        var fullSpectrum = [Float](repeating:0.0, count:Int(n2)/2)
        print(roots.max() ?? Float())
        
//        vDSP_vsmul(roots, vDSP_Stride(1), [1.0 / Float(n)], &fullSpectrum, 1, n2)
//        
//        print(fullSpectrum)
        
        
        return true
        
    }
    
    private func audioFileSettings() -> Dictionary<String, Any>
    {
        return [
            AVSampleRateKey : 44100,
            AVNumberOfChannelsKey : 1,
            AVFormatIDKey : kAudioFormatLinearPCM
        ]
    }
    
}
