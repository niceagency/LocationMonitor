# LocationMonitor
___

[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/niceagency/LocationMonitor) [![Carthage compatible](https://img.shields.io/badge/twitter-%40niceagency-blue.svg)](https://twitter.com/niceagency)

#### Supports Swift 3

LocationMonitor is a simple wrapper class written around `CLLocationManager` and `CLLocationManagerDelegate` to make requesting permissions and getting access to the user's current location quick and easy.

## Features
___

* Trigger permission prompt when suits you best
* Get user's current location in one call
* Customisable location update timeout
* Supports multiple listeners to receive location updates independently
* Per location listener update filter

## Requirements
___

Ensure you add one of the following keys with an associated string to your Info.plist file

`NSLocationWhenInUseUsageDescription`

`NSLocationAlwaysUsageDescription`

##### System requirements

+ iOS 9.3+ 
+ Xcode 8.0+
+ Swift 3.0+

## Usage
___

### Prompt use for permission (if needed)

`LocationManager.shared.requestPermission()`

### Check permission status

`let (authorized, status) = LocationManager.shared.isAuthorized()`

Where *authorized* is a `Bool` and *status* is a value of `CLAuthorizationStatus`

### Start receiving location updates

```
do {
	var stopUpdating = try LocationManager.shared.startUpdatingLocation { location, error, stopUdating in
	    print(location) // Do something with return location
	    stopUdating() // Stop receiving location updates on this listener
	}  
} catch {
    print(error)
}
```

The location update callback contains 3 parameters an optional `CLLocation` object, an optional error and a function that will stop updates on this listener.

### Filter location updates

```
do {   
    try LocationManager.shared.startUpdatingLocation({ location -> Bool in
        // Do some specific update filter block here
        return true
    }, locationUpdate: { location, error, stopUdating in
            stopUdating()
    })
} catch {
    print(error)
}
```

### Configurable properties

```
LocationManager.shared.accuracy = CLLocationAccuracy(10)
LocationManager.shared.distance = CLLocationDistance(100)
LocationManager.shared.timeout = 60
```

## Installation
___

### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks.

You can install Carthage with [Homebrew](http://brew.sh/) using the following command:

`$ brew update`

`$ brew install carthage`

To integrate LocationMonitor into your Xcode project using Carthage, specify it in your Cartfile:

`github "niceagency/LocationMonitor"`

Run `carthage update` to build the framework and drag the built LocationMonitor.framework into your Xcode project.

## Additional Information
___

Please review the [CLLocationManager](https://developer.apple.com/library/ios/documentation/CoreLocation/Reference/CLLocationManager_Class/) documentation for more information.

This library is written in Swift 3.

## Contributions
___

If you wish to contribute to LocationMonitor please fork the repository and send a pull request or raise an issue within GitHub.

## License
___

LocationMonitor is released under the MIT license. See LICENSE for details.
