//
//  PlayerProtocol.swift
//
//  Created by Eddie Sananikone on 1/31/20.
//  Copyright © 2020 Eddie Sananikone. All rights reserved.
//

import Foundation

protocol PlayerProtocol {
    
    func getPlayer(playerId: Int) -> Player?
    func getActivePlayers() -> [Player]?
    
}
