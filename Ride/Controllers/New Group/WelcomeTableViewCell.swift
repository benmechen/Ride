//
//  WelcomeTableViewCell.swift
//  Ride
//
//  Created by Ben Mechen on 10/07/2018.
//  Copyright © 2018 Fuse Apps. All rights reserved.
//

import UIKit

class WelcomeTableViewCell: UITableViewCell {

    //MARK: Properties
    @IBOutlet weak var groupName: UILabel!
    @IBOutlet weak var groupImage: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        groupImage.layer.borderWidth = 1
        groupImage.layer.masksToBounds = false
        groupImage.layer.borderColor = UIColor.red.cgColor
        groupImage.layer.cornerRadius = groupImage.frame.height/2
        groupImage.clipsToBounds = true
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
