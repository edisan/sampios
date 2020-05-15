//
//  SportsDataService.swift
//
//  Created by Eddie Sananikone on 1/30/20.
//  Copyright © 2020 Eddie Sananikone. All rights reserved.
//

import Foundation

class SportsDataService: SportAdapter, ServiceProtocol {
    
    final let Svc_Key_Name = "Ocp-Apim-Subscription-Key"
    static var svcKey = ""
    
    override init() {
        super.init()
        SportsDataURLs.loadNBA()
    }
    
    static func setServiceKey(svcKey: String) {
        SportsDataService.svcKey = svcKey
    }
    
    func getServiceKey() -> String {
        return SportsDataService.svcKey
    }
    
    func getServiceKeyName() -> String {
        return Svc_Key_Name
    }
    
    func getServiceUrls() -> [SportURL] {
        return [SportURL](SportsDataURLs.URLs.values)
    }
    
    func getServiceUrls(sport: SportType, league: LeagueType) -> [SportURL] {
        var urls = [SportURL]()
        
        for url in SportsDataURLs.URLs.values {
            if (url.sport == sport.rawValue && url.league == league.rawValue) {
                urls.append(url)
            }
        }
        
        return urls
    }
    
    func getServiceUrl(urlID: String) -> SportURL {
        return SportsDataURLs.URLs[urlID]!
    }
    
}
