//
//  Errors.swift
//  Ride
//
//  Created by Ben Mechen on 04/10/2019.
//  Copyright © 2019 Fuse Apps. All rights reserved.
//

import Foundation

enum Result<T> {
  case success(T)
  case error(Error)
}

enum DiscountError: Error {
  // Invalid discount code string used
  case invalidCode
  // Invalid price given
  case invalidPrice
  // Unable to retrieve & format data from database
  case databaseError
  // Code is dependent on a condition being met
  case conditionalCode(String)
  // Code is expired
  case codeExpired
  // Other error
  case error
}

enum DiscountsError: Error {
    // Supplied ID is not valid
    case idInvalid
    // Error shortening the URL - returns error localized description
    case shorteningError(String)
    // Error creating URL
    case urlError
}
