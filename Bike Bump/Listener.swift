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

//callback protocol to update UI from audio events
protocol AudioEvents:class {
    func ringDetected()
}

/* The Listener object buffers mic input and sends a sound clip if a central frequency is heard at a certain frequency post fft */

public class Listener: NSObject {
    
    //UI delegate
    weak var delegate:AudioEvents?

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
    var samplingRate:Int //hz
    var targetFrequncy:Int //hz
    var targetFrequncyThreshold:Int //hz
    
    //queue to control concurrency problems
    let soundQueue:DispatchQueue = DispatchQueue(label: "com.example.audiofftqueue")

    init(samplingRate:Int,
         soundClipDuration:Double,
         targetFrequncy:Int,
         targetFrequncyThreshold:Int,
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
        self.numBufferPerClip = Int(soundClipDuration*Double(samplingRate)/Double(bufferLength))
    }
    
    public func initializeAudio() {
        do {
            try audioSession.setActive(true)
            try audioSession.setCategory(AVAudioSessionCategoryRecord)
            try audioSession.setPreferredSampleRate(Double(self.samplingRate))
            try audioSession.setPreferredInputNumberOfChannels(1)
            try audioSession.setMode(AVAudioSessionModeMeasurement)
            self.setupFilter()
            self.audioEngine.attach(self.filter)
            
            //keep track of how to control audio processing format -changing sample rate
            self.audioEngine.connect(inputNode, to:self.filter , format: self.inputNode.inputFormat(forBus: 0))
            
            //listen for mic data - maybe do fiter post fft
            self.filter.installTap(onBus: 0, bufferSize: AVAudioFrameCount(self.n), format: self.filter.inputFormat(forBus: 0)) {
                (buffer: AVAudioPCMBuffer!, time: AVAudioTime!) -> Void in
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
                //callback for UI
                DispatchQueue.main.async() {
                    self.delegate?.ringDetected()
                }
                do {
                    //get enviornment info - > maybe make location manager local
                    let lat:Double = LocationManager.sharedLocationManager.getLocation().coordinate.latitude
                    let long:Double = LocationManager.sharedLocationManager.getLocation().coordinate.latitude
                    let curTime:String = LocationManager.sharedLocationManager.getCurrentTime()
                    
                    //create wav file
                    let base:String = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
                    let fileURL:URL = URL.init(fileURLWithPath: (base + "/Audio_Sample_" + curTime + "_lat=\(lat)_long=\(long).wav"))
                    let file:AVAudioFile = try AVAudioFile(forWriting:fileURL, settings: self.audioFileSettings())
                    
                    //merge buffers into files
                    for buffer in self.currentSoundBuffers {
                        try file.write(from: buffer)
                    }
                    //flush sound cache
                    self.currentSoundBuffers.removeAll()
                    
                    //send files to server
                    DispatchQueue.global(qos: .background).async {
                        NetworkManager.sendToServer(path:fileURL)
                        NetworkManager.sendDing(lat:Float(lat), lng:Float(long), timeStamp:curTime,value:0)
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
        //offload initialization so you can start and stop
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
    
    public func isListening() -> Bool {
        return self.audioEngine.isRunning
    }
    
    private func detectFrequency(buffer:AVAudioPCMBuffer) -> Bool {
         return abs(Float(targetFrequncy) - fftFundementalFreq(soundClip: buffer)) < Float(targetFrequncyThreshold)
    }
    
    private func fftFundementalFreq(soundClip:AVAudioPCMBuffer) -> Float {
        
        // create vectors
        var tempReal : [Float] = [Float](repeating: 0.0, count: n)
        var tempImag : [Float] = [Float](repeating: 0.0, count: n)
        var tempSplitComplex : DSPSplitComplex = DSPSplitComplex(realp: &tempReal, imagp: &tempImag)
        var splitComplex : DSPSplitComplex = DSPSplitComplex(realp: soundClip.floatChannelData![0], imagp: &tempImag)
        
        // FFT
        vDSP_fft_zript(fftSetup!, &splitComplex, vDSP_Stride(1), &tempSplitComplex, log_n, FFTDirection(FFT_FORWARD));
        
       //package results
        var fftMagnitudes = [Float](repeating:0.0, count:Int(n))
        vDSP_zvmags(&splitComplex, 1, &fftMagnitudes, 1, vDSP_Length(n));
        var roots = fftMagnitudes.map {sqrtf($0)}
        let maxIndex:Int = roots.index(of: roots.max()!)!
//        print(indexToFrequency(N: n, index: maxIndex))
       
        //normalize reults
//        var fullSpectrum = [Float](repeating:0.0, count:Int(n))
//        vDSP_vsmul(roots, vDSP_Stride(1), [1.0 / Float(n)], &fullSpectrum, 1, vDSP_Length(n))
        
        print(calculateSlope(index: maxIndex, width: 10, array: &roots))
        print(calculateSlope(index: maxIndex, width: -10, array: &roots))

        return Float(indexToFrequency(N: n, index: roots.index(of: roots.max()!)!))
    }
    
    private func audioFileSettings() -> Dictionary<String, Any>
    {
        return [
            AVSampleRateKey : samplingRate,
            AVNumberOfChannelsKey : 2,
            AVFormatIDKey : kAudioFormatLinearPCM
        ]
    }
    
    private func indexToFrequency(N:Int, index:Int) -> Double {
        return Double(index)*Double(self.samplingRate)/Double(N)
    }
    
    private func calculateSlope(index:Int, width:Int, array: inout [Float]) -> Float {
        //average 3 points as jank way of damping noise
        return (array[index]-(array[min(max(0,index+width-3),array.count-1)..<max(0,min(array.count-1,(index+width+4)))].reduce(0,+)))/Float(width)
    }
    
    
}
