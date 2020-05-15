//
//  NBAService.swift
//
//  Created by Eddie Sananikone on 1/30/20.
//  Copyright © 2020 Eddie Sananikone. All rights reserved.
//

import Foundation


class NBAService: SportsDataService {
    
    override func getServiceUrls(sport: SportType, league: LeagueType) -> [SportURL] {
        return super.getServiceUrls(sport: .BasketBall, league: .NBA)
    }
        
    override func getPlayer(playerId: Int) -> Player? {
        let sdPlayer = sdGetPlayer(playerId: playerId)
        print(sdPlayer)
        
        return sdPlayer
    }
    
    override func getActivePlayers() -> [Player]? {
        let sdPlayers = sdGetActivePlayers()
        print(sdPlayers)
        
        return sdPlayers
    }
    
    func sdGetActivePlayers() -> [SDPlayer]? {
        let url = getServiceUrl(urlID: ActivePlayers_ID)
        let serviceCall = ServiceCall<[SDPlayer]>()
        sendGETRequest(url: url, call: serviceCall)
        
        return serviceCall.object!
    }
    
    func sdGetPlayer(playerId: Int) -> SDPlayer? {
        var url = getServiceUrl(urlID: PlayerDetails_ID)
        url.url.append("\(playerId)")
        
        let serviceCall = ServiceCall<SDPlayer>()
        sendGETRequest(url: url, call: serviceCall)
        
        return serviceCall.object!
    }
    
    private func sendGETRequest<T>(url: SportURL, call: ServiceCall<T>) {
        sendRequest(url: url, call: call, method: "GET", service: self, handler: ServiceCallCompletionAdapter.DEFAULT)
    }
    
    private func sendRequest<T>(url: SportURL, call: ServiceCall<T>, method: String, service: ServiceProtocol, handler: ServiceCallCompletionProtocol) {
        let endpoint = URL(string: url.url, relativeTo: nil)
        let urlRequest = Service.createURLRequest(url: endpoint, httpMethod: method, service: service)
        _ = Service.sendRequestSync(serviceCall: call, urlRequest: urlRequest, completionHandler: handler.handle(call:))
    }
}
