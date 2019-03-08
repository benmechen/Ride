//
//  RequestTableViewCell.swift
//  Ride
//
//  Created by Ben Mechen on 30/12/2018.
//  Copyright © 2018 Fuse Apps. All rights reserved.
//

import UIKit

class RequestTableViewCell: UITableViewCell {

    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var location: UILabel!
    @IBOutlet weak var address: UILabel!
    @IBOutlet weak var distance: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
