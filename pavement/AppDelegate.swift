//
//  AppDelegate.swift
//  pavement
//
//  Created by Michael Hassin on 8/15/15.
//  Copyright (c) 2015 strangerware. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        
        UIApplication.sharedApplication().idleTimerDisabled = true
                
        NSRConfig.defaultConfig().rootURL = NSURL(string: GlobalConfig.rootAppURL())
        NSRConfig.defaultConfig().basicAuthUsername = "peemster"
        NSRConfig.defaultConfig().basicAuthPassword = "halsadick"
        NSRConfig.defaultConfig().configureToRailsVersion(NSRRailsVersion.Version3)
        
        let tabs = UITabBarController()
        let pavementView = PavementViewController()
        let statsView = StatsViewController()
        tabs.viewControllers = [pavementView, statsView]
        pavementView.tabBarItem = UITabBarItem(title: "Pavement", image: UIImage(named: "pavement-tab"), tag: 0)
        statsView.tabBarItem = UITabBarItem(title: "Stats",       image: UIImage(named: "stats-tab")  , tag: 1)
    
        let defaults = NSUserDefaults.standardUserDefaults()
        if !defaults.dictionaryRepresentation().keys.contains("totalDistanceMeters"){
            defaults.setDouble(0.0, forKey: "totalDistanceMeters")
        }
        
        self.window = UIWindow(frame: UIScreen.mainScreen().bounds)
        self.window!.rootViewController = tabs
        self.window!.backgroundColor = UIColor.whiteColor()
        self.window!.makeKeyAndVisible()

        return true
    }
}

