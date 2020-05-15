//
//  Person.swift
//
//  Created by Eddie Sananikone on 1/29/20.
//  Copyright © 2020 Eddie Sananikone. All rights reserved.
//

import Foundation

public protocol Person: Codable {
    
    var FirstName : String? { get set }
    var LastName : String? { get set }
    var BirthDate: String? { get set }
    var Height : Int? { get set } // cm
    var Weight: Int? { get set } // kg
    
    var BirthCity: String? { get set }
    var BirthState: String? { get set }
    var BirthCountry: String? { get set }
    var HighSchool: String? { get set }
    var College: String? { get set }
    var Salary: Int? { get set }
    
}
