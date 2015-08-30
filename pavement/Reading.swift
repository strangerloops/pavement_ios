//
//  Reading.swift
//  pavement
//
//  Created by Michael Hassin on 8/26/15.
//  Copyright (c) 2015 strangerware. All rights reserved.
//

@objc(Reading) class Reading: NSRRemoteObject {
   
    var startLat: NSNumber?
    var startLon: NSNumber?
    var endLat: NSNumber?
    var endLon: NSNumber?
    var acceleration: NSString?
    var startTime: String?
    var endTime: String?
    var ride: Ride?
    
    override func shouldOnlySendIDKeyForNestedObjectProperty(property: String!) -> Bool {
        return property == "ride"
    }
}
