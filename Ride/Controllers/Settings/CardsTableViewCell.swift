//
//  CardsTableViewCell.swift
//  Ride
//
//  Created by Ben Mechen on 16/02/2019.
//  Copyright © 2019 Fuse Apps. All rights reserved.
//

import UIKit

class CardsTableViewCell: UITableViewCell {

    @IBOutlet weak var cardTypeImage: UIImageView!
    @IBOutlet weak var cardNumber: UILabel!
    @IBOutlet weak var cardExpiry: UILabel!
    @IBOutlet weak var name: UILabel!
    @IBOutlet weak var accountNo: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
