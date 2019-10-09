//
//  Discounts.swift
//  Ride
//
//  Created by Ben Mechen on 25/09/2019.
//  Copyright © 2019 Fuse Apps. All rights reserved.
//

import Foundation
import Firebase
import os.log

enum Conditions {
    case maxPrice
    case minPrice
}

class Discounts {
    static let shared = Discounts()
    
    private init() {
        
    }
    
    func shareRide(generateLinkForUser id: String, completion: @escaping ((Result<URL>) -> ())) {
        guard id.count > 0 else {
            completion(.error(DiscountsError.idInvalid))
            return
        }
        
        let RideDB = Database.database().reference()
        RideDB.child("referral").observeSingleEvent(of: .value) { (snapshot) in
            guard let link = snapshot.value as? String, let url = URL(string: link + "?invitedby=\(id)") else {
                completion(.error(DiscountsError.urlError))
                return
            }
            
            let referralLink = DynamicLinkComponents(link: url, domainURIPrefix: "https://rideapp.page.link")
            
            referralLink?.iOSParameters = DynamicLinkIOSParameters(bundleID: "com.fuse.Ride")
            referralLink?.iOSParameters?.minimumAppVersion = "2.0.0"
            referralLink?.iOSParameters?.appStoreID = "1455407107"

            referralLink?.shorten(completion: { (url, warnings, error) in
                if let error = error {
                    completion(.error(DiscountsError.shorteningError(error.localizedDescription)))
                    return
                }
                
                guard url != nil else {
                    completion(.error(DiscountsError.shorteningError("Short url was not returned")))
                    return
                }
                
                completion(.success(url!))
            })
        }
    }
    
    
}
