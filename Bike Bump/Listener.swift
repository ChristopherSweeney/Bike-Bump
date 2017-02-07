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
    var lowPassFreq:Int
    
    //debug
    var player:AVAudioPlayerNode
    
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
         lowPassFreq:Int,
         grabAllSoundRecordings:Int) {
        
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
        self.grabAllSoundRecordings = Bool(grabAllSoundRecordings as NSNumber)
        
        self.soundClipDuration = soundClipDuration
        self.currentSoundBuffers = []
        self.numBufferPerClip = Int(soundClipDuration*Double(samplingRate)/Double(bufferLength))
        
        //debug
        self.player = AVAudioPlayerNode()
    }
    
    public func initializeAudio() {
          do {
                try audioSession.setActive(true)
                try audioSession.setCategory(AVAudioSessionCategoryRecord)
                try audioSession.setPreferredSampleRate(Double(self.samplingRate))
                try audioSession.setPreferredInputNumberOfChannels(1)
                try audioSession.setMode(AVAudioSessionModeMeasurement)
            }
            //cancel recording if any problems
            catch {
                print("something went wrong")
                return
            }
        
            self.setupFilter()
            self.audioEngine.attach(self.filter)


            //debug
            //setupPlayer()
        
            //keep track of how to control audio processing format -changing sample rate
            self.audioEngine.connect(inputNode, to:self.filter , format: self.inputNode.inputFormat(forBus: 0))
        
        
        
        
            //process audio - keep longer buffer, cut out needed buffer based on time stamp
            self.filter.installTap(onBus: 0, bufferSize: AVAudioFrameCount(self.n), format: self.filter.inputFormat(forBus: 0)) {
                    (buffer: AVAudioPCMBuffer!, time: AVAudioTime!) -> Void in
                    if(self.currentSoundBuffers.count >= self.numBufferPerClip && (self.grabAllSoundRecordings || self.detectBell(buffer: buffer))){
                            //callback for UI
                            DispatchQueue.main.async() {
                                self.delegate?.ringDetected()
                            }
                  
                            //get enviornment info
                            let lat:Double = LocationManager.sharedLocationManager.getLocation().coordinate.latitude
                            let long:Double = LocationManager.sharedLocationManager.getLocation().coordinate.latitude
                            let curTime:String = LocationManager.sharedLocationManager.getCurrentTime()
                            let epoch:Int = LocationManager.sharedLocationManager.getEpoch()
                            //create wav file
                            let base:String = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
                            //maybe send raw data to server, quicker, but more work on server side to package in file - > would have to be packaged through backend?
                            let filePath:String = base + "/Audio_Sample_" + curTime + "_lat=\(lat)_long=\(long).wav"
                            let fileURL:URL = URL.init(fileURLWithPath: filePath)

                            self.soundQueue.sync {
                                self.audioProcessingBlock(fileURL: fileURL)
                            }
                            //dealloc file so saved to mem before packagingand sending
                            //send files to server
                            DispatchQueue.global(qos: .background).async {
                                NetworkManager.sendToServer(path:fileURL)
                                NetworkManager.sendDing(lat:Float(lat), lng:Float(long), timeStamp:epoch, value:0)
                            }
                    }
                }
            
            //populated buffer with sound
            self.inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(self.n), format: self.inputNode.inputFormat(forBus: 0)){
                (buffer: AVAudioPCMBuffer!, time: AVAudioTime!) -> Void in
                    self.soundQueue.sync {
                        self.bufferSound(buffer: buffer)
                }
            }

        }
    
    func bufferSound(buffer: AVAudioPCMBuffer) {
        if(self.currentSoundBuffers.count < self.numBufferPerClip){
            self.currentSoundBuffers.append(buffer)
        }
        else {
            self.currentSoundBuffers.remove(at: 0)
            self.currentSoundBuffers.append(buffer)
        }
    }
    
    func audioProcessingBlock(fileURL: URL) {
        
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

    
    
    private func setupFilter(){
         filter.bands[0].filterType = AVAudioUnitEQFilterType.bandPass
         filter.bands[0].frequency = Float(targetFrequncy);
         filter.bands[0].bandwidth = 0.1
    }

    public func startListening() {
        //offload initialization so you can start and stop
        audioSession.requestRecordPermission({(permissionGranted: Bool) -> Void in
            if permissionGranted {
                do {
                    try self.audioEngine.start()
                    self.fftSetup = vDSP_create_fftsetup(self.log_n, FFTRadix(kFFTRadix2))!
                    //self.player.play()
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
        
        let lowerBound:Int = Int(Int(self.frequencyToIndex(N: n, freq: targetFrequncy-targetFrequncyThreshold)))
        let upperBound:Int = Int(Int(self.frequencyToIndex(N: n, freq: targetFrequncy+targetFrequncyThreshold)))

        //speed up
        let crest:Int =  roots[max(lowerBound,0)..<min(upperBound,roots.count)].index(of: roots[lowerBound..<upperBound].max()!)!
    
        
        let front:Float = calculateSlope(index: crest, width: 100, array: &roots)
        let back:Float = calculateSlope(index: crest, width: -100, array: &roots)
        
        let maxIndex:Int = roots.index(of: roots.max()!)!
        if indexToFrequency(N: n, index: maxIndex)>2500 && indexToFrequency(N: n, index: maxIndex) < 3500{
            print("here")
            print(front)
            print(back)
            print(crest)
            print(upperBound)
            print(lowerBound)
            print(maxIndex)
        }
       
        return false
    }
    
    private func audioFileSettings() -> Dictionary<String, Any> {
        return [
            AVSampleRateKey : samplingRate,
            AVNumberOfChannelsKey : 1,
            AVFormatIDKey : kAudioFormatLinearPCM
        ]
    }
    
    private func indexToFrequency(N:Int, index:Int) -> Double {
        return Double(index)*Double(self.samplingRate)/Double(N)
    }
    
    private func frequencyToIndex(N:Int, freq:Int) -> Double {
        return Double(freq)*Double(N)/Double(self.samplingRate)
    }
    
    private func calculateSlope(index:Int, width:Int, array: inout [Float]) -> Float {
        //average 3 points as jank way of damping noise
        return (array[index]-(array[min(max(0,index+width-3),array.count-1)..<max(0,min(array.count-1,(index+width+4)))].reduce(0,+)))/Float(width)
    }
    
    
    
    
    
    
    
    
    
    
    
    //debug
    private func setupPlayer() {
        audioEngine.attach(player)
        var files:[AVAudioFile] = []
        do {
            files = try FileManager.default.contentsOfDirectory(at: Bundle.main.bundleURL
                , includingPropertiesForKeys: nil, options: []).filter() {$0.absoluteString.range(of:"Ding") != nil}.map() { try AVAudioFile.init(forReading: $0)}
        }
        catch{
            print("No")
        }
       print(files)
        for file in files {
            player.scheduleFile(file, at: nil, completionHandler: {print("played" + file.url.absoluteString)})
        }
         self.audioEngine.connect(player, to: self.filter, format:files[0].fileFormat)
    }
    
    
}
