//
//  Reading.swift
//  pavement
//
//  Created by Michael Hassin on 8/26/15.
//  Copyright (c) 2015 strangerware. All rights reserved.
//

import CoreLocation

@objc(Reading) class Reading: NSRRemoteObject {
   
    var startLat: NSNumber?
    var startLon: NSNumber?
    var endLat: NSNumber?
    var endLon: NSNumber?
    var accelerationX: [NSNumber]?
    var accelerationY: [NSNumber]?
    var accelerationZ: [NSNumber]?
    var angleX: NSNumber?
    var angleY: NSNumber?
    var angleZ: NSNumber?
    var startTime: NSNumber?
    var endTime: NSNumber?
    var ride: Ride?
    
    override func shouldOnlySendIDKeyForNestedObjectProperty(property: String!) -> Bool {
        return property == "ride"
    }
    
    func isGarbage() -> Bool {
        let start = CLLocation(latitude: startLat!.doubleValue, longitude: startLon!.doubleValue)
        let end = CLLocation(latitude: endLat!.doubleValue, longitude: endLon!.doubleValue)
        let meterDistance = start.distanceFromLocation(end)
        return (meterDistance > 30.0 || meterDistance <= 0.08) && accelerationX!.count > 0
    }
}
