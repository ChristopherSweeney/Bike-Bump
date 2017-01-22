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

protocol AudioEvents:class {
    func ringDetected()
}

/* The Listener object buffers mic input and sends a sound clip if a central frequency is heard at a certain frequency */

public class Listener: NSObject {
    
    //UI delegate
    weak var delegate:AudioEvents?

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
    var lowPassFreq:Int
    
    //microphone harware params
    // let ioBufferDuration = 128.0 / 44100.0
    var samplingRate:Double //hz
    var targetFrequncy:Double //hz
    var targetFrequncyThreshold:Double //hz
    
    let soundQueue:DispatchQueue = DispatchQueue(label: "com.example.audiofftqueue")

    var len = 0
    init(samplingRate:Double,
         soundClipDuration:Double,
         targetFrequncy:Double,
         targetFrequncyThreshold:Double,
         bufferLength:Int,
         lowPassFreq:Int) {
        
        self.samplingRate = samplingRate
        self.targetFrequncy = targetFrequncy
        self.targetFrequncyThreshold = targetFrequncyThreshold
        self.inputNode = audioEngine.inputNode!
        self.filter = AVAudioUnitEQ(numberOfBands:1)
        self.lowPassFreq = lowPassFreq
        
        self.n = NSInteger(bufferLength)
        self.n2 = vDSP_Length(bufferLength/2)
        self.log_n = vDSP_Length(log2(Float(bufferLength)))
        self.fftSetup = nil
        
        self.soundClipDuration = soundClipDuration
        self.currentSoundBuffers = []
        self.numBufferPerClip = Int(soundClipDuration*samplingRate/Double(bufferLength))
        formatter.dateFormat = "dd-MM-yyyy-mm-ss"
        

    }
    
    public func initializeAudio() {
        do {
            try audioSession.setActive(true)
            try audioSession.setCategory(AVAudioSessionCategoryRecord)
            try audioSession.setPreferredSampleRate(self.samplingRate)
            try audioSession.setPreferredInputNumberOfChannels(1)
            // try audioSession.setPreferredIOBufferDuration(ioBufferDuration)
            try audioSession.setMode(AVAudioSessionModeMeasurement)
            self.setupFilter()
            self.audioEngine.attach(self.filter)
            //keep track of how to control audio processing format -changing sample rate
            self.audioEngine.connect(inputNode, to:self.filter , format: self.filter.inputFormat(forBus: 0))
            self.filter.installTap(onBus: 0, bufferSize: AVAudioFrameCount(self.n), format: self.filter.inputFormat(forBus: 0)) {
                (buffer: AVAudioPCMBuffer!, time: AVAudioTime!) -> Void in
                //control access to global varibles via serial queue
                self.soundQueue.sync {
                    self.audioProcessingBlock(buffer: buffer)
                }
            }
        }
        //cancel recording if any problems
        catch {
            print("something went wrong")
        }
        
    
    }
    
    func audioProcessingBlock(buffer: AVAudioPCMBuffer) {
        
        if(self.currentSoundBuffers.count < self.numBufferPerClip){
            self.currentSoundBuffers.append(buffer)
        }
        else {
            self.currentSoundBuffers.remove(at: 0)
            self.currentSoundBuffers.append(buffer)
            if(self.detectFrequency(buffer: buffer)){
                DispatchQueue.main.async() {
                    self.delegate?.ringDetected()
                }
                do {
                    let lat:Double = sharedLocationManager.getLocation().coordinate.latitude
                    let long:Double = sharedLocationManager.getLocation().coordinate.latitude
                    let base:String = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
                    var fileURL:URL = URL.init(fileURLWithPath: (base + "/Audio_Sample_" + self.formatter.string(from: Date()) + "_lat=\(lat)_long=\(long).wav"))
                    var file:AVAudioFile = try AVAudioFile(forWriting:fileURL, settings: self.audioFileSettings())
                    for buffer in self.currentSoundBuffers {
                        //remeber to delete file after sending
                        try file.write(from: buffer)
                    }
                    //empty sound cache
                    self.currentSoundBuffers.removeAll()
                    //                              file = nil
                    DispatchQueue.global(qos: .background).async {
                        NetworkManager.sendToServer(path:fileURL)
                    }
                }
                catch{
                    print("could not create file")
                }
            }
            
        }
    }
    private func setupFilter(){
         filter.bands[0].filterType = AVAudioUnitEQFilterType.lowPass
         filter.bands[0].frequency = Float(lowPassFreq);
    }

    public func startListening() {
        //offload initianliztion so you can start and stop
        audioSession.requestRecordPermission({(permissionGranted: Bool) -> Void in
            if permissionGranted {
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
        //anything else to close down - AVAudio File
        audioEngine.stop()
        currentSoundBuffers.removeAll()
        do {
          try audioSession.setActive(false)
           vDSP_destroy_fftsetup(fftSetup)

        }
        catch {
            print("could not end session")
        }
        
    }
    
    private func detectFrequency(buffer:AVAudioPCMBuffer) -> Bool {
         return abs(Float(targetFrequncy)-fft(soundClip: buffer)) < Float(targetFrequncyThreshold)
    }
    
    private func fft(soundClip:AVAudioPCMBuffer) -> Float {
        // create vectors
        var tempSplitComplexReal : [Float] = [Float](repeating: 0.0, count: n/2)
        var tempSplitComplexImag : [Float] = [Float](repeating: 0.0, count: n/2)
        var tempSplitComplex : DSPSplitComplex = DSPSplitComplex(realp: &tempSplitComplexReal, imagp: &tempSplitComplexImag)
        var splitComplex : DSPSplitComplex = DSPSplitComplex(realp: soundClip.floatChannelData![0], imagp: &tempSplitComplexImag)
        
        // FFT
        vDSP_fft_zript(fftSetup!, &splitComplex, vDSP_Stride(1), &tempSplitComplex, log_n, FFTDirection(FFT_FORWARD));
        
       //analyze results
        var fftMagnitudes = [Float](repeating:0.0, count:Int(n2))
        vDSP_zvmags(&splitComplex, 1, &fftMagnitudes, 1, n2);
        let roots = fftMagnitudes.map {sqrtf($0)}
        var fullSpectrum = [Float](repeating:0.0, count:Int(n2))
        //use reduce to iterate though once
        print(indexToFrequency(N: n, index: roots.index(of: roots.max()!)!))
//        vDSP_vsmul(roots, vDSP_Stride(1), [1.0 / Float(n)], &fullSpectrum, 1, n2)
//        
//        print(fullSpectrum)
        
        
        return Float(indexToFrequency(N: n, index: roots.index(of: roots.max()!)!))
        
    }
    
    private func audioFileSettings() -> Dictionary<String, Any>
    {
    
        return [
            AVSampleRateKey : 44100.0,
            AVNumberOfChannelsKey : 2,
            AVFormatIDKey : kAudioFormatLinearPCM
        ]
    }
    
    private func indexToFrequency(N:Int, index:Int) -> Double {
        return Double(index)*self.samplingRate/Double(N)
    }
    
}
