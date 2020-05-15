//
//  ServiceCall.swift
//
//  Created by Eddie Sananikone on 2/9/20.
//  Copyright © 2020 Eddie Sananikone. All rights reserved.
//

import Foundation

class ServiceCall<T: Codable>{
    
    var data: Data?
    var request: URLRequest?
    var response: URLResponse?
    var error: Error?
    var object: T?
    var objectType: T.Type?
    
    init() {
        objectType = T.self
    }
}
