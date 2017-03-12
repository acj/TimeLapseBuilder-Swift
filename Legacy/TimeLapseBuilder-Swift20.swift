//
//  TimeLapseBuilder.swift
//
//  Created by Adam Jensen on 5/10/15.
//
//  NOTE: This implementation is written in Swift 2.0.

import AVFoundation
import UIKit

let kErrorDomain = "TimeLapseBuilder"
let kFailedToStartAssetWriterError = 0
let kFailedToAppendPixelBufferError = 1

class TimeLapseBuilder: NSObject {
  let photoURLs: [String]
  var videoWriter: AVAssetWriter?
  
  init(photoURLs: [String]) {
    self.photoURLs = photoURLs
  }
  
  func build(progress: (NSProgress -> Void), success: (NSURL -> Void), failure: (NSError -> Void)) {
    let inputSize = CGSize(width: 4000, height: 3000)
    let outputSize = CGSize(width: 1280, height: 720)
    var error: NSError?
    
    let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as NSString
    let videoOutputURL = NSURL(fileURLWithPath: documentsPath.stringByAppendingPathComponent("AssembledVideo.mov"))
    
    do {
      try NSFileManager.defaultManager().removeItemAtURL(videoOutputURL)
    } catch {}
    
    do {
      try videoWriter = AVAssetWriter(URL: videoOutputURL, fileType: AVFileTypeQuickTimeMovie)
    } catch let writerError as NSError {
      error = writerError
      videoWriter = nil
    }
    
    if let videoWriter = videoWriter {
      let videoSettings: [String : AnyObject] = [
        AVVideoCodecKey  : AVVideoCodecH264,
        AVVideoWidthKey  : outputSize.width,
        AVVideoHeightKey : outputSize.height,
//        AVVideoCompressionPropertiesKey : [
//          AVVideoAverageBitRateKey : NSInteger(1000000),
//          AVVideoMaxKeyFrameIntervalKey : NSInteger(16),
//          AVVideoProfileLevelKey : AVVideoProfileLevelH264BaselineAutoLevel
//        ]
      ]
      
      let videoWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoSettings)

      let sourceBufferAttributes = [String : AnyObject](dictionaryLiteral:
        (kCVPixelBufferPixelFormatTypeKey as String, Int(kCVPixelFormatType_32ARGB)),
        (kCVPixelBufferWidthKey as String, Float(inputSize.width)),
        (kCVPixelBufferHeightKey as String, Float(inputSize.height))
      )
      
      let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
        assetWriterInput: videoWriterInput,
        sourcePixelBufferAttributes: sourceBufferAttributes
      )
      
      assert(videoWriter.canAddInput(videoWriterInput))
      videoWriter.addInput(videoWriterInput)
      
      if videoWriter.startWriting() {
        videoWriter.startSessionAtSourceTime(kCMTimeZero)
        assert(pixelBufferAdaptor.pixelBufferPool != nil)
        
        let media_queue = dispatch_queue_create("mediaInputQueue", nil)
        
        videoWriterInput.requestMediaDataWhenReadyOnQueue(media_queue, usingBlock: { () -> Void in
          let fps: Int32 = 30
          let frameDuration = CMTimeMake(1, fps)
          let currentProgress = NSProgress(totalUnitCount: Int64(self.photoURLs.count))
          
          var frameCount: Int64 = 0
          var remainingPhotoURLs = [String](self.photoURLs)
          
          while (videoWriterInput.readyForMoreMediaData && !remainingPhotoURLs.isEmpty) {
            let nextPhotoURL = remainingPhotoURLs.removeAtIndex(0)
            let lastFrameTime = CMTimeMake(frameCount, fps)
            let presentationTime = frameCount == 0 ? lastFrameTime : CMTimeAdd(lastFrameTime, frameDuration)
            
            
            if !self.appendPixelBufferForImageAtURL(nextPhotoURL, pixelBufferAdaptor: pixelBufferAdaptor, presentationTime: presentationTime) {
              error = NSError(
                domain: kErrorDomain,
                code: kFailedToAppendPixelBufferError,
                userInfo: [
                  "description": "AVAssetWriterInputPixelBufferAdapter failed to append pixel buffer",
                  "rawError": videoWriter.error ?? "(none)"
                ]
              )
              
              break
            }
            
            frameCount++
            
            currentProgress.completedUnitCount = frameCount
            progress(currentProgress)
          }
          
          videoWriterInput.markAsFinished()
          videoWriter.finishWritingWithCompletionHandler { () -> Void in
            if error == nil {
              success(videoOutputURL)
            }
            
            self.videoWriter = nil
          }
        })
      } else {
        error = NSError(
          domain: kErrorDomain,
          code: kFailedToStartAssetWriterError,
          userInfo: ["description": "AVAssetWriter failed to start writing"]
        )
      }
    }
    
    if let error = error {
      failure(error)
    }
  }
  
  func appendPixelBufferForImageAtURL(url: String, pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor, presentationTime: CMTime) -> Bool {
    var appendSucceeded = false
    
    autoreleasepool {
      if let url = NSURL(string: url),
        let imageData = NSData(contentsOfURL: url),
        let image = UIImage(data: imageData),
        let pixelBufferPool = pixelBufferAdaptor.pixelBufferPool {
          let pixelBufferPointer = UnsafeMutablePointer<CVPixelBuffer?>.alloc(1)
          let status: CVReturn = CVPixelBufferPoolCreatePixelBuffer(
            kCFAllocatorDefault,
            pixelBufferPool,
            pixelBufferPointer
          )
          
          if let pixelBuffer = pixelBufferPointer.memory where status == 0 {
            fillPixelBufferFromImage(image, pixelBuffer: pixelBuffer)
            
            appendSucceeded = pixelBufferAdaptor.appendPixelBuffer(
              pixelBuffer,
              withPresentationTime: presentationTime
            )
            
            pixelBufferPointer.destroy()
          } else {
            NSLog("error: Failed to allocate pixel buffer from pool")
          }
          
          pixelBufferPointer.dealloc(1)
      }
    }
    
    return appendSucceeded
  }
  
  func fillPixelBufferFromImage(image: UIImage, pixelBuffer: CVPixelBufferRef) {
    CVPixelBufferLockBaseAddress(pixelBuffer, 0)
    
    let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)
    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    
    let context = CGBitmapContextCreate(
      pixelData,
      Int(image.size.width),
      Int(image.size.height),
      8,
      CVPixelBufferGetBytesPerRow(pixelBuffer),
      rgbColorSpace,
      CGImageAlphaInfo.PremultipliedFirst.rawValue
    )
    
    CGContextDrawImage(context, CGRectMake(0, 0, image.size.width, image.size.height), image.CGImage)
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0)
  }
}