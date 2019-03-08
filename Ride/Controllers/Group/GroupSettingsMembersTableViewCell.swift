//
//  GroupSettingsMembersTableViewCell.swift
//  Ride
//
//  Created by Ben Mechen on 07/10/2018.
//  Copyright © 2018 Fuse Apps. All rights reserved.
//

import UIKit

class GroupSettingsMembersTableViewCell: UITableViewCell {

    @IBOutlet weak var addConnectionName: UILabel!
    @IBOutlet weak var addConnectionPhoto: UIImageView!
    @IBOutlet weak var addConnectionCar: UILabel!
    @IBOutlet weak var memberConnectionName: UILabel!
    @IBOutlet weak var memberConnectionPhoto: UIImageView!
    @IBOutlet weak var memberConnectionCar: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Add people
        if addConnectionName != nil {
            addConnectionPhoto.layer.borderWidth = 1
            addConnectionPhoto.layer.masksToBounds = false
            addConnectionPhoto.layer.borderColor = UIColor.red.cgColor
            addConnectionPhoto.layer.cornerRadius = addConnectionPhoto.frame.height/2
            addConnectionPhoto.clipsToBounds = true
        }
        
        // Current members
        if memberConnectionName != nil {
            memberConnectionPhoto.layer.borderWidth = 1
            memberConnectionPhoto.layer.masksToBounds = false
            memberConnectionPhoto.layer.borderColor = UIColor.red.cgColor
            memberConnectionPhoto.layer.cornerRadius = memberConnectionPhoto.frame.height/2
            memberConnectionPhoto.clipsToBounds = true
        }
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
}
