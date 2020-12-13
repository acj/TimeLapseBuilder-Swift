//
//  TestDelegate.swift
//  TimeLapseBuilderTests
//
//  Created by Adam Jensen on 12/13/20.
//

import Foundation
@testable import TimeLapseBuilder

class TestDelegate: TimelapseBuilderDelegate {
    var didMakeProgress: ((Progress) -> Void)?
    var didFinish: ((URL) -> Void)?
    var didFailWithError: ((Error) -> Void)?
    
    init(progress: ((Progress) -> Void)?, finished: ((URL) -> Void)?, failed: ((Error) -> Void)?) {
        self.didMakeProgress = progress
        self.didFinish = finished
        self.didFailWithError = failed
    }
    
    func timeLapseBuilder(_ timelapseBuilder: TimeLapseBuilder, didMakeProgress progress: Progress) {
        self.didMakeProgress?(progress)
    }
    
    func timeLapseBuilder(_ timelapseBuilder: TimeLapseBuilder, didFinishWithURL url: URL) {
        self.didFinish?(url)
    }
    
    func timelapseBuilder(_ timelapseBuilder: TimeLapseBuilder, didFailWithError error: Error) {
        self.didFailWithError?(error)
    }
}
