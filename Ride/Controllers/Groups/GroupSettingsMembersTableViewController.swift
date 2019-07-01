//
//  GroupSettingsMembersTableViewController.swift
//  Ride
//
//  Created by Ben Mechen on 07/10/2018.
//  Copyright © 2018 Fuse Apps. All rights reserved.
//

import UIKit
import Crashlytics
import Firebase
import FacebookCore
import os.log

protocol GroupSettingsViewControllerDelegate: class {
    func updateGroup(group: Group)
}

class GroupSettingsMembersTableViewController: UITableViewController {

    @IBOutlet weak var membersCloseButton: UIBarButtonItem!
    lazy var RideDB = Database.database().reference()
    var selectedIndex: NSInteger = 0
    var connections = [String: Array<Connection>]()
    var userCount = 0
    var group: Group!
    var unconnectedUsers = [Connection]()
    var filteredUsers = [Connection]()
    var members = [Connection]()
    let searchController = UISearchController(searchResultsController: nil)
    weak var groupSettingsViewControllerDelegate: GroupSettingsViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if membersCloseButton == nil {
            //Create data model
            connections["selected"] = [Connection]()
            connections["unselected"] = [Connection]()
            
            //Search bar
            searchController.searchResultsUpdater = self
            searchController.obscuresBackgroundDuringPresentation = false
            searchController.searchBar.placeholder = "Find more users"
            UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).defaultTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
            navigationItem.searchController = searchController
            definesPresentationContext = true
            
            loadUserConnections()
        } else {
            loadGroupMembers()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if #available(iOS 11.0, *) {
            navigationItem.hidesSearchBarWhenScrolling = false
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if #available(iOS 11.0, *) {
            navigationItem.hidesSearchBarWhenScrolling = true
        }
    }
    
    // MARK: - Actions
    @IBAction func addToGroup(_ sender: Any) {
        if (connections["selected"]?.count)! > 0 {
//            let selfConnection = Connection(hostId: (Auth.auth().currentUser?.uid)!, userId: (Auth.auth().currentUser?.uid)!, name: (Auth.auth().currentUser?.displayName)!, photo: (Auth.auth().currentUser?.photoURL?.absoluteString)!, index: -1)!
            
            let newUsers = connections["selected"]!.compactMap{$0._connectionUser}
            
            group._groupMembers?.append(contentsOf: newUsers)
            
            for user in newUsers {
                RideDB.child("Groups").child("GroupUsers").child(group._groupID).child("userIDs").child(user).setValue(true)
                RideDB.child("Groups").child("UserGroups").child(user).child("groupIDs").child(group._groupID).setValue(true)
            }
            
            RideDB.child("Groups").child("GroupMeta").child(group._groupID).child("timestamp").setValue(ServerValue.timestamp())
            
            group.generateName(completion: { name in
                if let name = name {
                    self.group._groupName = name
                }
            })
            
            group.updateGroupConnections()
                
            groupSettingsViewControllerDelegate?.updateGroup(group: group)
            
            self.dismiss(animated: true)
        }
    }
    
    
    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        if membersCloseButton != nil || isFiltering() {
            return 1
        } else {
            return 2
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if membersCloseButton != nil {
            return self.userCount
        } else {
            if isFiltering() {
                return filteredUsers.count
            } else {
                if section == 0 {
                    return connections["selected"]!.count
                } else {
                    return connections["unselected"]!.count
                }
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = "GroupSettingsMembersTableViewCell"
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? GroupSettingsMembersTableViewCell else {
            fatalError("Dequeued cell is not an instance of GroupSettingsMembersTableViewCell")
        }
        
        let connection: Connection
        
        if membersCloseButton == nil {
            if isFiltering() {
                if indexPath.row < filteredUsers.count {
                    connection = filteredUsers[indexPath.row]
                    //                connections["unselected"].append(connection)
                    if (connections["unselected"]!.count < filteredUsers.count) {
                        appendToConnections(key: "unselected", object: connection)
                    }
                } else {
                    os_log("Filtering index out of range", log: OSLog.default, type: .error)
                    return cell
                }
            } else {
                switch (indexPath.section) {
                case 0:
                    connection = connections["selected"]![indexPath.row]
                default:
                    connection = connections["unselected"]![indexPath.row]
                }
            }
            
            if connection.selected {
                cell.accessoryType = .checkmark
            } else {
                cell.accessoryType = .none
            }
            
            cell.addConnectionName.text = connection._userName
            cell.addConnectionPhoto.image(fromUrl: connection._userPhoto!)
            cell.addConnectionCar.text = connection.getCarName()
            
            if isFiltering() {
                if ((connections["unselected"]?.index(of: connection)) != nil) {
                    _ = removeFromConnections(key: "unselected", index: (connections["unselected"]?.index(of: connection)!)!)
                }
            }
        } else if membersCloseButton != nil && indexPath.row < members.count {
            cell.memberConnectionName.text = members[indexPath.row]._userName
            if members[indexPath.row]._userPhoto != nil {
                cell.memberConnectionPhoto.image(fromUrl: members[indexPath.row]._userPhoto!)
            }
            if let car = members[indexPath.row]._userCar as? [String: String] {
                cell.memberConnectionCar.text = car["type"]
            }
        }
    
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        
        if membersCloseButton != nil {
            let optionMenu = UIAlertController(title: nil, message: members[indexPath.row]._userName, preferredStyle: .actionSheet)

            let removeAction = UIAlertAction(title: "Remove from group", style: .destructive, handler: {(action) -> Void in                
                self.group.removeUser(id: self.members[indexPath.row]._connectionUser)
//                self.group._groupMembers?.remove(at: indexPath.row)
                self.groupSettingsViewControllerDelegate?.updateGroup(group: self.group)

                self.members.remove(at: indexPath.row)
                
                self.userCount -= 1
                self.tableView.reloadData()
            })
            
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
            
            optionMenu.addAction(removeAction)
            optionMenu.addAction(cancelAction)
            
            self.present(optionMenu, animated: true, completion: nil)
        } else {
            if isFiltering() {
                if tableView.cellForRow(at: indexPath as IndexPath)?.accessoryType != .checkmark {
                    if filteredUsers[indexPath.row]._connectionHost != "none" {
                        filteredUsers[indexPath.row].selected = true
                        insertIntoConnections(key: "selected", index: selectedIndex, object: removeFromConnections(key: "unselected", index: indexPath.row) as! Connection)
                    } else {
                        filteredUsers[indexPath.row].selected = true
                        filteredUsers[indexPath.row].index = selectedIndex
                        insertIntoConnections(key: "selected", index: selectedIndex, object: filteredUsers[indexPath.row])
                    }
                    selectedIndex += 1
                    tableView.reloadData()
                }
            } else {
                if tableView.cellForRow(at: indexPath as IndexPath)?.accessoryType == .checkmark {
                    if connections["selected"]![indexPath.row]._connectionHost != "none" {
                        connections["selected"]![indexPath.row].selected = false
                        var newIndex = connections["selected"]![indexPath.row].index
                        if newIndex < selectedIndex {
                            newIndex = selectedIndex - 1
                        }
                        insertIntoConnections(key: "unselected", index: newIndex, object: removeFromConnections(key: "selected", index: indexPath.row) as! Connection)
                        
                    } else {
                        connections["selected"]![indexPath.row].selected = false
                        _ = removeFromConnections(key: "selected", index: indexPath.row)
                    }
                    selectedIndex -= 1
                    tableView.reloadData()
                } else {
                    connections["unselected"]![indexPath.row].selected = true
                    if indexPath.row < (connections["unselected"]?.count)! {
                        insertIntoConnections(key: "selected", index: selectedIndex, object: removeFromConnections(key: "unselected", index: indexPath.row) as! Connection)
                    } else {
                        os_log("Index out of range", log: OSLog.default, type: .error)
                    }
                    selectedIndex += 1
                    tableView.reloadData()
                }
            }
        }
    }
    
    @IBAction func cancel(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Private instance methods
    
    func isFiltering() -> Bool {
        return searchController.isActive && !searchBarIsEmpty()
    }
    
    func searchBarIsEmpty() -> Bool {
        // Returns true if the text is empty or nil
        return searchController.searchBar.text?.isEmpty ?? true
    }
    
    func filterContentForSearchText(_ searchText: String, scope: String = "All") {
        filteredUsers.removeAll()
        
        filteredUsers = (connections["unselected"]?.filter({( connection : Connection) -> Bool in
            if connection.selected == false {
                return (connection._userName?.lowercased().contains(searchText.lowercased()))!
            } else {
                return false
            }
        }))!
        
        var connectionIds: Array<String> = [(Auth.auth().currentUser?.uid)!]
        for connection in connections["unselected"]! {
            connectionIds.append(connection._connectionUser)
        }
        
        if unconnectedUsers.count == 0 {
            loadUnconnectedUsers(userIds: connectionIds, completion: { users in
                self.unconnectedUsers = users
                self.filteredUsers += self.unconnectedUsers.filter({( connection : Connection) -> Bool in
                    if connection.selected == false {
                        return (connection._userName?.lowercased().contains(searchText.lowercased()))!
                    } else {
                        return false
                    }
                })
                
                self.tableView.reloadData()
            })
        } else {
            filteredUsers += unconnectedUsers.filter({( connection : Connection) -> Bool in
                if connection.selected == false {
                    return (connection._userName?.lowercased().contains(searchText.lowercased()))!
                } else {
                    return false
                }
            })
            
            tableView.reloadData()
        }
    }
    
    // MARK: - Custom functions
    
    private func loadUserConnections() {
        let userId = Auth.auth().currentUser?.uid
        RideDB.child("Connections").child(userId!).observeSingleEvent(of: .value, with: { (snapshot) in
            let value = snapshot.value as! NSDictionary
            let usersIDs = value.allKeys as! Array<String>
            if usersIDs.count > 1 {
                for id in usersIDs {
                    if !(self.group._groupMembers!.contains(id)) {
                        self.RideDB.child("Users").child(id ).observeSingleEvent(of: .value, with: { (snapshot) in
                            guard let userValue = snapshot.value as? [String: Any] else {
                                return
                            }
                            
                            if userValue["name"] != nil && userValue["car"] != nil && userValue["photo"] != nil {
                                self.insertIntoConnections(key: "unselected", index: usersIDs.index(of: id)!, object: Connection(hostId: userId!, userId: id , name: userValue["name"] as! String, photo: userValue["photo"] as! String, car: userValue["car"] as! [String: Any], index: usersIDs.index(of: id)!)!)
                                self.tableView?.reloadData()
                            }
                        })
                    }
                }
            } else {
                os_log("No user connections", log: OSLog.default, type: .debug)
            }
        })
    }
    
    private func loadUnconnectedUsers(userIds: Array<String>, completion: @escaping (Array<Connection>)->()) {
        RideDB.child("Users").observeSingleEvent(of: .value, with: { (snapshot) in
            let users = snapshot.value as! NSMutableDictionary
            // Remove users already displayed
            for id in userIds {
                users.removeObject(forKey: id)
            }
            
            // Create a connection for each user
            var userConnections: Array<Connection> = []
            var userDetails: [String: Any]
            for user in users {
                if !(self.group._groupMembers!.contains(user.key as! String)) {
                    print("User:", user)
                    userDetails = user.value as! [String : Any]
                    
                    if userDetails["name"] != nil && userDetails["car"] != nil && userDetails["photo"] != nil {
                        let connection = Connection(hostId: "none", userId: user.key as! String, name: userDetails["name"]! as! String, photo: userDetails["photo"]! as! String, car: userDetails["car"]! as! [String: Any], index: -1)!
                        if !userConnections.contains(connection) {
                            userConnections.append(connection)
                        }
                    }
                }
            }
            
            completion(userConnections)
        })
    }
    
    private func loadGroupMembers() {
        var i = 0
        self.userCount = 0
        RideDB.child("Users").observeSingleEvent(of: .value, with: { (snapshot) in
            if let value = snapshot.value as? [String: [String: Any]] {
                for user in self.group._groupMembers! {
                    if user != Auth.auth().currentUser!.uid {
                        let userDetails = value[user]
                        
                        if userDetails != nil, let car = userDetails?["car"] as? [String: Any], userDetails?["name"] != nil, userDetails?["photo"] != nil {
                            if let connection = Connection(hostId: (Auth.auth().currentUser?.uid)!, userId: user, name: userDetails!["name"] as! String, photo: userDetails!["photo"] as! String, car: car, index: i) {
                                self.members.append(connection)
                                self.userCount += 1
                            }
                        }
                        self.tableView.reloadData()
                    }
                    i = i + 1
                }
            }
        })
    }
    
    private func appendToConnections(key: String, object: Connection) {
        if var arr = connections[key] {
            arr.append(object)
            connections[key] = arr
        }
    }
    
    private func insertIntoConnections(key: String, index: Int, object: Connection) {
        if var arr = connections[key] {
            var newIndex = index
            if index > arr.count - 1 {
                newIndex = arr.count
            }
            
            arr.insert(object, at: newIndex)
            connections[key] = arr
        }
    }
    
    private func removeFromConnections(key: String, index: Int) -> Any {
        if var arr = connections[key] {
            if (index < arr.count) {
                let element = arr.remove(at: index)
                connections[key] = arr
                return element
            }
            print("Count:", arr.count)
            print("Index:", index)
            return false
        }
        return false
    }
}

extension GroupSettingsMembersTableViewController: UISearchResultsUpdating {
    
    //MARK: UISearchResultsUpdating Updating
    func updateSearchResults(for searchController: UISearchController) {
        guard searchController.searchBar.text != nil else {
            return
        }
        filterContentForSearchText(searchController.searchBar.text!)
    }
}
