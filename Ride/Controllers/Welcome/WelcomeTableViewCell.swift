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
        if mainUser?._userAvailable[groupID] != nil && mainUser?._userAvailable[groupID] == true {
            self.groupImage.layer.borderWidth = 1.5
            self.groupImage.layer.borderColor = UIColor.red.cgColor
        } else {
            self.groupImage.layer.borderWidth = 0
        }

        
        
        //        RideDB?.child("Users").child(currentUser!.uid).observeSingleEvent(with: .value, with: { (snapshot) in
//            if !(snapshot.value is NSNull) {
//                let value = snapshot.value as! NSDictionary
//
//                let availableList = value["available"] as? [String: Bool] ?? [:]
//
//                if availableList[groupID] != nil && availableList[groupID] == true {
//                    self.groupImage.layer.borderWidth = 1.5
//                    self.groupImage.layer.borderColor = UIColor.red.cgColor
//                } else {
//                    self.groupImage.layer.borderWidth = 0
//                }
//            }
//        })
    }

}
