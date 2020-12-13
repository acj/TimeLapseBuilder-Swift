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
        
        let assets = assetList(count: 3)
        let timelapseBuilder = TimeLapseBuilder(photoURLs: assets)
        timelapseBuilder.build({ progress in
            // Ignore
        }, success: { url in
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.relativePath))
            expectation.fulfill()
        }, failure: { error in
            XCTFail("unexpected failure: \(error)")
        })
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testWhenGivenASeriesOfImages_reportsProgressCorrectly() {
        let expectation = self.expectation(description: "Build timelapse")
        
        var mostRecentCompletedUnitCount: Int64 = 0
        let progress = { (progress: Progress) in
            XCTAssertEqual(progress.completedUnitCount, mostRecentCompletedUnitCount + 1)
            mostRecentCompletedUnitCount += 1
            
            if progress.isFinished {
                expectation.fulfill()
            }
        }
        
        let assets = assetList(count: 3)
        let timelapseBuilder = TimeLapseBuilder(photoURLs: assets)
        timelapseBuilder.build(progress, success: { url in
            // Ignore
        }, failure: { error in
            XCTFail("unexpected failure: \(error)")
        })
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testWhenGivenASeriesOfImages_producesVideoOfExpectedDuration() {
        let expectation = self.expectation(description: "Build timelapse")
        
        let assets = assetList(count: 30)
        let timelapseBuilder = TimeLapseBuilder(photoURLs: assets)
        timelapseBuilder.build({ progress in
            // Ignore
        }, success: { url in
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
        }, failure: { error in
            XCTFail("unexpected failure: \(error)")
        })
        
        waitForExpectations(timeout: 5, handler: nil)
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
