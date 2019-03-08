//
//  RequestsTableViewCell.swift
//  Ride
//
//  Created by Ben Mechen on 05/01/2019.
//  Copyright © 2019 Fuse Apps. All rights reserved.
//

import UIKit

class RequestsTableViewCell: UITableViewCell {
    @IBOutlet weak var profileImage: UIImageView!
    @IBOutlet weak var name: UILabel!
    @IBOutlet weak var start: UILabel!
    @IBOutlet weak var end: UILabel!
    @IBOutlet weak var people: UILabel!
    @IBOutlet weak var from: UILabel!
    @IBOutlet weak var to: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        profileImage.layer.borderWidth = 0
        profileImage.layer.masksToBounds = false
        profileImage.layer.cornerRadius = profileImage.frame.height/2
        profileImage.clipsToBounds = true
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
