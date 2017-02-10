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
import AudioToolbox


//callback protocol to update UI from audio events
protocol AudioEvents:class {
    func ringDetected()
}

/* The Listener object buffers mic input and sends a sound clip to the server tied with location and time, if a central frequency is heard at a certain frequency post fft */

public class Listener: NSObject {
    
    //UI delegate
    weak var delegate:AudioEvents?

    //fft params
    var n: NSInteger
    var n2:vDSP_Length
    var log_n:vDSP_Length
    var fftSetup: FFTSetup?
    var grabAllSoundRecordings: Bool
    
    //temp storage
    var currentSoundBuffers:[AVAudioPCMBuffer]
    var soundClipDuration:Double
    var numBufferPerClip:Int
    
    //audio graph params
    var audioEngine:AVAudioEngine = AVAudioEngine()
    var audioSession = AVAudioSession.sharedInstance()
    var inputNode:AVAudioInputNode//microphone node
    var filter:AVAudioUnitEQ//lowpass filter
    
    //not used-> maybe use to filter out high noise for ML algorithm
    var lowPassFreq:Int
    
    //microphone harware params
    var samplingRate:Int //hz
    
    // bell detection alogrithm params
    var slopeWidth:Int //hz
    var targetFrequncy:Int //hz
    var targetFrequncyThreshold:Int //hz
    var targetSlope:Float
    
    //location manager
    let locationManager = LocationManager.sharedLocationManager
    
    //queue to control concurrency problems
    let soundQueue:DispatchQueue = DispatchQueue(label: "com.example.audiofftqueue")

    init(samplingRate:Int,
         soundClipDuration:Double,
         targetFrequncy:Int,
         targetFrequncyThreshold:Int,
         bufferLength:Int,
         lowPassFreq:Int,
         grabAllSoundRecordings:Int,
         slopeWidth:Int,
         targetSlope: Float) {
        
        self.samplingRate = samplingRate
        self.targetFrequncy = targetFrequncy
        self.targetFrequncyThreshold = targetFrequncyThreshold
        self.slopeWidth = slopeWidth
        self.inputNode = audioEngine.inputNode!
        self.filter = AVAudioUnitEQ(numberOfBands:1)
        self.lowPassFreq = lowPassFreq
        self.targetSlope = targetSlope
        
        self.n = NSInteger(bufferLength)
        self.n2 = vDSP_Length(bufferLength/2)
        self.log_n = vDSP_Length(log2(Float(bufferLength)))
        self.fftSetup = nil
        self.grabAllSoundRecordings = Bool(grabAllSoundRecordings as NSNumber)
        
        self.soundClipDuration = soundClipDuration
        self.currentSoundBuffers = []
        self.numBufferPerClip = Int(soundClipDuration*Double(samplingRate)/Double(bufferLength))
        
    }
    
    /**
     initialize audio via audio session and setting up audio graph pipline
     */
    public func initializeAudio() {
        print("initializing listener with folllowing parameters...")
        printParams()
        //audio session setup (lower level mic config)
          do {
                try audioSession.setActive(true)
                try audioSession.setCategory(AVAudioSessionCategoryRecord)
                try audioSession.setPreferredSampleRate(Double(self.samplingRate))
                try audioSession.setPreferredInputNumberOfChannels(1)
                try audioSession.setMode(AVAudioSessionModeMeasurement)
            }
            catch {
                //cancel recording if any problems
                print("something went wrong with audio setup")
                return
            }
        
            //higher level audio setup - pipeline
            self.setupFilter()
            self.audioEngine.attach(self.filter)
            self.audioEngine.connect(inputNode, to:self.filter , format: self.inputNode.inputFormat(forBus: 0))
        
            //TODO: keep longer buffer, cut out needed buffer based on time stamp
        
            //audio callback for FFT
            self.filter.installTap(onBus: 0, bufferSize: AVAudioFrameCount(self.n), format: self.filter.inputFormat(forBus: 0)) {
                    (buffer: AVAudioPCMBuffer!, time: AVAudioTime!) -> Void in
                    if(self.currentSoundBuffers.count >= self.numBufferPerClip && (self.grabAllSoundRecordings || self.detectBell(buffer: buffer))){
                        
                            //user feedback for bell
                            AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
                            //callback for UI
                            DispatchQueue.main.async() {
                                self.delegate?.ringDetected()
                            }
                  
                            //get enviornment info
                            let lat:Double = self.locationManager.getLocation().coordinate.latitude
                            let long:Double = self.locationManager.getLocation().coordinate.latitude
                            let curTime:String = self.locationManager.getCurrentTime()
                            let epoch:Int = self.locationManager.getEpoch()
                        
                            //create wav file
                            let base:String = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
                            //TODO: maybe send raw data to server, quicker, but more work on server side to package in file - > would have to be packaged through backend?
                            let filePath:String = base + "/Audio_Sample_" + curTime + "_lat=\(lat)_long=\(long).wav"
                            let fileURL:URL = URL.init(fileURLWithPath: filePath)
                        
                            self.soundQueue.sync {
                                self.writeToFile(fileURL: fileURL)
                            }
                            //dealloc file so saved to mem before packagingand sending
                            //send files to server
                            DispatchQueue.global(qos: .background).async {
                                NetworkManager.sendToServer(path:fileURL)
                                NetworkManager.sendDing(lat:Float(lat), lng:Float(long), timeStamp:epoch, value:0)
                            }
                    }
                }
            
            //audio callback for populating buffer
            self.inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(self.n), format: self.inputNode.inputFormat(forBus: 0)){
                (buffer: AVAudioPCMBuffer!, time: AVAudioTime!) -> Void in
                    self.soundQueue.sync {
                        self.bufferSound(buffer: buffer)
                }
            }
        }
    
    /**
        keeping running list of sound buffers in time domain    
     */
    func bufferSound(buffer: AVAudioPCMBuffer) {
        if(self.currentSoundBuffers.count < self.numBufferPerClip){
            self.currentSoundBuffers.append(buffer)
        }
        else {
            self.currentSoundBuffers.remove(at: 0)
            self.currentSoundBuffers.append(buffer)
        }
    }
    
    /**
     push buffer to file and clear buffer
     */
    func writeToFile(fileURL: URL) {
        
        //merge buffers into files
        do {
            let file:AVAudioFile = try AVAudioFile(forWriting:fileURL, settings: self.audioFileSettings())
            for buffer in self.currentSoundBuffers {
                try file.write(from: buffer)
            }
            //flush sound cache
            self.currentSoundBuffers.removeAll()
        }
        catch {
            print("could not write file")
        }
    }
    
    /**
     return settings for writing audio files
            if running with simulator on computer, mic chnannels need to be set to 2
     */
    private func audioFileSettings() -> Dictionary<String, Any> {
        return [
            AVSampleRateKey : samplingRate,
            AVNumberOfChannelsKey : 1,
            AVFormatIDKey : kAudioFormatLinearPCM
        ]
    }
    
    /**
     pre fft filter
     */
    private func setupFilter(){
         filter.bands[0].filterType = AVAudioUnitEQFilterType.bandPass
         filter.bands[0].frequency = Float(targetFrequncy);
         filter.bands[0].bandwidth = 0.1
    }
    
    /**
     start pulling audio through render thread    
     */
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
    
    /**
     stop pulling audio through render thread
    */
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
    
    
    /**
    are we returning data
     */
    public func isListening() -> Bool {
        return self.audioEngine.isRunning
    }
    
    /**
     compute fft and evaluate frequency neighborhood to detect bell peaks
     */
    private func detectBell(buffer:AVAudioPCMBuffer) -> Bool {
        // create vectors
        var tempReal : [Float] = [Float](repeating: 0.0, count: n)
        var tempImag : [Float] = [Float](repeating: 0.0, count: n)
        var tempSplitComplex : DSPSplitComplex = DSPSplitComplex(realp: &tempReal, imagp: &tempImag)
        var splitComplex : DSPSplitComplex = DSPSplitComplex(realp: buffer.floatChannelData![0], imagp: &tempImag)
        
        // FFT
        vDSP_fft_zript(fftSetup!, &splitComplex, vDSP_Stride(1), &tempSplitComplex, log_n, FFTDirection(FFT_FORWARD));
        
        //package results
        var fftMagnitudes = [Float](repeating:0.0, count:Int(n))
        vDSP_zvmags(&splitComplex, 1, &fftMagnitudes, 1, vDSP_Length(n));
        var roots:[Float] = fftMagnitudes.map {sqrtf($0)}
        
        let lowerBound:Int = self.frequencyToIndex(N: n, freq: targetFrequncy-targetFrequncyThreshold)
        let upperBound:Int = self.frequencyToIndex(N: n, freq: targetFrequncy+targetFrequncyThreshold)
        let crest:Int = self.geMaxIndex(array: &roots, lowerBound:lowerBound, upperBound:upperBound)

        print(indexToFrequency(N:n,index:self.geMaxIndex(array: &roots, lowerBound:0, upperBound:roots.count)))
        print(indexToFrequency(N: n, index: crest))
        let indexWidthForSlope = self.frequencyToIndex(N: n, freq: slopeWidth)
        
        let frontSlope:Float = calculateSlope(index: crest, width: indexWidthForSlope, array: &roots)
        let backSlope:Float = calculateSlope(index: crest, width: -indexWidthForSlope, array: &roots)
        return true
    }
    
    
    private func indexToFrequency(N:Int, index:Int) -> Double {
        return Double(index)*Double(self.samplingRate)/Double(N)
    }
    
    private func frequencyToIndex(N:Int, freq:Int) -> Int {
        return Int(Double(freq)*Double(N)/Double(self.samplingRate))
    }
    
    private func calculateSlope(index:Int, width:Int, array: inout [Float]) -> Float {
        //average 3 points as naive way of damping noise
        return (array[index]-(array[min(max(0,index+width-3),array.count-1)..<max(0,min(array.count-1,(index+width+4)))].reduce(0,+)))/Float(width)
    }
    
    private func geMaxIndex(array: inout [Float], lowerBound:Int, upperBound:Int) -> Int {
        var index:Int = 0
        var maxValue:Float = 0
        for i in max(lowerBound,0)..<min(upperBound,array.count-1) {
            if array[i] > maxValue {
                maxValue = array[i]
                index = i
            }
        }
        return index
    }
    
    //debug - TODO: make toString method
    func printParams() {
        print("target frequency: " + String(targetFrequncy))
        print("target slope: " + String(targetSlope))
        print("slope Width: " + String(slopeWidth))
        print("target frequency threshold: " + String(targetFrequncyThreshold))
        print("low pass frequency: " + String(lowPassFreq))
        print("buffer length: " + String(n))
        print("sound Clip Duration: " + String(soundClipDuration))
        print("mic sampling rate: " + String(samplingRate))
        print("is fft filter turned on?: " + (grabAllSoundRecordings ? "NO" : "YES"))


        




    }
    
}
