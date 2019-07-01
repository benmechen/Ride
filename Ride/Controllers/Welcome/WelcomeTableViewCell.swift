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
    @IBOutlet weak var groupAvailable: UILabel!
    
    var userManager: UserManagerProtocol!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        groupImage.layer.borderWidth = 0
        groupImage.layer.masksToBounds = false
        groupImage.layer.cornerRadius = groupImage.frame.height/2
        groupImage.clipsToBounds = true
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func checkIfAvailable(groupID: String) {
        userManager?.getCurrentUser(completion: { (success, user) in
            guard success && user != nil else {
                return
            }
            
            if user!.available[groupID] != nil && user!.available[groupID] == true {
                self.groupImage.layer.borderWidth = 1.5
                self.groupImage.layer.borderColor = UIColor.red.cgColor
            } else {
                self.groupImage.layer.borderWidth = 0
            }
        })
    }

}
