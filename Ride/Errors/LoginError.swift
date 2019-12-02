//
//  LoginError.swift
//  Ride
//
//  Created by Ben Mechen on 28/11/2019.
//  Copyright © 2019 Fuse Apps. All rights reserved.
//

import Foundation

enum LoginError: Error {
    // Login service returned failure state
    case loginServiceFail(String)
    // Login canceled by user
    case loginServiceCanceled
    // Login service unknown failure
    case loginServiceUnknownFailure
    // User id is not set
    case loginIDNotSet
    // New user id not set
    case newUserIDNotSet
    // New user name not set
    case newUserNameNotSet
    // New user photo not set
    case newUserPhotoNotSet
    // New user car not set
    case newUserCarNotSet
    // Inviter's id is not set
    case newUserInvitedByNotSet
    // Facebook graph request failed
    case facebookGraphRequestFailed(Error?)
}
