//
//  StatsViewController.swift
//  pavement
//
//  Created by Michael Hassin on 11/3/15.
//  Copyright © 2015 strangerware. All rights reserved.
//

import UIKit

class StatsViewController: UIViewController {

    var distanceLabel: UILabel!
    var rankLabel: UILabel!
    var recalButton: UIButton!
    let recalImage = UIImage(named: "recal-button")!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let screenHeight = self.view.frame.size.height
        let screenWidth = self.view.frame.size.width
        distanceLabel = UILabel(frame: CGRectMake(0, screenHeight / 8, screenWidth, screenHeight / 10))
        rankLabel     = UILabel(frame: CGRectMake(0, screenHeight / 5, screenWidth, screenHeight / 10))
        distanceLabel.textAlignment = .Center
        distanceLabel.numberOfLines = 0
        rankLabel.textAlignment     = .Center
        let recalLabel = UILabel(frame: CGRectMake(screenWidth * 0.1, screenHeight * 0.5, screenWidth * 0.8, screenHeight * 0.5))
        recalLabel.text = "Press this button when your pavement measuring setup changes, such as if you switch your bike, tires or phone mount.\n\nRecalibrating will preserve your record of miles measured."
        recalLabel.numberOfLines = 0
        recalLabel.textAlignment  = .Center
        let recalButton = UIButton(type: .Custom)
        recalButton.frame = CGRectMake((screenWidth/2) - (recalImage.size.width/4), (screenHeight * 0.6) - (recalImage.size.height / 4), recalImage.size.width / 2, recalImage.size.height / 2)
        recalButton.setImage(recalImage, forState: .Normal)
        recalButton.addTarget(self, action: Selector("recalibrate"), forControlEvents: .TouchUpInside)
        
        view.addSubview(distanceLabel)
        view.addSubview(rankLabel)
        view.addSubview(recalButton)
        view.addSubview(recalLabel)

        if NSUserDefaults.standardUserDefaults().dictionaryRepresentation().keys.contains("scoreboardId") {
            let scoreboardId = NSUserDefaults.standardUserDefaults().integerForKey("scoreboardId")
            NSRRequest.GET().routeTo("/scoreboards/rank/\(scoreboardId)").sendAsynchronous { (response, error) -> Void in
                if let rank = (response as! NSDictionary)["rank"] as? Int {
                    if rank > 0 {
                        self.rankLabel.text = "(That's #\(rank) worldwide!)"
                    }
                }
            }
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        let totalDistance = NSUserDefaults.standardUserDefaults().doubleForKey("totalDistanceMeters")
        distanceLabel.text = "Miles of pavement measured:\n \(metersToMiles(totalDistance))"
    }
    
    func recalibrate(){
        NSUserDefaults.standardUserDefaults().removeObjectForKey("calibrationId")
    }
    
    func metersToMiles(meters: Double) -> Int {
        return Int(meters * 0.000621371)
    }
}
