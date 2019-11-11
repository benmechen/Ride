//
//  CreateGroupTableViewController.swift
//  Ride
//
//  Created by Ben Mechen on 10/07/2018.
//  Copyright © 2018 Fuse Apps. All rights reserved.
//

import UIKit
import Crashlytics
import Firebase
import FacebookCore
import os.log

class CreateGroupTableViewController: UITableViewController {
    
    var userManager: UserManagerProtocol!
    lazy var RideDB = Database.database().reference()
    var selectedIndex: NSInteger = 0
    var connections = [String: Array<Connection>]()
    var unconnectedUsers = [Connection]()
    var filteredUsers = [Connection]()
    let searchController = UISearchController(searchResultsController: nil)
    var paymentMode: Bool = false
    var driver: String = ""
    var paymentDelegate: PaymentDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Search bar
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Find more users"
        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).defaultTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]

        navigationItem.searchController = searchController
        definesPresentationContext = true
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            
            var hue: CGFloat = 0
            var saturation: CGFloat = 0
            var brightness: CGFloat = 0
            var alpha: CGFloat = 0
            
            UIColor(named: "Main")?.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
            if traitCollection.userInterfaceStyle == .dark {
                appearance.backgroundColor = UIColor(hue: hue, saturation: saturation - 0.1, brightness: brightness - 0.08, alpha: alpha)
            } else {
                appearance.backgroundColor = UIColor(hue: hue, saturation: saturation - 0.2, brightness: brightness + 0.08, alpha: alpha)
            }
            
            appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]

            navigationController?.navigationBar.standardAppearance = .init(barAppearance: appearance)
            navigationController?.navigationBar.scrollEdgeAppearance = navigationController?.navigationBar.standardAppearance
            navigationController?.navigationBar.barTintColor = UIColor(named: "Main")
        }
        
        if self.connections.count == 0 {
            //Create data model
            connections["selected"] = [Connection]()
            connections["unselected"] = [Connection]()
            loadUserConnections()
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
    @IBAction func createGroup(_ sender: Any) {
        if self.paymentMode {
            self.paymentDelegate?.addUsers(users: self.connections)
            self.dismiss(animated: true, completion: nil)
        } else {
            if (connections["selected"]?.count)! > 0 {
                let selfConnection = Connection(hostId: (Auth.auth().currentUser?.uid)!, userId: (Auth.auth().currentUser?.uid)!, name: (Auth.auth().currentUser?.displayName)!, photo: (Auth.auth().currentUser?.photoURL?.absoluteString)!, index: -1)!
                
                var selectedConnections: Array<Connection> = []
                if var arr = connections["selected"] {
                    arr.append(selfConnection)
                    selectedConnections = arr
                }
                let newGroup = Group(members: (selectedConnections.compactMap{$0._connectionUser}), creator: (Auth.auth().currentUser?.uid)!, userManager!)
                newGroup?.createGroup(memberNames: (selectedConnections.compactMap{$0._userName}), completion: { status, id in
                    if status == true {
                        self.dismiss(animated: true, completion: nil)
                        DataManager.shared.welcomeViewController.loadUserGroups()
                        DataManager.shared.welcomeViewController.tableView.reloadData()
                        DataManager.shared.welcomeViewController.userManager = self.userManager
                    }
                })
            } else {
                let alert = UIAlertController(title: "Please select members", message: "", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: { _ in
                    os_log("Group selection empty", log: OSLog.default, type: .debug)
                }))
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    

    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        if isFiltering() {
            return 1
        } else {
            return 2
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
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

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = "CreateGroupTableViewCell"
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? CreateGroupTableViewCell else {
            fatalError("Dequeued cell is not an instance of CreateGroupTableViewCell")
        }
        
        let connection: Connection
        
        if isFiltering() {
            if indexPath.row < filteredUsers.count {
                connection = filteredUsers[indexPath.row]
//                connections["unselected"].append(connection)
                appendToConnections(key: "unselected", object: connection)
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
                
        cell.connectionName.text = connection._userName
        cell.connectionPhoto.image(fromUrl: connection._userPhoto!)
        cell.connectionCar.text = connection.getCarName()
        
        if isFiltering() {
            _ = removeFromConnections(key: "unselected", index: (connections["unselected"]?.index(of: connection)!)!)
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        if isFiltering() {
            if tableView.cellForRow(at: indexPath as IndexPath)?.accessoryType != .checkmark {
                if filteredUsers[indexPath.row]._connectionHost != "none" {
                    filteredUsers[indexPath.row].selected = true
                    if let connection = removeFromConnections(key: "unselected", index: filteredUsers[indexPath.row].index) as? Connection {
                        insertIntoConnections(key: "selected", index: selectedIndex, object: connection)
                    } else {
                        return
                    }
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
                print(indexPath.row)
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
        guard let userId = Auth.auth().currentUser?.uid else {
            return
        }
        
        RideDB.child("Connections").child(userId).observeSingleEvent(of: .value, with: { (snapshot) in
            if let dictionary = snapshot.value as? NSDictionary, var value = dictionary.allKeys as? Array<String> {
                if value.count > 1 {
                    if let index = value.index(of: Auth.auth().currentUser!.uid) {
                        value.remove(at: index)
                    }
                    if let index = value.index(of: self.driver) {
                        value.remove(at: index)
                    }
                    for id in value {
                        if id != Auth.auth().currentUser!.uid && id != self.driver {
                            self.userManager.fetch(byID: id, completion: { (success, user) in
                                guard success, user != nil else {
                                    return
                                }
                                                                
                                self.insertIntoConnections(key: "unselected", index: value.index(of: id)!, object: Connection(hostId: userId, userId: id , name: user!.name, photo: user!.photo.absoluteString, car: ["type": user!.car._carType, "mpg": user!.car._carMPG, "seats": user!.car._carSeats, "registration": user!.car._carRegistration], index: value.index(of: id)!)!)
                                self.tableView?.reloadData()
                            })
                            
//                            self.RideDB.child("Users").child(id).observeSingleEvent(of: .value, with: { (snapshot) in
//                                guard let userValue = snapshot.value as? [String: Any] else {
//                                    return
//                                }
//                                
//                                if userValue["name"] != nil && userValue["car"] != nil && userValue["photo"] != nil {
//                                    self.insertIntoConnections(key: "unselected", index: value.index(of: id)!, object: Connection(hostId: userId!, userId: id , name: userValue["name"] as! String, photo: userValue["photo"] as! String, car: userValue["car"] as! [String: Any], index: value.index(of: id)!)!)
//    //                                self.connections["unselected"].insert(Connection(hostId: userId!, userId: id as! String, name: userValue["name"]!, photo: userValue["photo"]!, car: userValue["car"]!, index: value.index(of: id))!, at: value.index(of: id))
//                                    self.tableView?.reloadData()
//                                }
//                            })
                        }
                    }
                } else {
                    os_log("No user connections", log: OSLog.default, type: .debug)
                }
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
            
            if users.value(forKey: (Auth.auth().currentUser?.uid)!) != nil {
                users.removeObject(forKey: Auth.auth().currentUser?.uid as Any)
            }
            
            // Create a connection for each user
            var userConnections: Array<Connection> = []
            var userDetails: [String: Any]
            for user in users {
                userDetails = user.value as! [String : Any]
                
                if userDetails["name"] != nil && userDetails["car"] != nil && userDetails["photo"] != nil {
                    let connection = Connection(hostId: "none", userId: user.key as! String, name: userDetails["name"]! as! String, photo: userDetails["photo"]! as! String, car: userDetails["car"]! as! [String: Any], index: -1)!
                    if !userConnections.contains(connection) {
                        userConnections.append(connection)
                    }
                }
            }
            
            completion(userConnections)
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
            
            if newIndex >= 0 {
                arr.insert(object, at: newIndex)
                connections[key] = arr
            } else {
                connections[key]?.append(object)
            }
        }
    }
    
    private func removeFromConnections(key: String, index: Int) -> Any {
        if var arr = connections[key], index < arr.count {
            let element = arr.remove(at: index)
            connections[key] = arr
            return element
        }
        return false
    }
}

extension CreateGroupTableViewController: UISearchResultsUpdating {
    
    //MARK: UISearchResultsUpdating Updating
    func updateSearchResults(for searchController: UISearchController) {
        filterContentForSearchText(searchController.searchBar.text!)

    }
}
