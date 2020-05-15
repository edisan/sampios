//
//  NBAFacade.swift
//
//  Created by Eddie Sananikone on 2/9/20.
//  Copyright © 2020 Eddie Sananikone. All rights reserved.
//

import Foundation

public class NBAFacade {

    static let NBA = NBAService()
        
    public static func getPlayer(playerId: Int) -> Player {
        return NBA.getPlayer(playerId: playerId)!
    }
    
    public static func getActivePlayers() {
        NBA.getActivePlayers()
    }
        
}
