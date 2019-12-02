//
//  DiscountError.swift
//  Ride
//
//  Created by Ben Mechen on 28/11/2019.
//  Copyright © 2019 Fuse Apps. All rights reserved.
//

import Foundation

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
