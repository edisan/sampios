//
//  Player.swift
//
//  Created by Eddie Sananikone on 1/29/20.
//  Copyright © 2020 Eddie Sananikone. All rights reserved.
//

import Foundation

public protocol Player: Personnel {
    
    var PlayerID: Int? { get set }
    var Status: String? { get set }
    var TeamID: Int? { get set }
    var Team: String? { get set }
    var Jersey: Int? { get set }
    var PositionCategory: String? { get set }
    var Position: String? { get set }
    
    var Experience: Int? { get set }
    
    var InjuryStatus: String? { get set }
    var InjuryBodyPart: String? { get set }
    var InjuryStartDate: String? { get set }
    var InjuryNotes: String? { get set }
    
    var PhotoUrl: String? { get set }
}
