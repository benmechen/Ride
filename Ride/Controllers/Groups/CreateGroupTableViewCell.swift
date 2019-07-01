//
//  CreateGroupTableViewCell.swift
//  Ride
//
//  Created by Ben Mechen on 18/07/2018.
//  Copyright © 2018 Fuse Apps. All rights reserved.
//

import UIKit

class CreateGroupTableViewCell: UITableViewCell {

    @IBOutlet weak var connectionName: UILabel!
    @IBOutlet weak var connectionPhoto: UIImageView!
    @IBOutlet weak var connectionCar: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        connectionPhoto.layer.borderWidth = 1
        connectionPhoto.layer.masksToBounds = false
        connectionPhoto.layer.borderColor = UIColor.red.cgColor
        connectionPhoto.layer.cornerRadius = connectionPhoto.frame.height/2
        connectionPhoto.clipsToBounds = true
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
