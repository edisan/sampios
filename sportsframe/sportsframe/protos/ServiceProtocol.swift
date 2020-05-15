//
//  ServiceProtocol.swift
//
//  Created by Eddie Sananikone on 2/8/20.
//  Copyright © 2020 Eddie Sananikone. All rights reserved.
//

import Foundation

protocol ServiceProtocol {
    
    func getServiceKeyName() -> String
    
    func getServiceKey() -> String
    
    func getServiceUrls() -> [SportURL]
    
    func getServiceUrls(sport: SportType, league: LeagueType) -> [SportURL]
    
    func getServiceUrl(urlID: String) -> SportURL
}
