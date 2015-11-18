//
//  Ride.swift
//  pavement
//
//  Created by Michael Hassin on 8/28/15.
//  Copyright (c) 2015 strangerware. All rights reserved.
//

@objc(Ride) class Ride: NSRRemoteObject {
    var startTime: NSNumber?
    var endTime: NSNumber?
    var calibrationId: NSNumber?
    var scoreboardId: NSNumber?
}
