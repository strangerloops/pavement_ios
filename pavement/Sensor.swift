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
    var motionData: [String] = []
    var previousLocation: CLLocation?
    var previousEndTime: String?
    var ride: Ride?

    let UPDATE_INTERVAL = 0.005
    
    override init() {
        locationManager.activityType = CLActivityType.AutomotiveNavigation
        // causes readings to snap to roads, which i can't decide if we want or not (i think we want it)
        // it does mess up readings on the lakefront trail maybe incl a switch to switch it to walking
        // see http://ilquest.com/2012/11/02/ios-6-is-unusable-for-people-relying-on-accurate-gps-tracks/
    }

    func go() {
        ride = Ride()
        ride!.startTime = NSDate().description
        ride!.remoteCreateAsync { error in
            if error != nil {
                println("oops")
            } else {
                self.beginPollingLocation()
                self.beginPollingMotion()
            }
        }
    }
    
    func beginPollingLocation(){
        locationManager.requestAlwaysAuthorization()
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.distanceFilter = 0.00001
            locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
            locationManager.startUpdatingLocation()
        }
    }
    
    func beginPollingMotion(){
        if motionManager.deviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = UPDATE_INTERVAL
            motionManager.startDeviceMotionUpdatesToQueue(NSOperationQueue.mainQueue(), withHandler: { [unowned self] (data: CMDeviceMotion!, error: NSError!) in
                    self.motionData.append("\(data.userAcceleration.z)")
                })
        } else {
            println("no device motion available")
        }
    }
    
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        let newLocation = locations.last as! CLLocation
        let now = NSDate().description
        if let oldLocation = previousLocation {
            let acceleration = (motionData.reduce("", combine: {($0 as String) + ", " + $1}) as NSString)
            if acceleration.length > 1 {
                let reading = Reading()
                println(ride!.remoteID)
                reading.ride = ride
                reading.startTime = previousEndTime
                reading.endTime = now
                reading.startLat = NSNumberFormatter().numberFromString("\(oldLocation.coordinate.latitude)")!.floatValue
                reading.startLon = NSNumberFormatter().numberFromString("\(oldLocation.coordinate.longitude)")!.floatValue
                reading.endLat = NSNumberFormatter().numberFromString("\(newLocation.coordinate.latitude)")!.floatValue
                reading.endLon = NSNumberFormatter().numberFromString("\(newLocation.coordinate.longitude)")!.floatValue
                reading.acceleration = acceleration.substringWithRange(NSRange(location: 2, length: acceleration.length - 2))
                sendData(reading)
            }
        }
        motionData.removeAll()
        previousLocation = newLocation
        previousEndTime = now
    }
    
    func stop() {
        motionData.removeAll()
        locationManager.stopUpdatingLocation()
        motionManager.stopDeviceMotionUpdates()
        if ride != nil {
            let defaults = NSUserDefaults.standardUserDefaults()
            let calibrated = defaults.integerForKey("calibrationRide") != 0
            ride!.endTime = NSDate().description
            if calibrated {
               ride!.calibrationID = defaults.integerForKey("calibrationRide")
            }
            ride!.remoteUpdateAsync { error in
                if !calibrated {
                    defaults.setInteger(self.ride!.remoteID.integerValue, forKey: "calibrationRide")
                }
                self.ride = nil
            }
        }
    }
    
    func sendData(reading: Reading){
        reading.remoteCreateAsync { (error) -> Void in
            if error != nil {
                println("error: \(error!)")
            }
        }
    }
}
