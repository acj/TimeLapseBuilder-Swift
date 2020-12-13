//
//  TestDelegate.swift
//  TimeLapseBuilderTests
//
//  Created by Adam Jensen on 12/13/20.
//

import Foundation
@testable import TimeLapseBuilder

class TestDelegate: TimelapseBuilderDelegate {
    var progressFunc: ((Progress) -> Void)?
    var finishedFunc: ((URL) -> Void)?
    var failedFunc: ((Error) -> Void)?
    
    init(progress: ((Progress) -> Void)?, finished: ((URL) -> Void)?, failed: ((Error) -> Void)?) {
        self.progressFunc = progress
        self.finishedFunc = finished
        self.failedFunc = failed
    }
    
    func timeLapseBuilder(_ timelapseBuilder: TimeLapseBuilder, didMakeProgress progress: Progress) {
        self.progressFunc?(progress)
    }
    
    func timeLapseBuilder(_ timelapseBuilder: TimeLapseBuilder, didFinishWithURL url: URL) {
        self.finishedFunc?(url)
    }
    
    func timelapseBuilder(_ timelapseBuilder: TimeLapseBuilder, didFailWithError error: Error) {
        self.failedFunc?(error)
    }
}
