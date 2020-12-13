//
//  main.swift
//  SampleApp-macOS
//
//  Created by Adam Jensen on 12/13/20.
//

import Foundation
import TimeLapseBuilder

func main() {
    let assets = assetList(count: 60)
    
    let timelapseBuilder = TimeLapseBuilder(delegate: Delegate())
    let tempPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0] as NSString
    timelapseBuilder.build(with: assets, type: .mov, toOutputPath: tempPath.appendingPathComponent("AssembledVideo.mov"))
}

private func assetList(count: Int) -> [String] {
    let assetType = "jpg"
    let currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let bundleURL = URL(fileURLWithPath: "SampleFixtures.bundle", relativeTo: currentDirectoryURL)
    let bundle = Bundle(url: bundleURL)!
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

class Delegate: TimelapseBuilderDelegate {
    public func timeLapseBuilder(_ timelapseBuilder: TimeLapseBuilder, didMakeProgress progress: Progress) {
        print("Progress: \(progress.fractionCompleted)")
    }

    public func timeLapseBuilder(_ timelapseBuilder: TimeLapseBuilder, didFinishWithURL url: URL) {
        print("Final video is available at \(url)")
        exit(0)
    }

    public func timelapseBuilder(_ timelapseBuilder: TimeLapseBuilder, didFailWithError error: Error) {
        print("Failed to produce video: \(error)")
        exit(1)
    }
}

main()

Thread.sleep(forTimeInterval: 60)
