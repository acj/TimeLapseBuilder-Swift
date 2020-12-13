//
//  TimeLapseBuilder.swift
//
//  Created by Adam Jensen on 11/18/16.

import AVFoundation
import UIKit

let kErrorDomain = "TimeLapseBuilder"
let kFailedToStartAssetWriterError = 0
let kFailedToAppendPixelBufferError = 1

public protocol TimelapseBuilderDelegate: class {
    func timeLapseBuilder(_ timelapseBuilder: TimeLapseBuilder, didMakeProgress progress: Progress)
    func timeLapseBuilder(_ timelapseBuilder: TimeLapseBuilder, didFinishWithURL url: URL)
    func timelapseBuilder(_ timelapseBuilder: TimeLapseBuilder, didFailWithError error: Error)
}

public class TimeLapseBuilder {
    public var delegate: TimelapseBuilderDelegate
    
    var videoWriter: AVAssetWriter?
    
    init(delegate: TimelapseBuilderDelegate) {
        self.delegate = delegate
    }
    
    func build(with assetPaths: [String], type: AVFileType, toOutputPath: String) {
        let inputSize = CGSize(width: 4000, height: 3000)
        let outputSize = CGSize(width: 1280, height: 720)
        var error: NSError?
        
        let videoOutputURL = URL(fileURLWithPath: toOutputPath)
        
        do {
            try FileManager.default.removeItem(at: videoOutputURL)
        } catch {}
        
        do {
            try videoWriter = AVAssetWriter(outputURL: videoOutputURL, fileType: type)
        } catch let writerError as NSError {
            error = writerError
            videoWriter = nil
        }
        
        if let videoWriter = videoWriter {
            let videoSettings: [String : AnyObject] = [
                AVVideoCodecKey  : AVVideoCodecType.h264 as AnyObject,
                AVVideoWidthKey  : outputSize.width as AnyObject,
                AVVideoHeightKey : outputSize.height as AnyObject,
                //        AVVideoCompressionPropertiesKey : [
                //          AVVideoAverageBitRateKey : NSInteger(1000000),
                //          AVVideoMaxKeyFrameIntervalKey : NSInteger(16),
                //          AVVideoProfileLevelKey : AVVideoProfileLevelH264BaselineAutoLevel
                //        ]
            ]
            
            let videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
            
            let sourceBufferAttributes = [
                (kCVPixelBufferPixelFormatTypeKey as String): Int(kCVPixelFormatType_32ARGB),
                (kCVPixelBufferWidthKey as String): Float(inputSize.width),
                (kCVPixelBufferHeightKey as String): Float(inputSize.height)] as [String : Any]
            
            let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: videoWriterInput,
                sourcePixelBufferAttributes: sourceBufferAttributes
            )
            
            assert(videoWriter.canAdd(videoWriterInput))
            videoWriter.add(videoWriterInput)
            
            if videoWriter.startWriting() {
                videoWriter.startSession(atSourceTime: CMTime.zero)
                assert(pixelBufferAdaptor.pixelBufferPool != nil)
                
                let media_queue = DispatchQueue(label: "mediaInputQueue")
                
                videoWriterInput.requestMediaDataWhenReady(on: media_queue) {
                    let fps: Int32 = 30
                    let currentProgress = Progress(totalUnitCount: Int64(assetPaths.count))
                    
                    var frameCount: Int64 = 0
                    var remainingPhotoURLs = [String](assetPaths)
                    
                    while !remainingPhotoURLs.isEmpty {
                        while videoWriterInput.isReadyForMoreMediaData {
                            if remainingPhotoURLs.isEmpty {
                                break
                            }
                            let nextPhotoURL = remainingPhotoURLs.remove(at: 0)
                            let presentationTime = CMTimeMake(value: frameCount, timescale: fps)
                            
                            if !self.appendPixelBufferForImageAtURL(nextPhotoURL, pixelBufferAdaptor: pixelBufferAdaptor, presentationTime: presentationTime) {
                                error = NSError(
                                    domain: kErrorDomain,
                                    code: kFailedToAppendPixelBufferError,
                                    userInfo: ["description": "AVAssetWriterInputPixelBufferAdapter failed to append pixel buffer"]
                                )
                                
                                break
                            }
                            
                            frameCount += 1
                            
                            currentProgress.completedUnitCount = frameCount
                            self.delegate.timeLapseBuilder(self, didMakeProgress: currentProgress)
                        }
                    }
                    
                    videoWriterInput.markAsFinished()
                    videoWriter.finishWriting {
                        if let error = error {
                            self.delegate.timelapseBuilder(self, didFailWithError: error)
                        } else {
                            self.delegate.timeLapseBuilder(self, didFinishWithURL: videoOutputURL)
                        }
                        
                        self.videoWriter = nil
                    }
                }
            } else {
                error = NSError(
                    domain: kErrorDomain,
                    code: kFailedToStartAssetWriterError,
                    userInfo: ["description": "AVAssetWriter failed to start writing"]
                )
            }
        }
        
        if let error = error {
            self.delegate.timelapseBuilder(self, didFailWithError: error)
        }
    }
    
    func appendPixelBufferForImageAtURL(_ url: String, pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor, presentationTime: CMTime) -> Bool {
        var appendSucceeded = false
        
        autoreleasepool {
            if let url = URL(string: url),
                let imageData = try? Data(contentsOf: url),
                let image = UIImage(data: imageData),
                let pixelBufferPool = pixelBufferAdaptor.pixelBufferPool {
                let pixelBufferPointer = UnsafeMutablePointer<CVPixelBuffer?>.allocate(capacity: 1)
                let status: CVReturn = CVPixelBufferPoolCreatePixelBuffer(
                    kCFAllocatorDefault,
                    pixelBufferPool,
                    pixelBufferPointer
                )
                
                if let pixelBuffer = pixelBufferPointer.pointee, status == 0 {
                    fillPixelBufferFromImage(image, pixelBuffer: pixelBuffer)
                    
                    appendSucceeded = pixelBufferAdaptor.append(
                        pixelBuffer,
                        withPresentationTime: presentationTime
                    )
                    
                    pixelBufferPointer.deinitialize(count: 1)
                } else {
                    NSLog("error: Failed to allocate pixel buffer from pool")
                }
                
                pixelBufferPointer.deallocate()
            }
        }
        
        return appendSucceeded
    }
    
    func fillPixelBufferFromImage(_ image: UIImage, pixelBuffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: pixelData,
            width: Int(image.size.width),
            height: Int(image.size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        )
        
        context?.draw(image.cgImage!, in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    }
}
