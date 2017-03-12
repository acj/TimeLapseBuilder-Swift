//
//  ViewController.swift
//  TimeLapseBuilder
//
//  Created by Adam Jensen on 11/18/16.

import UIKit

class ViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let urls = [
//            "https://mydomain.com/first.jpg",
//            "https://mydomain.com/second.jpg"
//            ...
            
            "" // REMOVE THIS LINE
        ]
        
        let timelapseBuilder = TimeLapseBuilder(photoURLs: urls)
        timelapseBuilder.build({ progress in
            print(progress)
        }, success: { url in
            print(url)
        }, failure: { error in
            print(error)
        })
    }
}

