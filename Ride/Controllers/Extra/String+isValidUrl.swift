//
//  String+isValidUrl.swift
//  Ride
//
//  Created by Ben Mechen on 01/12/2019.
//  Copyright © 2019 Fuse Apps. All rights reserved.
//

import Foundation

extension String {
    var isValidURL: Bool {
        let urlRegEx = "^(https?://)?(www\\.)?([-a-z0-9]{1,63}\\.)*?[a-z0-9][-a-z0-9]{0,61}[a-z0-9]\\.[a-z]{2,6}(/[-\\w@\\+\\.~#\\?&/=%]*)?$"
        let urlTest = NSPredicate(format:"SELF MATCHES %@", urlRegEx)
        let result = urlTest.evaluate(with: self)
        return result
    }
}
