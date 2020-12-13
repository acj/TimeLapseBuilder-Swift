//
//  ViewController.swift
//  TimeLapseBuilder
//
//  Created by Adam Jensen on 11/18/16.

import AVKit
import TimeLapseBuilder
import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var progressView: UIProgressView!
    
    @IBAction func buildTimelapse(_ sender: Any) {
        let assets = assetList(count: 60)
        
        let timelapseBuilder = TimeLapseBuilder(delegate: self)
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
        timelapseBuilder.build(with: assets, type: .mov, toOutputPath: documentsPath.appendingPathComponent("AssembledVideo.mov"))
    }
    
    private func assetList(count: Int) -> [String] {
        let assetType = "jpg"
        let bundle = Bundle.main
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

extension ViewController: TimelapseBuilderDelegate {
    public func timeLapseBuilder(_ timelapseBuilder: TimeLapseBuilder, didMakeProgress progress: Progress) {
        DispatchQueue.main.async {
            self.progressView.setProgress(Float(progress.fractionCompleted), animated: true)
        }
    }
    
    public func timeLapseBuilder(_ timelapseBuilder: TimeLapseBuilder, didFinishWithURL url: URL) {
        DispatchQueue.main.async {
            let playerVC = AVPlayerViewController()
            playerVC.player = AVPlayer(url: url)
            self.present(playerVC, animated: true) {
                self.progressView.setProgress(0, animated: true)
            }
        }
    }
    
    public func timelapseBuilder(_ timelapseBuilder: TimeLapseBuilder, didFailWithError error: Error) {
        let alert = UIAlertController(title: "Couldn't build timelapse", message: "\(error)", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}
