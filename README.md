# XProgressHUD

[![CI Status](http://img.shields.io/travis/ming/XProgressHUD.svg?style=flat)](https://travis-ci.org/ming/XProgressHUD)
[![Version](https://img.shields.io/cocoapods/v/XProgressHUD.svg?style=flat)](http://cocoapods.org/pods/XProgressHUD)
[![License](https://img.shields.io/cocoapods/l/XProgressHUD.svg?style=flat)](http://cocoapods.org/pods/XProgressHUD)
[![Platform](https://img.shields.io/cocoapods/p/XProgressHUD.svg?style=flat)](http://cocoapods.org/pods/XProgressHUD)

Swift version of [MBProgressHUD](https://github.com/jdg/MBProgressHUD) with more simplified, friendly methods to send messages between Swift and JS in UIWebViews.

---

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

`XProgressHUD` works on iOS 8+ and swift 4.0.

## Adding XProgressHUD to your project

### CocoaPods

[CocoaPods](http://cocoapods.org) is the recommended way to add MBProgressHUD to your project.

1. Add a pod entry for XProgressHUD to your Podfile `pod 'XProgressHUD'`
2. Install the pod(s) by running `pod install`.
3. Include XProgressHUD wherever you need it with `import XProgressHUD`.


### Source files

Alternatively you can directly add the `XProgressHUD.swift`  to your project.

## Usage

The main guideline you need to follow when dealing with MBProgressHUD while running long-running tasks is keeping the main thread work-free, so the UI can be updated promptly. The recommended way of using MBProgressHUD is therefore to set it up on the main thread and then spinning the task, that you want to perform, off onto a new thread.

```swift
ProgressHUD.showHUD(forView: self.view, animated: true)
DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 10) {
    ProgressHUD.hideHUD(forView: self.view, animated: true)
}

```

If you need to configure the HUD you can do this by using the XProgressHUD reference that showHUDAddedTo:animated: returns.

```swift
let hub = ProgressHUD.showHUD(forView: self.view, animated: true)
hub?.label.text = "加载中"
DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 10) {
ProgressHUD.hideHUD(forView: self.view, animated: true)
}
```

You can also use a `NSProgress` object and MBProgressHUD will update itself when there is progress reported through that object.

```swift
let hub = ProgressHUD.showHUD(forView: self.scrollView, animated: true)
hub?.mode = .determinate
hub?.label.text = "加载中..."
hub?.detailsLabel.text = "(1/2)"
hud?.progressObject = progress;
```

You should be aware that any HUD updates issued inside the above block won't be displayed until the block completes.


## Author

ming, z4015@qq.com

## License

XProgressHUD is available under the MIT license. See the LICENSE file for more info.
