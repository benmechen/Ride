//
//  GroupTableViewCell.swift
//  Ride
//
//  Created by Ben Mechen on 03/10/2018.
//  Copyright © 2018 Fuse Apps. All rights reserved.
//

import UIKit
import os.log

class GroupTableViewCell: UITableViewCell {

    var delegate: GroupTableViewCellDelegate!
    var user: User!
    @IBOutlet weak var requestButton: UIButton!
    @IBOutlet weak var userImage: UIImageView!
    @IBOutlet weak var userName: UILabel!
    @IBOutlet weak var userCar: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        requestButton.titleLabel?.textAlignment = NSTextAlignment.center
        requestButton.titleLabel?.textColor = rideClickableRed
        requestButton.tintColor = rideClickableRed
        requestButton.layer.borderWidth = 2
        requestButton.layer.borderColor = rideClickableRed.cgColor
        
//        userImage.layer.borderWidth = 1
//        userImage.layer.borderColor = UIColor.red.cgColor
        userImage.layer.masksToBounds = false
        userImage.layer.cornerRadius = userImage.frame.height/2
        userImage.clipsToBounds = true
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    /*override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        if segue.identifier == "requestRide" {
            os_log("Requesting ride", log: OSLog.default, type: .debug)
            guard let requestViewController = segue.destination as? RequestViewController else {
                //                print("Unexpected destination: \(segue.destination)")
                os_log("Unexpected destination: %@", log: OSLog.default, type: .error, segue.destination)
                return
            }
        }
        
        
    }*/
    @IBAction func requestRide(_ sender: Any) {
        print("Clicked")
        if self.delegate != nil {
            print("Calling delegate")
            self.delegate.callSegueFromCell(data: user)
        }
    }
    
}
