//
//  TimeLapseBuilder.swift
//
//  Created by Adam Jensen on 11/18/16.

import AVFoundation

#if os(macOS)
import Cocoa
typealias UIImage = NSImage
#else
import UIKit
#endif

let kErrorDomain = "TimeLapseBuilder"
let kFailedToStartAssetWriterError = 0
let kFailedToAppendPixelBufferError = 1
let kFailedToDetermineAssetDimensions = 2
let kFailedToProcessAssetPath = 3

public protocol TimelapseBuilderDelegate: AnyObject {
    func timeLapseBuilder(_ timelapseBuilder: TimeLapseBuilder, didMakeProgress progress: Progress)
    func timeLapseBuilder(_ timelapseBuilder: TimeLapseBuilder, didFinishWithURL url: URL)
    func timeLapseBuilder(_ timelapseBuilder: TimeLapseBuilder, didFailWithError error: Error)
}

public class TimeLapseBuilder {
    public var delegate: TimelapseBuilderDelegate
    
    var videoWriter: AVAssetWriter?
    
    public init(delegate: TimelapseBuilderDelegate) {
        self.delegate = delegate
    }
    
    public func build(with assetPaths: [String], atFrameRate framesPerSecond: Int32, type: AVFileType, toOutputPath: String) {
        // Output video dimensions are inferred from the first image asset
        guard
            let firstAssetPath = assetPaths.first,
            let firstAssetURL = URL(string: firstAssetPath),
            let canvasSize = dimensionsOfImage(url: firstAssetURL),
            canvasSize != CGSize.zero
        else {
            let error = NSError(
                domain: kErrorDomain,
                code: kFailedToDetermineAssetDimensions,
                userInfo: ["description": "TimelapseBuilder failed to determine the dimensions of the first asset. Does the URL or file path exist?"]
            )
            self.delegate.timeLapseBuilder(self, didFailWithError: error)
            return
        }
        
        
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
                AVVideoWidthKey  : canvasSize.width as AnyObject,
                AVVideoHeightKey : canvasSize.height as AnyObject,
                //        AVVideoCompressionPropertiesKey : [
                //          AVVideoAverageBitRateKey : NSInteger(1000000),
                //          AVVideoMaxKeyFrameIntervalKey : NSInteger(16),
                //          AVVideoProfileLevelKey : AVVideoProfileLevelH264BaselineAutoLevel
                //        ]
            ]
            
            let videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
            
            let sourceBufferAttributes = [
                (kCVPixelBufferPixelFormatTypeKey as String): Int(kCVPixelFormatType_32ARGB),
                (kCVPixelBufferWidthKey as String): Float(canvasSize.width),
                (kCVPixelBufferHeightKey as String): Float(canvasSize.height)] as [String : Any]
            
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
                    let currentProgress = Progress(totalUnitCount: Int64(assetPaths.count))
                    
                    var frameCount: Int64 = 0
                    var remainingAssetPaths = [String](assetPaths)
                    
                    while !remainingAssetPaths.isEmpty {
                        while videoWriterInput.isReadyForMoreMediaData {
                            if remainingAssetPaths.isEmpty {
                                break
                            }
                            let nextAssetPath = remainingAssetPaths.remove(at: 0)
                            guard let nextAssetURL = URL(string: nextAssetPath) else {
                                error = NSError(
                                    domain: kErrorDomain,
                                    code: kFailedToProcessAssetPath,
                                    userInfo: ["description": "TimelapseBuilder failed to process the asset path. Is it a valid URL or file path?"]
                                )
                                break
                            }
                            let presentationTime = CMTimeMake(value: frameCount, timescale: framesPerSecond)
                            
                            if !self.appendPixelBufferForImageAtURL(nextAssetURL, pixelBufferAdaptor: pixelBufferAdaptor, presentationTime: presentationTime) {
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
                            self.delegate.timeLapseBuilder(self, didFailWithError: error)
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
            self.delegate.timeLapseBuilder(self, didFailWithError: error)
        }
    }
    
    func dimensionsOfImage(url: URL) -> CGSize? {
        guard let imageData = try? Data(contentsOf: url),
              let image = UIImage(data: imageData) else {
            return nil
        }
        
        return image.size
    }
    
    func appendPixelBufferForImageAtURL(_ url: URL, pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor, presentationTime: CMTime) -> Bool {
        var appendSucceeded = false
        
        autoreleasepool {
            if let imageData = try? Data(contentsOf: url),
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

#if os(macOS)
extension NSImage {
    var cgImage: CGImage? {
        var proposedRect = CGRect(origin: .zero, size: size)

        return cgImage(forProposedRect: &proposedRect,
                       context: nil,
                       hints: nil)
    }
}
#endif
