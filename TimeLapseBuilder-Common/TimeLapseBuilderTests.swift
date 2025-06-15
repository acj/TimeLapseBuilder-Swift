//
//  TimeLapseBuilderTests.swift
//  TimeLapseBuilderTests
//
//  Created by Adam Jensen on 11/18/16.
//
//

import AVKit
import XCTest
@testable import TimeLapseBuilder

class TimeLapseBuilderTests: XCTestCase {
    func testWhenGivenASeriesOfImages_producesAnOutputFile() {
        let expectation = self.expectation(description: "Build timelapse")
        let testDelegate = TestDelegate(progress: { (progress: Progress) in
            // Ignore
        }, finished: { url in
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.relativePath))
            expectation.fulfill()
        }, failed: { error in
            XCTFail("unexpected failure: \(error)")
        })
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
        let outputPath = documentsPath.appendingPathComponent("AssembledVideo.mov")
        
        let timelapseBuilder = TimeLapseBuilder(delegate: testDelegate)
        let assets = assetList(count: 3)
        
        timelapseBuilder.build(with: assets, atFrameRate: 30, type: .mov, toOutputPath: outputPath)
        
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    func testWhenGivenASeriesOfImages_reportsProgressCorrectly() {
        let expectation = self.expectation(description: "Build timelapse")
        var mostRecentCompletedUnitCount: Int64 = 0
        let testDelegate = TestDelegate(progress: { (progress: Progress) in
            XCTAssertEqual(progress.completedUnitCount, mostRecentCompletedUnitCount + 1)
            mostRecentCompletedUnitCount += 1
            
            if progress.isFinished {
                expectation.fulfill()
            }
        }, finished: { url in
            // Ignore
        }, failed: { error in
            XCTFail("unexpected failure: \(error)")
        })
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
        let outputPath = documentsPath.appendingPathComponent("AssembledVideo.mov")
        
        let assets = assetList(count: 3)
        let timelapseBuilder = TimeLapseBuilder(delegate: testDelegate)
        timelapseBuilder.build(with: assets, atFrameRate: 30, type: .mov, toOutputPath: outputPath)
        
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    func testWhenGivenASeriesOfImages_producesVideoOfExpectedDuration() {
        let expectation = self.expectation(description: "Build timelapse")
        let testDelegate = TestDelegate(progress: { progress in
            // Ignore
        }, finished: { url in
            let asset = AVURLAsset(url: url)
            var frameCount = 0
            do {
                frameCount = try asset.getNumberOfFrames()
            } catch {
                XCTFail("failed to get frame count: \(error)")
            }
            
            XCTAssertEqual(asset.duration.seconds, 1.0, "Unexpected video duration")
            XCTAssertEqual(frameCount, 34, "Unexpected frame count")
            
            expectation.fulfill()
        }, failed: { error in
            XCTFail("unexpected failure: \(error)")
        })
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
        let outputPath = documentsPath.appendingPathComponent("AssembledVideo.mov")
        
        let assets = assetList(count: 30)
        let timelapseBuilder = TimeLapseBuilder(delegate: testDelegate)
        timelapseBuilder.build(with: assets, atFrameRate: 30, type: .mov, toOutputPath: outputPath)
        
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    func testWhenGivenAnInvalidFirstAssetPath_returnsAnError() {
        let expectation = self.expectation(description: "Build timelapse")
        let testDelegate = TestDelegate(progress: { progress in
            // Ignore
        }, finished: { url in
            XCTFail("Should have failed, but succeeded instead")
        }, failed: { error in
            expectation.fulfill()
        })
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
        let outputPath = documentsPath.appendingPathComponent("AssembledVideo.mov")
        
        let assets = ["file:///invalid/path"]
        let timelapseBuilder = TimeLapseBuilder(delegate: testDelegate)
        timelapseBuilder.build(with: assets, atFrameRate: 30, type: .mov, toOutputPath: outputPath)
        
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    func testWhenGivenAnInvalidSubsequentAssetPath_returnsAnError() {
        let expectation = self.expectation(description: "Build timelapse")
        let testDelegate = TestDelegate(progress: { progress in
            // Ignore
        }, finished: { url in
            XCTFail("Should have failed, but succeeded instead")
        }, failed: { error in
            expectation.fulfill()
        })
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
        let outputPath = documentsPath.appendingPathComponent("AssembledVideo.mov")
        
        var assets = assetList(count: 1)
        assets.append("file:///invalid/path")
        let timelapseBuilder = TimeLapseBuilder(delegate: testDelegate)
        timelapseBuilder.build(with: assets, atFrameRate: 30, type: .mov, toOutputPath: outputPath)
        
        waitForExpectations(timeout: 30, handler: nil)
    }
    
    private func assetList(count: Int) -> [String] {
        let assetType = "jpg"
        let bundle = Bundle(for: type(of: self))
        let urls = [
            bundle.url(forResource: "red", withExtension: assetType)!.absoluteString,
            bundle.url(forResource: "white", withExtension: assetType)!.absoluteString,
            bundle.url(forResource: "blue", withExtension: assetType)!.absoluteString,
        ]
        
        var assets = [String]()
        
        for i in 1...count {
            assets.append(urls[i % urls.count])
        }
        
        return assets
    }
}

extension AVURLAsset {
    func getNumberOfFrames() throws -> Int {
        let reader = try AVAssetReader(asset: self)
        let videoTrack = self.tracks(withMediaType: AVMediaType.video)[0]
        let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: nil)
        reader.add(readerOutput)
        reader.startReading()

        var frameCount = 0
        while true {
            guard
                readerOutput.copyNextSampleBuffer() != nil
            else {
                break
            }
            frameCount = frameCount + 1
        }

        return frameCount
    }
}
