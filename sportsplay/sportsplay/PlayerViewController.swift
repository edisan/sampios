//
//  PlayerViewController.swift
//
//  Created by Eddie Sananikone on 5/10/20.
//  Copyright © 2020 Eddie Sananikone. All rights reserved.
//

import UIKit
import Foundation

import sportsframe

class PlayerViewController: UIViewController {
    
    /**
     * UI Views
     */
    @IBOutlet weak var thumbView: UIImageView!    
    
    /**
     * UI Labels
     */
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var positionLabel: UILabel!
    @IBOutlet weak var dobLabel: UILabel!
    @IBOutlet weak var playerIDTextField: UITextField!
    @IBOutlet weak var loadButton: UIButton!
    
    /**
     * Player ID to get information for
     */
    private var playerID: Int = -1
    
    /**
     * Handle load button click to call API to get Player info
     */
    @IBAction func getPlayerInfo(_ loadButton: UIButton) {
        let player = NBAFacade.getPlayer(playerId: Int(playerIDTextField.text!)!)
        
        DispatchQueue.main.async {
            self.nameLabel.text = player.FirstName! + player.LastName!
            self.positionLabel.text = player.Position
            self.dobLabel.text = player.BirthDate
            
            let url = URL(string: player.PhotoUrl!)
            let data = try? Data(contentsOf: url!)
            self.thumbView.image = UIImage(data: data!)
        }
    }
}
