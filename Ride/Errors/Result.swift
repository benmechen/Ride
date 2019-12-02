//
//  Result.swift
//  Ride
//
//  Created by Ben Mechen on 28/11/2019.
//  Copyright © 2019 Fuse Apps. All rights reserved.
//

import Foundation

enum Result<T> {
  case success(T)
  case error(Error)
}
