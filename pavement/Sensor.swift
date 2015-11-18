//
//  Sensor.swift
//  pavement
//
//  Created by Michael Hassin on 8/22/15.
//  Copyright (c) 2015 strangerware. All rights reserved.
//

import UIKit
import CoreLocation
import CoreMotion

class Sensor: NSObject, CLLocationManagerDelegate {
    
    let locationManager = CLLocationManager()
    let motionManager = CMMotionManager()
    var accelerationX = [Double]()
    var accelerationY = [Double]()
    var accelerationZ = [Double]()
    var angleX = 0.0
    var angleY = 0.0
    var angleZ = 0.0
    var previousLocation: CLLocation?
    var previousEndTime: NSNumber?
    var ride: Ride?
    let startImage = UIImage(named: "start-button")
    let stopImage = UIImage(named: "stop-button")
    var delegate: PavementViewController

    let UPDATE_INTERVAL = 0.005 // seconds

    init(delegate: PavementViewController){
        self.delegate = delegate
    }
    
    func requestLocationAuthorization(){
        locationManager.requestAlwaysAuthorization()
    }
    
    func go() {
        
        delegate.button.enabled = false
        locationManager.activityType = CLActivityType.AutomotiveNavigation
        // causes readings to snap to roads, which i can't decide if we want or not (i think we want it)
        // it will affect readings on the lakefront (theyre snapped to LSD) maybe allow it to switch to walking
        // see http://ilquest.com/2012/11/02/ios-6-is-unusable-for-people-relying-on-accurate-gps-tracks/
        // update: this is "ok for now" but should eventually use OSRM snap to road on the server
        
        ride = Ride()
        let now = NSDate().timeIntervalSince1970
        previousEndTime = now
        ride!.startTime = now
        let defaults = NSUserDefaults.standardUserDefaults()
        let calibrated = defaults.dictionaryRepresentation().keys.contains("calibrationId")
        let scoreboardPresence = defaults.dictionaryRepresentation().keys.contains("scoreboardId")
        if calibrated {
            ride!.calibrationId = defaults.integerForKey("calibrationId")
        }
        if scoreboardPresence {
            ride!.scoreboardId = defaults.integerForKey("scoreboardId")
        }
        ride!.remoteCreateAsync { error in
            if error != nil {
                print("couldn't create ride.")
            } else {
                if !calibrated {
                    let newId = self.ride!.remoteID
                    defaults.setInteger(Int(newId), forKey: "calibrationId")
                    self.ride!.calibrationId = newId
                }
                if !scoreboardPresence {
                    let newId = self.ride!.remoteID
                    defaults.setInteger(Int(newId), forKey: "scoreboardId")
                    self.ride!.scoreboardId = newId
                }
                self.beginPollingLocation()
                self.beginPollingMotion()
            }
            self.delegate.button.enabled = true
        }
    }
    
    func beginPollingLocation(){
        if CLLocationManager.locationServicesEnabled() {
            previousEndTime = NSDate().timeIntervalSince1970
            locationManager.delegate = self
            locationManager.distanceFilter = 0.00001
            locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
            locationManager.startUpdatingLocation()
        }
    }
    
    func beginPollingMotion(){
        motionManager.startAccelerometerUpdatesToQueue(NSOperationQueue.mainQueue()) { (data: CMAccelerometerData?, error: NSError?) -> Void in
        
            func square(number: Double) -> Double {
                return number * number
            }
            
            func phoneAtRest(force: Double) -> Bool {
                return (abs(force) > 0.98) && (abs(force) < 1.02)
            }
            
            func lowpass(number: Double) -> Double {
                if number > 1.0 {
                    return 1.0
                }
                if number < -1.0 {
                    return -1.0
                }
                return number
            }
            
            if let motionData = data {
                let acceleration = motionData.acceleration
                let x = acceleration.x
                let y = acceleration.y
                let z = acceleration.z
                let totalForce = sqrt(square(x) + square(y) + square(z))
                
                // http://www.intmath.com/vectors/7-vectors-in-3d-space.php
                
                if phoneAtRest(totalForce) {
                    self.angleX = acos(lowpass(x * totalForce))
                    self.angleY = acos(lowpass(y * totalForce))
                    self.angleZ = acos(lowpass(z * totalForce))
                }
                if self.angleX != 0.0 && self.angleY != 0.0 && self.angleZ != 0.0 {
                    self.accelerationX.append(x)
                    self.accelerationY.append(y)
                    self.accelerationZ.append(z)
                }
            }
        }
    }
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let newLocation = locations.last as CLLocation!
        let now = NSDate().timeIntervalSince1970
        if let oldLocation = previousLocation {
            if (accelerationX.count > 1) && (accelerationY.count > 1) && (accelerationZ.count > 1) {
                let reading = Reading()
                reading.ride = ride
                reading.startTime = previousEndTime
                reading.endTime = now
                reading.startLat = NSNumber(double: oldLocation.coordinate.latitude)
                reading.startLon = NSNumber(double: oldLocation.coordinate.longitude)
                reading.endLat = NSNumber(double: newLocation.coordinate.latitude)
                reading.endLon = NSNumber(double: newLocation.coordinate.longitude)
                reading.accelerationX = accelerationX.map { NSNumber(double: $0) }
                reading.accelerationY = accelerationY.map { NSNumber(double: $0) }
                reading.accelerationZ = accelerationZ.map { NSNumber(double: $0) }
                reading.angleX = NSNumber(double: angleX)
                reading.angleY = NSNumber(double: angleY)
                reading.angleZ = NSNumber(double: angleZ)
                if !reading.isGarbage(){
                    sendData(reading)
                }
                updateButtonColor()
                let defaults = NSUserDefaults.standardUserDefaults()
                let previousDistance = defaults.doubleForKey("totalDistanceMeters")
                let additionalDistance = oldLocation.distanceFromLocation(newLocation)
                defaults.setDouble(previousDistance + additionalDistance, forKey: "totalDistanceMeters")
            }
        }
        clearAccelerationArrays()
        previousLocation = newLocation
        previousEndTime = now
    }
    
    func clearAccelerationArrays(){
        accelerationX.removeAll()
        accelerationY.removeAll()
        accelerationZ.removeAll()
    }
    
    func stop() {
//        delegate.eraseSine()
        clearAccelerationArrays()
        angleX = 0.0
        angleY = 0.0
        angleZ = 0.0
        previousLocation = nil
        previousEndTime = nil
        locationManager.stopUpdatingLocation()
        motionManager.stopAccelerometerUpdates()
        
        if ride != nil {
            ride!.endTime = NSDate().timeIntervalSince1970
            ride!.remoteUpdateAsync { error in
                NSRRequest.POST().routeToObject(self.ride!, withCustomMethod: "trim").sendAsynchronous({ (jsonRep, error) in
                    self.ride = nil
                })
            }
        }
    }
    
    func updateButtonColor(){
        let x = accelerationX.reduce(0) { $0 + $1 } / Double(accelerationX.count)
        let y = accelerationY.reduce(0) { $0 + $1 } / Double(accelerationY.count)
        let z = accelerationZ.reduce(0) { $0 + $1 } / Double(accelerationZ.count)
        let g = (cos(angleX) * x) + (cos(angleY) * y) + (cos(angleZ) * z)
        delegate.updateButtonColor(Float(g))
    }

    func sendData(reading: Reading){
        // TODO: no if false!
        if false {
            reading.remoteCreateAsync { (error) -> Void in
                if error != nil {
                    print("error: \(error!)")
                }
            }
        }
    }
}
