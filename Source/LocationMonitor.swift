//
//  LocationMonitor.swift
//  LocationMonitor
//
//  Created by Tim Searle on 18/04/2016.
//  Copyright © 2016 Nice Agency. All rights reserved.
//

import Foundation
import CoreLocation

/// `ErrorType` cases specific to `LocationManager` usage
public enum LocationMonitorError: Int, ErrorType {
    case LocationServicesUnavailable = 0
    case LocationServicesDisallowed
    case LocationServicesRequestTimedOut
}

/// `CLLocationManager` wrapper class that supports quick and easy access to the user's current location, with the ability to filter updates
public final class LocationMonitor: NSObject {
    
    public static let shared: LocationMonitor = LocationMonitor()
    
    public typealias LocationUpdateCallback = (CLLocation?, NSError?, StopLocationUpdates) -> Void
    public typealias LocationUpdateFilter = ((CLLocation) -> Bool)
    public typealias StopLocationUpdates = (() -> Void)
    
    private let locationManager: CLLocationManager = CLLocationManager()
    
    private(set) public var cachedLocation: CLLocation?
    private var listeners: [String : (LocationUpdateFilter?,LocationUpdateCallback,StopLocationUpdates)] = [:]
    private var timers: [String : NSTimer] = [:]
    
    /**
     The desired `CLLocationAccuracy` for the location manager. See `desiredAccuracy` on `CLLocationManager` for more information.
     */
    public var accuracy: CLLocationAccuracy {
        get {
            return self.locationManager.desiredAccuracy
        }
        set(accuracy) {
            self.locationManager.desiredAccuracy = accuracy
        }
    }
    
    /**
     The minimum `CLLocationDistance` a device must move horizontally before generating updates. See `distanceFilter` on `CLLocationManager` for more information.
     */
    public var distance: CLLocationDistance {
        get {
            return self.locationManager.distanceFilter
        }
        set(distance) {
            self.locationManager.distanceFilter = distance
        }
    }
    
    /**
     The maximum time that can elapse between location updates
     */
    public var timeout: NSTimeInterval = 60
    
    public override init() {
        super.init()
        self.locationManager.delegate = self
    }
    
    /**
     Request for permission to start accessing location updates
     */
    public func requestPermission() {
        print("Checking authorization status")
        self.locationManager.delegate = self
        self.requestPermissionAndStartUpdating(false)
    }
    
    private func requestPermissionAndStartUpdating(startUpdating: Bool) {
        let status = CLLocationManager.authorizationStatus()
        
        switch status {
        case .AuthorizedAlways, .AuthorizedWhenInUse:
            print("CLLocationManager authorized")
            if startUpdating {
                self.locationManager.startUpdatingLocation()
            }
        case .NotDetermined:
            print("Request location services permissions")
            self.locationManager.requestWhenInUseAuthorization()
        case .Restricted, .Denied:
            print("Location services are not allowed")
        }
    }
    
    /**
     Check if the location manager is authorized for updates
     - Returns: A tuple with two values, a `Bool` representing if the manager is authorized and the associated `CLAuthorizationStatus`
     */
    public func isAuthorized() -> (Bool, CLAuthorizationStatus) {
        let status = CLLocationManager.authorizationStatus()
        
        if status == .AuthorizedWhenInUse || status == .AuthorizedAlways {
            return (true, status)
        }
        
        return (false, status)
    }
    
    /**
     Register with the location manager for location updates with an optional location filter.
     - Parameter filter: Optional callback of type `LocationUpdateFilter` that allows caller to filter out/in certain updates
     - Parameter locationUpdate: Callback of type `LocationUpdateCallback` that informs the caller when location updates have been returned
     - Throws: `LocationManagerError` errors based on the availability of location services
     */
    public func startUpdatingLocation(filter: LocationUpdateFilter? = nil, locationUpdate: LocationUpdateCallback) throws -> StopLocationUpdates {
        
        if !CLLocationManager.locationServicesEnabled() {
            throw LocationMonitorError.LocationServicesUnavailable
        }
        
        let status = CLLocationManager.authorizationStatus()
        
        if status == .Denied || status == .Restricted {
            throw LocationMonitorError.LocationServicesDisallowed
        }
        
        let someKey = NSUUID().UUIDString
        
        self.timers[someKey] = NSTimer.scheduledTimerWithTimeInterval(self.timeout, target: self, selector: #selector(locationUpdateDidTimeout(_:)), userInfo: someKey, repeats: false)
        
        let stopUpdates = {
            self.listeners.removeValueForKey(someKey)
            
            self.timers[someKey]?.invalidate()
            self.timers.removeValueForKey(someKey)
            
            if self.listeners.count == 0 {
                self.locationManager.stopUpdatingLocation()
            }
        }
        
        let callbackEntry = (filter,locationUpdate,stopUpdates)
        
        self.listeners[someKey] = callbackEntry
        
        self.requestPermissionAndStartUpdating(true)
        
        return stopUpdates
    }
    
    func locationUpdateDidTimeout(timer: NSTimer) {
        guard let key = timer.userInfo as? String else {
            return
        }
        
        
        print("We've timed out!")
        
        self.timers[key]?.invalidate()
        self.timers.removeValueForKey(key)
        
        if let (_,callback,stopUpdates) = self.listeners[key] {
            
            let error = NSError(domain: "LocationMonitorError",
                                code: LocationMonitorError.LocationServicesRequestTimedOut.rawValue,
                                userInfo: [NSLocalizedDescriptionKey : "\(LocationMonitorError.LocationServicesRequestTimedOut)"])
            
            callback(nil, error, stopUpdates)
            stopUpdates()
        }
    }
    
    /**
     Stop all location updates for all attached listeners
     */
    public func stopAllLocationUpdates() {
        for (_,(_,_,stopUpdating)) in self.listeners {
            stopUpdating()
        }
    }
}

extension LocationMonitor: CLLocationManagerDelegate {
    
    public func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard self.listeners.count > 0 else {
            self.locationManager.stopUpdatingLocation()
            return
        }
        
        if let latestUpdate = locations.last {
            
            for (key, (filter, callback, stop)) in self.listeners {
                
                self.timers[key]?.invalidate()
                self.timers[key] = NSTimer.scheduledTimerWithTimeInterval(self.timeout, target: self, selector: #selector(locationUpdateDidTimeout(_:)), userInfo: key, repeats: false)
                
                if let locationUpdateFilter = filter {
                    if locationUpdateFilter(latestUpdate) {
                        callback(latestUpdate,nil,stop)
                    }
                } else {
                    callback(latestUpdate,nil,stop)
                }
            }
            
            self.cachedLocation = latestUpdate
        }
    }
    
    public func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        
        if status == .AuthorizedWhenInUse || status == .AuthorizedAlways {
            if self.listeners.count > 0 {
                self.locationManager.startUpdatingLocation()
            }
        }
        
        if status == .Denied || status == .Restricted {
            
            for (_, (_, callback, stop)) in self.listeners {
                
                let error = NSError(domain: "LocationMonitorError",
                                    code: LocationMonitorError.LocationServicesDisallowed.rawValue,
                                    userInfo: [NSLocalizedDescriptionKey : "\(LocationMonitorError.LocationServicesDisallowed)"])
                
                callback(nil, error, stop)
                
                stop()
            }
        }
    }
    
    public func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        
        for (key, (_, callback, stop)) in self.listeners {
            
            self.timers[key]?.invalidate()
            self.timers.removeValueForKey(key)
            
            callback(nil, error, stop)
        }
    }
}
