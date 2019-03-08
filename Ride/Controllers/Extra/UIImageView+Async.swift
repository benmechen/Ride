//
//  UIImage+Async.swift
//  Ride
//
//  Created by Ben Mechen on 03/08/2018.
//  Copyright © 2018 Fuse Apps. All rights reserved.
//

import Foundation
import UIKit

extension UIImageView {
    public func image(fromUrl urlString: String) {
        guard let url = URL(string: urlString) else {
            self.image = UIImage(named: "groupPlaceholder")
            return
        }
        let loadImage = URLSession.shared.dataTask(with: url) {
            data, response, error in
            if let response = data{
                DispatchQueue.main.async {
                    self.image = UIImage(data: response)
                }
            } else {
                self.image = UIImage(named: "groupPlaceholder")
            }
        }
        loadImage.resume()
    }
}
