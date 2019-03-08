//
//  Group.swift
//  Ride
//
//  Created by Ben Mechen on 10/07/2018.
//  Copyright © 2018 Fuse Apps. All rights reserved.
//

import UIKit
import Crashlytics
import Firebase
import os.log
import MapKit

class Group {
    
    //MARK: Properties
    var _groupID: String!
    var _groupCreator: String!
    var _groupName: String!
    var _groupPhoto: URL?
    var _groupMembers: Array<String>?
    var _groupUsers: Array<User> = []
    var _groupTimestamp: NSDate
    var _groupAvailability: [String: Bool]
    var availableCount: Int = 0
    
    init?(id: String = "nil", name: String = "", photo: String = "gs://fuse-ride.appspot.com/GroupPhotos/groupPlaceholder.png", members: Array<String> = [], creator: String = "sys", timestamp: NSDate = NSDate(), available: [String: Bool] = [:]) {
        
        self._groupID = id
        self._groupPhoto = URL(string: photo)
        self._groupMembers = members
        self._groupName = name
        self._groupCreator = creator
        self._groupTimestamp = timestamp
        self._groupAvailability = available
        
        for user in self._groupAvailability {
            if user.value == true && user.key != currentUser!.uid {
                self.availableCount += 1
            }
        }
        
        loadUsers()
    }
    
    public func createGroup(memberNames: Array<String>, completion: @escaping (Bool?, String?)->()) {
        guard memberNames.count > 0 else {
            completion(false, "")
            return
        }
        
        if RideDB != nil {
            guard let key = RideDB?.child("Groups").child("GroupMeta").childByAutoId().key else {
                completion(false, "")
                return
            }
            
            var group: [String : Any] = ["creator": self._groupCreator,
                        "name": "",
                        "photo": self._groupPhoto?.absoluteString ?? "",
                        "timestamp": ServerValue.timestamp()]
            
            var available: [String: Bool] = [:]
            for user in self._groupMembers! {
                available[user] = false
            }
            
            group["available"] = available
            
            let childUpdates: [String : Any] = ["/Groups/GroupMeta/\(key)": group]
            
            RideDB?.updateChildValues(childUpdates, withCompletionBlock: { error, data in
                if let error = error {
                    os_log("Error updating database: %@", log: OSLog.default, type: .error, error.localizedDescription)
                    completion(false, "")
                } else {
                    self.updateGroupMembership(members: self._groupMembers!, id: key)
                    self.updateUserMembership(members: self._groupMembers!, id: key)
                    self.updateGroupConnections()
                    completion(true, key)
                }
            })
        } else {
            os_log("Failed to reach database", log: OSLog.default, type: .error)
            completion(false, "")
        }
    }

    public func generateName(completion: @escaping (String?)->()) {
        if self._groupName.isEmpty {
            self.loadMemberNames { memberNames, value in
                if memberNames.count > 0 {
                    var memberNames = memberNames
                    var groupName: String = ""

                    if let first = memberNames[0].components(separatedBy: " ").first {
                        groupName = first
                    }

                    memberNames.remove(at: 0)

                    for userName in memberNames {
                        if let first = userName.components(separatedBy: " ").first {
                            groupName = "\(groupName), \(first)"
                        }
                    }
                    
                    self._groupName = groupName
                    completion(self._groupName)
                }
            }
        } else {
            completion(self._groupName)
        }
    }
    
    public func removeUser(id: String) {
        RideDB?.child("Groups").child("GroupUsers").child(self._groupID).child("userIDs").child(id).setValue(nil)
        RideDB?.child("Groups").child("UserGroups").child(id).child("groupIDs").child(self._groupID).setValue(nil)
        RideDB?.child("Users").child(id).child("available").child(self._groupID).setValue(nil)
        
        os_log("%@ removed from group: %@", log: OSLog.default, type: .error, id, self._groupID)
    }
    
    private func loadUsers() {
        if RideDB != nil {
            RideDB?.child("Users").observe(.value, with: { (snapshot) in
                if let value = snapshot.value as? NSDictionary {
                    self._groupUsers.removeAll()
                    for user in self._groupMembers! {
                        if value[user] != nil {
                            guard var userDetails = value[user] as? [String: Any] else {
                                continue
                            }
                            
                            if userDetails["available"] == nil {
                                userDetails["available"] = [:]
                            }
                            
                            if userDetails["location"] == nil {
                                userDetails["location"] = [:]
                            }
                            
                            if userDetails["timestamp"] == nil {
                                userDetails["timestamp"] = 0.0
                            }
                            
                            if let user = User(id: user, name: userDetails["name"] as! String, photo: userDetails["photo"] as! String, car: userDetails["car"] as! [String: String], available: userDetails["available"] as! [String : Bool], location: userDetails["location"] as! [String : CLLocationDegrees], timestamp: userDetails["timestamp"] as! TimeInterval) {
                                self._groupUsers.append(user)
                            }
                        }
                    }
                }
            })
        }
    }
    
    private func loadMemberNames(completion: @escaping (Array<String>, NSDictionary)->())  {
        var memberNames: Array<String> = []
        if RideDB != nil {
            RideDB?.child("Users").observeSingleEvent(of: .value, with: { (snapshot) in
                // Get user value
                if let value = snapshot.value as? NSDictionary {
                    var groupMembers = self._groupMembers
                    let selfIndex = groupMembers?.index(of: (currentUser?.uid)!)
                    groupMembers?.remove(at: selfIndex!)
                    for member in groupMembers! {
                        if let user = value[member] as? [String: Any] {
                            memberNames.append(user["name"] as! String)
                        }
                    }
                    completion(memberNames, value)
                }
            })
        }
    }
    
    private func updateUserMembership(members: Array<String>, id: String) {
        if RideDB != nil {
            for user in members {
                RideDB?.child("Groups").child("UserGroups").child(user).child("groupIDs").child(id).setValue(true)
            }
        }
    }
    
    private func updateGroupMembership(members: Array<String>, id: String) {
        if RideDB != nil {
            for user in members {
                RideDB?.child("Groups").child("GroupUsers").child(id).child("userIDs").child(user).setValue(true)
            }
        }
    }
    
    public func updateGroupConnections() {
        for user in self._groupMembers! {
            RideDB?.child("Connections").child(user).observeSingleEvent(of: .value, with: { (snapshot) in
                if let value = snapshot.value as? NSDictionary {
                    let userIDs = value.allKeys as! Array<String>
                    for member in self._groupMembers! {
                        if !userIDs.contains(member) {
                            RideDB?.child("Connections").child(user).child(member).setValue(true)
                        }
                    }
                }
            })
        }
    }
    
}
