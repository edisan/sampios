//
//  SportsDataURLs.swift
//
//  Created by Eddie Sananikone on 2/9/20.
//  Copyright © 2020 Eddie Sananikone. All rights reserved.
//

import Foundation

let ActivePlayers_ID = "ActivePlayers"
let PlayerDetails_ID = "PlayerDetails"

class SportsDataURLs {
    
    static var URLs = [String: SportURL]()
    
    static func loadNBA() {
        let bundle = Bundle(for: self)
        print(bundle)
        var format = PropertyListSerialization.PropertyListFormat.xml
        let url = bundle.url(forResource: "NBA", withExtension: "plist")
        
        do {
            let data = try? Data(contentsOf: url!)
            let plistData = try PropertyListSerialization.propertyList(from: data!, options: .mutableContainersAndLeaves, format: &format) as! [String:String]
            for key in plistData.keys {
                if key != "Svc_Key" {
                    URLs[key] = createSportURL(sportType: .BasketBall, leagueType: .NBA, urlID: key, url: plistData[key]!)
                }
                else {
                    SportsDataService.setServiceKey(svcKey: plistData[key]!)
                }
            }
        }
        catch {
            print("Error reading NBA.plist \(error)")
        }
    }
    
    static func createSportURL(sportType: SportType, leagueType: LeagueType, urlID: String, url: String) -> SportURL {
        let sportURL = SportURL(sport: sportType.rawValue, league: leagueType.rawValue, urlID: urlID, url: url)
        
        return sportURL
    }
}
