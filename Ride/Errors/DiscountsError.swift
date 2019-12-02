//
//  DiscountsError.swift
//  Ride
//
//  Created by Ben Mechen on 28/11/2019.
//  Copyright © 2019 Fuse Apps. All rights reserved.
//

import Foundation

enum DiscountsError: Error {
    // Supplied ID is not valid
    case idInvalid
    // Error shortening the URL - returns error localized description
    case shorteningError(String)
    // Error creating URL
    case urlError
}
