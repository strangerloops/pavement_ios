//
//  PavementViewController.swift
//  pavement
//
//  Created by Michael Hassin on 8/15/15.
//  Copyright (c) 2015 strangerware. All rights reserved.
//

import UIKit

class PavementViewController: UIViewController {
    
    var button: UIButton!
    var running: Bool = false
    var sensor: Sensor!
    let startImage: UIImage! = UIImage(named: "start-button")
    let stopImage: UIImage! = UIImage(named: "stop-button")
    var sineWave: SineCurveView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let screenHeight = self.view.frame.size.height
        let screenWidth = self.view.frame.size.width
        
        sensor = Sensor(delegate: self)
        sensor.requestLocationAuthorization()
        button = UIButton(type: .Custom)
        button.frame = CGRectMake((screenWidth/2) - (startImage.size.width/2), (screenHeight / 2) - (startImage.size.height / 2), startImage.size.height, startImage.size.width)
        button.setImage(startImage, forState: UIControlState.Normal)
        button.addTarget(self, action: Selector("toggle"), forControlEvents: .TouchUpInside)
        
        view.addSubview(button)
    }
    
    override func viewWillAppear(animated: Bool) {
        let request = NSMutableURLRequest(URL: NSURL(string: GlobalConfig.rootAppURL())!)
        request.HTTPMethod = "GET"
        NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue()) { (response, data, error) in
            // hits server to spin it up
        }
    }
    
    func toggle(){
        if running {
            stop()
        } else {
            go()
        }
    }

    func go(){
        button.setImage(stopImage!, forState: UIControlState.Normal)
        running = true
        sensor.go()
    }
    
    func stop(){
        button.setImage(startImage!, forState: UIControlState.Normal)
        running = false
        sensor.stop()
    }
    
    func updateButtonColor(roughness: Float){
        let adjusted = abs(roughness - 1.0) * 2.5
        let red = CGFloat(adjusted)
        let green = CGFloat(0.0)
        let blue = CGFloat(1.0 - adjusted)
        let color = UIColor(red: red, green: green, blue: blue, alpha: 1.0)
        button.setImage(tintImage(stopImage, withColor: color), forState: .Normal)
    }
    
    func tintImage(originalImage: UIImage, withColor color: UIColor) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(originalImage.size, false, 0.0)
        let rect = CGRectMake(0, 0, originalImage.size.width, originalImage.size.height)
        originalImage.drawInRect(rect)
        color.set()
        UIRectFillUsingBlendMode(rect, CGBlendMode.Screen)
        originalImage.drawInRect(rect, blendMode: CGBlendMode.DestinationIn, alpha: 1.0)
        let image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext()
        return image
    }
}

