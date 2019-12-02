//
//  LoginService.swift
//  Ride
//
//  Created by Ben Mechen on 23/11/2019.
//  Copyright © 2019 Fuse Apps. All rights reserved.
//

import Foundation
import FacebookCore
import FacebookLogin
import Firebase


enum LoginServices {
    case facebook
    case apple
}

class LoginService {
    class var shared: LoginService { get { return LoginService() } }
    weak var RideDB = Database.database().reference()
    
    func addUserToLookup(withID id: String, internalID: String) -> Bool {
        guard id.count > 0 else {
            return false
        }
        
        RideDB?.child("IDs").child(id).setValue(internalID)
        
        return true
    }
    
    func checkUserExists(_ id: String, completion: @escaping ((Bool) -> ())) {
        RideDB?.child("Users").child(id).observeSingleEvent(of: .value) { snapshot in
            completion(snapshot.exists())
        }
    }
    
    func addUserDetails(id: String, name: String, photo: String, car: [String: String]) -> Result<Bool> {
        guard id.count > 0 else {return .error(LoginError.newUserIDNotSet)}
        guard name.count > 0 else {return .error(LoginError.newUserNameNotSet)}
        guard photo.count > 0 && photo.isValidURL else {return .error(LoginError.newUserPhotoNotSet)}
        guard car.count == 4 && (car["type"] == "" && car["mpg"] == "" && car["seats"] == "" && car["registration"] == "") else {return .error(LoginError.newUserCarNotSet)}
                
        RideDB?.child("Users").child(id).setValue([
        "name": name,
        "photo": photo,
        "car": car
        ] as [String : Any])
        
        return .success(true)
    }
    
    func connectUsers(_ user1: String, _ user2: String) {
        RideDB?.child("Connections").child(user1).child(user2).setValue(true)
        RideDB?.child("Connections").child(user2).child(user1).setValue(true)
    }
}

class FacebookLoginService: LoginService  {
    override class var shared: FacebookLoginService { get { return FacebookLoginService() } }
    let loginManager = LoginManager()
    
    let accessToken = {
        return AccessToken.current
    }
    
    func login(viewController: UIViewController, completion: @escaping ((Result<AuthCredential>) -> ())) {
        loginManager.logIn(permissions: [.publicProfile, .userFriends], viewController: viewController) { (result) in
            switch result {
            case .failed(let error):
                completion(.error(LoginError.loginServiceFail(error.localizedDescription)))
            case .cancelled:
                completion(.error(LoginError.loginServiceCanceled))
            case .success(granted: _, declined: _, token: let accessToken):
                let authCredential = FacebookAuthProvider.credential(withAccessToken: accessToken.tokenString)
                
                completion(.success(authCredential))
            }
        }
    }
    
    func fetchFriends(forUser id: String, completion: @escaping (Result<Array<String>>) -> ()) {
        guard id.count > 0 else {
            completion(.error(LoginError.newUserIDNotSet))
            return
        }
        
        let connection = GraphRequestConnection()

        
        connection.add(GraphRequest(graphPath: "/me/friends"), batchParameters: ["fields": "id"]) { (response, result, error) in
            guard error == nil else {
                completion(.error(LoginError.facebookGraphRequestFailed(error!)))
                return
            }
            
            guard let resultDict = result as? [String: Any], let data = resultDict["data"] as? [[String: String]] else {
                completion(.error(LoginError.facebookGraphRequestFailed(nil)))
                return
            }
            var friends: [String] = []
            var count = 1
            
            for user in data {
                if let id = user["id"] {
                    self.checkFacebookUserExists(id) { rideID in
                        if rideID != nil {
                            friends.append(rideID!)
                        }
                        
                        if count == data.count {
                            completion(.success(friends))
                        }
                        
                        count += 1
                    }
                }
            }
        }
    }
    
    private func checkFacebookUserExists(_ id: String, completion: @escaping ((String?) -> ())) {
        RideDB?.child("IDs").child(id).observeSingleEvent(of: .value) { snapshot in
            if snapshot.exists(), let rideID = snapshot.value as? String {
                completion(rideID)
            }
            completion(nil)
        }
    }
}

//class AppleLoginService: LoginService {
//    func login(viewController: UIViewController, completion: @escaping ((Result<Bool>) -> ())) {
//        <#code#>
//    }
//
//
//}
