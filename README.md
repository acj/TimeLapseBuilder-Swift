# TimeLapseBuilder

This is a reference implementation for building time lapse videos from still images using Swift.

The sample app runs on iOS, but the `TimeLapseBuilder` class can be easily ported to run on macOS.

## Getting started

 1. Clone this repository
 1. Open `TimeLapseBuilder.xcodeproj` with Xcode
 1. Have a look at `ViewController.swift` and `TimeLapseBuilder.swift`
 1. If you provide some URLs in `ViewController.swift` and run the app in the simulator, it will build a video and output its location in the console.
  - A very helpful starter project would be for someone to improve `ViewController` so that it plays the video in an `AVPlayerViewController` once it's ready.

If you need help adapting this code to use in your app, I recommend posting your questions on [Stack Overflow](https://stackoverflow.com). Please open an issue if you find a bug.

## Legacy Swift

Older versions of TimeLapseBuilder are available for Swift 1.2 and 2.0. Check out the `Legacy/` directory.

## Notables

 - [@seanmcneil](https://github.com/seanmcneil) has built a Cocoapod called [Spitfire](https://cocoapods.org/pods/Spitfire) based on this code.
 - Various contributors have helped to fix bugs and port this code to newer versions of Swift. You can find their comments and code on the [original gist](https://gist.github.com/acj/6ae90aa1ebb8cad6b47b).

## Contributing

If you **found a bug**, open an issue.

If you **have a feature request**, open an issue.

If you **want to contribute** (yay!), submit a pull request.

## License

MIT license. Please see the LICENSE file for the particulars.
