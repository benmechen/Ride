//
//  GroupTableViewCellBroadcast.swift
//  Ride
//
//  Created by Ben Mechen on 26/07/2019.
//  Copyright © 2019 Fuse Apps. All rights reserved.
//

import UIKit

class GroupTableViewCellBroadcast: UITableViewCell {

    var delegate: GroupTableViewCellDelegate!
    var users: [User]!
    @IBOutlet weak var send: UIButton!
    @IBOutlet weak var sendText: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    
    @IBAction func requestRide(_ sender: Any) {
        print("Clicked")
        print(users)
        if self.delegate != nil {
            self.delegate.callSegueFromCell(data: users)
        }
    }
}
