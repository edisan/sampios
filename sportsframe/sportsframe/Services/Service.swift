//
//  Service.swift
//
//  Created by Eddie Sananikone on 1/29/20.
//  Copyright © 2020 Eddie Sananikone. All rights reserved.
//

import Foundation

final class Service {
    
    class func createURLRequest(url: URL?, httpMethod: String, service: ServiceProtocol) -> URLRequest {
        guard let requestUrl = url else { fatalError()}
        var request = URLRequest(url: requestUrl)
        request.setValue(service.getServiceKey(), forHTTPHeaderField: service.getServiceKeyName())
        request.httpMethod = httpMethod

        return request
    }
    
    class func createRequestTask(urlRequest: URLRequest, completionHandler: ((String) -> Void)?) -> URLSessionDataTask {
        let task = URLSession.shared.dataTask(with: urlRequest, completionHandler: { (data,response,error) in
            
            var responsePayload : String = ""
            
            if let data = data, let dataString = String(data: data, encoding: .utf8) {
                print("Response: \n \(dataString)")
                responsePayload = dataString
            }
            
            completionHandler!(responsePayload)
        })
        
        return task
    }
    
    class func sendRequestAsync<T>(serviceCall: ServiceCall<T>, urlRequest: URLRequest, completionHandler: ((ServiceCall<T>) -> Void)?) -> URLSessionDataTask {

        let task = URLSession.shared.dataTask(with: urlRequest, completionHandler: { (data,response,error) in
            
            serviceCall.data = data
            serviceCall.request = urlRequest
            serviceCall.response = response
            serviceCall.error = error
            
            completionHandler!(serviceCall)
        })
        
        return task
    }
    
    class func sendRequestSync<T>(serviceCall: ServiceCall<T>, urlRequest: URLRequest, completionHandler: ((ServiceCall<T>) -> Void)?) -> URLSessionDataTask {

        let sem = DispatchSemaphore(value: 0)
        
        let task = URLSession.shared.dataTask(with: urlRequest, completionHandler: { (data,response,error) in
            
            serviceCall.data = data
            serviceCall.request = urlRequest
            serviceCall.response = response
            serviceCall.error = error
            
            completionHandler!(serviceCall)
            sem.signal()
        })
        
        task.resume()
        
        _ = sem.wait(wallTimeout: .distantFuture)
        
        return task
    }
    
}
