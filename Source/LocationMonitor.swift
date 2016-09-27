//
//  LocationMonitor.swift
//  LocationMonitor
//
//  Created by Tim Searle on 18/04/2016.
//  Copyright © 2016 Nice Agency. All rights reserved.
//

import Foundation
import CoreLocation

/// `Error` cases specific to `LocationManager` usage
public enum LocationMonitorError: Int, Error {
    case locationServicesUnavailable = 0
    case locationServicesDisallowed
    case locationServicesRequestTimedOut
}

/// `CLLocationManager` wrapper class that supports quick and easy access to the user's current location, with the ability to filter updates
public class LocationMonitor: NSObject {
    
    public static let shared: LocationMonitor = LocationMonitor()
    
    public typealias StopLocationUpdates = () -> Void
    public typealias LocationUpdateCallback = ((CLLocation?, Error?, StopLocationUpdates) -> Void)
    public typealias LocationUpdateFilter = ((CLLocation) -> Bool)
    
    fileprivate let locationManager: CLLocationManager = CLLocationManager()
    fileprivate(set) public var cachedLocation: CLLocation?
    fileprivate var listeners: [String : (LocationUpdateFilter?,LocationUpdateCallback,StopLocationUpdates)] = [:]
    fileprivate var timers: [String : Timer] = [:]
    
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
    public var timeout: TimeInterval = 60
    
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
        self.requestPermission(startUpdating: false)
    }
    
    fileprivate func requestPermission(startUpdating: Bool) {
        let status = CLLocationManager.authorizationStatus()
        
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            print("CLLocationManager authorized")
            if startUpdating {
                self.locationManager.startUpdatingLocation()
            }
        case .notDetermined:
            print("Request location services permissions")
            self.locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            print("Location services are not allowed")
        }
    }
    
    /**
     Check if the location manager is authorized for updates
     - Returns: A tuple with two values, a `Bool` representing if the manager is authorized and the associated `CLAuthorizationStatus`
     */
    public func isAuthorized() -> (Bool, CLAuthorizationStatus) {
        let status = CLLocationManager.authorizationStatus()
        
        if status == .authorizedWhenInUse || status == .authorizedAlways {
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
    @nonobjc public func startUpdatingLocation(filter: LocationUpdateFilter? = nil, locationUpdate: @escaping LocationUpdateCallback) throws -> StopLocationUpdates {
        
        if !CLLocationManager.locationServicesEnabled() {
            throw LocationMonitorError.locationServicesUnavailable
        }
        
        let status = CLLocationManager.authorizationStatus()
        
        if status == .denied || status == .restricted {
            throw LocationMonitorError.locationServicesDisallowed
        }
        
        let someKey = UUID().uuidString
        
        self.timers[someKey] = Timer.scheduledTimer(timeInterval: self.timeout, target: self, selector: #selector(LocationMonitor.locationUpdateDidTimeout), userInfo: someKey, repeats: false)
        
        let stopUpdates = {
            self.listeners.removeValue(forKey: someKey)
            
            self.timers[someKey]?.invalidate()
            self.timers.removeValue(forKey: someKey)
            
            if self.listeners.count == 0 {
                self.locationManager.stopUpdatingLocation()
            }
        }
        
        let callbackEntry = (filter,locationUpdate,stopUpdates)
        
        self.listeners[someKey] = callbackEntry
        
        self.requestPermission(startUpdating: true)
        
        return stopUpdates
    }
    
    func locationUpdateDidTimeout(timer: Timer) {
        guard let key = timer.userInfo as? String else {
            return
        }
        
        print("We've timed out!")
        
        self.timers[key]?.invalidate()
        self.timers.removeValue(forKey: key)
        
        if let (_,callback,stopUpdates) = self.listeners[key] {
            
            let error = NSError(domain: "LocationMonitorError",
                                code: LocationMonitorError.locationServicesRequestTimedOut.rawValue,
                                userInfo: [NSLocalizedDescriptionKey : "\(LocationMonitorError.locationServicesRequestTimedOut)"])
            
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
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard self.listeners.count > 0 else {
            self.locationManager.stopUpdatingLocation()
            return
        }
        
        if let latestUpdate = locations.last {
            
            for (key, (filter, callback, stop)) in self.listeners {
                
                self.timers[key]?.invalidate()
                self.timers[key] = Timer.scheduledTimer(timeInterval: self.timeout, target: self, selector: #selector(LocationMonitor.locationUpdateDidTimeout), userInfo: key, repeats: false)
                
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
    
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            if self.listeners.count > 0 {
                self.locationManager.startUpdatingLocation()
            }
        }
        
        if status == .denied || status == .restricted {
            
            for (_, (_, callback, stop)) in self.listeners {
                
                let error = NSError(domain: "LocationMonitorError",
                                    code: LocationMonitorError.locationServicesDisallowed.rawValue,
                                    userInfo: [NSLocalizedDescriptionKey : "\(LocationMonitorError.locationServicesDisallowed)"])
                
                callback(nil, error, stop)
                
                stop()
            }
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        
        for (key, (_, callback, stop)) in self.listeners {
            
            self.timers[key]?.invalidate()
            self.timers.removeValue(forKey: key)
            
            callback(nil, error, stop)
        }
    }
}
