//
//  ServiceCallProtocol.swift
//
//  Created by Eddie Sananikone on 2/9/20.
//  Copyright © 2020 Eddie Sananikone. All rights reserved.
//

import Foundation

protocol ServiceCallCompletionProtocol {
    
    func handle<T>(call: ServiceCall<T>)
    
    
}
