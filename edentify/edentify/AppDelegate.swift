//
// NOTE: The code derived here was pulled from Apple's VisionFaceTrack sample
//       Updates were made to add face recognition of author and Manny Pacquiao.  Doing so allowed
//       understanding of the code involved to make use of Vision.
//
//  AppDelegate.swift
//  edentify
//
//  Created by Eddie Sananikone on 5/14/20.
//  Copyright © 2020 Eddie Sananikone. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        self.window?.makeKeyAndVisible()
        
        return true
    }

}

