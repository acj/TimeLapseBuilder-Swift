//
//  TimeLapseBuilder.swift
//
//  Created by Adam Jensen on 5/10/15.
//
//  NOTE: This is the original Swift 1.2 implementation.

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
    
    let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as! NSString
    let videoOutputURL = NSURL(fileURLWithPath: documentsPath.stringByAppendingPathComponent("AssembledVideo.mov"))!
    
    NSFileManager.defaultManager().removeItemAtURL(videoOutputURL, error: nil)
    
    videoWriter = AVAssetWriter(URL: videoOutputURL, fileType: AVFileTypeQuickTimeMovie, error: &error)
    
    if let videoWriter = videoWriter {
      let videoSettings: [NSObject : AnyObject] = [
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

      let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
        assetWriterInput: videoWriterInput,
        sourcePixelBufferAttributes: [
          kCVPixelBufferPixelFormatTypeKey : kCVPixelFormatType_32ARGB,
          kCVPixelBufferWidthKey : inputSize.width,
          kCVPixelBufferHeightKey : inputSize.height,
        ]
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
    var appendSucceeded = true
    
    autoreleasepool {
      if let url = NSURL(string: url),
        let imageData = NSData(contentsOfURL: url),
        let image = UIImage(data: imageData) {
          var pixelBuffer: Unmanaged<CVPixelBuffer>?
          let status: CVReturn = CVPixelBufferPoolCreatePixelBuffer(
            kCFAllocatorDefault,
            pixelBufferAdaptor.pixelBufferPool,
            &pixelBuffer
          )
          
          if let pixelBuffer = pixelBuffer where status == 0 {
            let managedPixelBuffer = pixelBuffer.takeRetainedValue()
            
            fillPixelBufferFromImage(image, pixelBuffer: managedPixelBuffer)
            
            appendSucceeded = pixelBufferAdaptor.appendPixelBuffer(
              managedPixelBuffer,
              withPresentationTime: presentationTime
            )
          } else {
            NSLog("error: Failed to allocate pixel buffer from pool")
          }
      }
    }
    
    return appendSucceeded
  }
  
  func fillPixelBufferFromImage(image: UIImage, pixelBuffer: CVPixelBufferRef) {
    let imageData = CGDataProviderCopyData(CGImageGetDataProvider(image.CGImage))
    let lockStatus = CVPixelBufferLockBaseAddress(pixelBuffer, 0)
    
    let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.PremultipliedFirst.rawValue)
    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    
    let context = CGBitmapContextCreate(
      pixelData,
      Int(image.size.width),
      Int(image.size.height),
      8,
      Int(4 * image.size.width),
      rgbColorSpace,
      bitmapInfo
    )
    
    CGContextDrawImage(context, CGRectMake(0, 0, image.size.width, image.size.height), image.CGImage)
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0)
  }
}