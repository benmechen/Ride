//
//  StripeClient.swift
//  Ride
//
//  Created by Ben Mechen on 15/02/2019.
//  Copyright © 2019 Fuse Apps. All rights reserved.
//

import Foundation
import Stripe
import Firebase

enum Constants {
    static let publishableKey = "pk_test_42sjKkUbpuxfYX8PTKHXMG7U"
    static let baseURLString = "YOUR_BASE_URL_STRING"
    static let defaultCurrency = "gbp"
    static let defaultDescription = "Pay your Ride driver"
}

enum Result {
    case success
    case failure(Error)
}

class StripeClient: NSObject, STPCustomerEphemeralKeyProvider {
    
    static let shared = StripeClient()
    lazy var RideDB = Database.database().reference()
    
    enum CustomerKeyError: Error {
        case missingBaseURL
        case invalidResponse
    }
    
    enum RequestRideError: Error {
        case missingBaseURL
        case invalidResponse
    }
        
    func completeCharge(_ result: STPPaymentResult, customer: String, destination: String, total: Double, user: Double, requestID: String, completion: @escaping STPErrorBlock) {
        
        let params: [String: Any] = [
            "source": result.paymentMethod.stripeId,
            "customer": customer,
            "total_amount": Int(String(format: "%.2f", total).replacingOccurrences(of: ".", with: ""))!,
            "user_amount": Int(String(format: "%.2f", user).replacingOccurrences(of: ".", with: ""))!,
            "currency": Constants.defaultCurrency,
            "destination": destination,
            "metadata": [
                "request_id": requestID
            ]
        ]
        
            
        RideDB.child("stripe_customers").child(Auth.auth().currentUser!.uid).child("charges").childByAutoId().setValue(params) { (error, ref) -> Void in
            ref.observe(.value, with: { snapshot in
                if let value = snapshot.value as? [String: Any] {
                    if snapshot.hasChild("error") {
                        completion(NSError(domain: "", code: 0, userInfo: ["description": (value["error"] as! String)]))
                    } else if snapshot.hasChild("status") {
                        if let status = value["status"] as? String {
                            if status == "succeeded" {
                                completion(nil)
                            }
                        }
                        completion(NSError(domain: "", code: 1, userInfo: ["description": "There was an error processing your payment"]))
                    }
                }
            })
        }
    }
    
    func createCustomerKey(withAPIVersion apiVersion: String, completion: @escaping STPJSONResponseCompletionBlock) {
        
        let parameters: [String: Any] = ["api_version": apiVersion]
        
        print("Parameters:", parameters)
        
        RideDB.child("stripe_customers").child(Auth.auth().currentUser!.uid).child("ephemeral_keys").removeValue()
            
        RideDB.child("stripe_customers").child(Auth.auth().currentUser!.uid).child("ephemeral_keys").setValue(parameters) { (error, ref) -> Void in
            if error != nil {
                completion(nil, CustomerKeyError.invalidResponse)
            } else {
                ref.observe(.value, with: { (snapshot) in
                    if snapshot.hasChild("id") {
                        if let value = snapshot.value as? [AnyHashable: Any] {
                            completion(value, nil)
                        }
                    }
                })
            }
        }
    }
    
}
