//
//  ServiceCallAdapter.swift
//
//  Created by Eddie Sananikone on 2/11/20.
//  Copyright © 2020 Eddie Sananikone. All rights reserved.
//

import Foundation

class ServiceCallCompletionAdapter: ServiceCallCompletionProtocol {
    
    static let DEFAULT = ServiceCallCompletionAdapter()
    
    func handle<T>(call: ServiceCall<T>) {
        let jsonString = String(data: call.data!, encoding: .utf8)!
        print("json string: \(jsonString)")
        let decoder = JSONDecoder()
        do {
            call.object = try decoder.decode((call.objectType)!, from: jsonString.data(using: .utf8)!)
        }
        catch {
            print(error)
        }
    }
    
}
