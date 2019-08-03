//
//  User.swift
//  RideTests
//
//  Created by Ben Mechen on 16/07/2019.
//  Copyright © 2019 Fuse Apps. All rights reserved.
//

import XCTest

@testable import Ride

class UserTests: XCTestCase {

    var system: UserManager!
    var user: User!
    
    override func setUp() {
        super.setUp()
        
        system = UserManager()
    }

    func testUserCompare() {
        let lhs = User(id: "123", name: "Test User", photo: URL(string: "https://www.apple.com")
            , car: Car(), available: [:], location: [:], senderId: "123", displayName: "Test User")
        let rhs = User(id: "123", name: "Test User", photo: URL(string: "https://www.apple.com")
            , car: Car(), available: [:], location: [:], senderId: "123", displayName: "Test User")
        
        XCTAssertEqual(lhs, rhs)
    }
}
