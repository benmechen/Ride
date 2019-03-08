//
//  WelcomeTableViewController.swift
//  Ride
//
//  Created by Ben Mechen on 09/07/2018.
//  Copyright © 2018 Fuse Apps. All rights reserved.
//

import UIKit
import Firebase
import FacebookCore
import FacebookLogin
import os.log


class WelcomeTableViewController: UITableViewController, WelcomeViewControllerDelegate {
    
    //MARK: Properties
    @IBOutlet weak var navigationBar: UINavigationItem!
    var searchController: UISearchController!
    var profileButton: UIImageView!
    var groups = [Group]()
    var refreshController = UIRefreshControl()

    override func viewDidLoad() {
        RideDB?.child("Users").child((currentUser?.uid)!).observeSingleEvent(of: .value, with: { (snapshot) in
            let value = snapshot.value as? NSDictionary
            let car = value!["car"] as? [String: Any]
            
            if car!["type"] != nil {
                if car!["type"] as! String == "undefined" {
                    moveToSetupController()
                }
            }
        })
        
        super.viewDidLoad()
        
        DataManager.shared.welcomeViewController = self
        
        self.tableView.addSubview(refreshController)
        refreshController.addTarget(self, action: #selector(self.refresh), for: UIControlEvents.valueChanged)
        
        //Set the right bar button to user's profile picture
        if currentUser?.photoURL != nil {
            print("Profile Download Started")
            profileButton = UIImageView(frame: CGRect(x: 0, y: 0, width: 38, height: 38))
            profileButton.image = UIImage(named: "groupPlaceholder")
            profileButton.image(fromUrl: (currentUser?.photoURL?.absoluteString)!)
            profileButton.backgroundColor = .white
            profileButton.layer.masksToBounds = true
            profileButton.layer.cornerRadius = profileButton.frame.height/2
            profileButton.layer.borderWidth = 1
            profileButton.layer.borderColor = rideClickableRed.cgColor
            profileButton.isUserInteractionEnabled = true
            let widthConstraint = profileButton.widthAnchor.constraint(equalToConstant: 38)
            let heightConstraint = profileButton.heightAnchor.constraint(equalToConstant: 38)
            heightConstraint.isActive = true
            widthConstraint.isActive = true
            profileButton.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.showSettings)))
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: profileButton)
        }
        
        //Set navigation bar title to custom text for logo
        let rideLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 21))
        rideLabel.text = "Ride"
        rideLabel.textColor = UIColor.white
        rideLabel.textAlignment = .center
        rideLabel.font = UIFont(name: "HelveticaNeue-Light", size: 30.0)
        navigationBar.titleView = rideLabel
        
        //Create search bar and add to navigation bar
        let searchController = UISearchController(searchResultsController: nil)
        navigationItem.searchController = searchController
        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).defaultTextAttributes = [NSAttributedStringKey.foregroundColor.rawValue: UIColor.white]

        
        loadUserGroups()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return groups.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = "WelcomeTableViewCell"
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? WelcomeTableViewCell else {
            fatalError("The dequeued cell is not an instance of WelcomeTableViewCell")
        }
        
        if groups.count > 0 {
            let group = groups[indexPath.row]

            group.generateName(completion: { name in
                if let name = name {
                    cell.groupName.text = name
                } else {
                    cell.groupName.text = ""
                }
            })

            cell.groupImage.image(fromUrl: group._groupPhoto!)
        }

        return cell
    }
    

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        print("Preparing to segue: \(segue.identifier)")
        
        switch(segue.identifier ?? "") {
        case "showGroup":
            print("Showing group")
            guard let groupViewController = segue.destination as? GroupViewController else {
                print("Unexpected destination: \(segue.destination)")
//                fatalError("Unexpected destination: \(segue.destination)")
                return
            }
            guard let selectedGroupController = sender as? WelcomeTableViewCell else {
                print("Unexpected sender: \(String(describing: sender))")
//                fatalError("Unexpected sender: \(String(describing: sender))")
                return
            }
            guard let indexPath = tableView.indexPath(for: selectedGroupController) else {
                print("The selected cell is not being displayed by the table")
//                fatalError("The selected cell is not being displayed by the table")
                return
            }
            
            if indexPath.row < groups.count {
                let selectedGroup = groups[indexPath.row]
                groupViewController.group = selectedGroup
                groupViewController.welcomeViewControllerDelegate = self
            } else {
                print("Index (\(indexPath.row)) out of range (\(groups.count))")
                return
            }
        case "showSettings":
//            guard let settingsViewController = segue.destination as? SettingsTableViewController else {
//                print("Unexpected destination: \(segue.destination)")
//                //                fatalError("Unexpected destination: \(segue.destination)")
//                return
//            }
//            settingsViewController.welcomeViewControllerDelegate = self
            let navVC = segue.destination as? UINavigationController
            let settingsViewController = navVC?.viewControllers.first as! SettingsTableViewController
            settingsViewController.welcomeViewControllerDelegate = self
            os_log("Showing settings", log: OSLog.default, type: .debug)
        case "showCreateGroup":
            os_log("Showing create new group", log: OSLog.default, type: .debug)
        default:
            fatalError("Unexpected Segue Identifier; \(String(describing: segue.identifier))")
        }
    }
    
    //MARK: Custom Methods
    @objc public func refresh(_ sender: UIRefreshControl) {
        print("Refreshing...")
        groups.removeAll()
        loadUserGroups(sender)
        print("Refreshed")
    }
    
    @objc private func showSettings() {
        performSegue(withIdentifier: "showSettings", sender: self)
    }
    
    public func changeProfilePhoto(image: UIImage) {
        print("Changing photo")
        
        self.profileButton.image = image
    }
    
    public func updateWelcomeGroupName(id: String, name: String) {
        if let group = groups.first(where: {$0._groupID == id}) {
            group._groupName = name
            tableView.reloadData()
        }
    }
    
    public func loadUserGroups(_ sender: UIRefreshControl = UIRefreshControl()){
        groups = [Group]()
        let userID = currentUser?.uid
        if RideDB != nil {
            RideDB?.child("Groups").child("UserGroups").child(userID!).observe(.value, with: { (snapshot) in
                if !(snapshot.value is NSNull) {
                        let value = snapshot.value as! NSDictionary
                        let groupIDParent = value["groupIDs"]! as! NSDictionary
                        let groupIDs = groupIDParent.allKeys as? Array<String>
                    
                        if groupIDs != nil {
                            for groupID: String in groupIDs! {
                                print("Group ID:", groupID)
                                RideDB?.child("Groups").child("GroupMeta").child(groupID).observe(.value, with: { (snapshot) in
                                    let value = snapshot.value as? NSDictionary
                                    let groupName = value?["name"] as? String ?? ""
                                    let groupPhotoURL = value?["photo"] as? String ?? ""
                                    let groupCreator = value?["creator"] as? String ?? ""
                                    let groupTimestamp = value?["timestamp"] as? TimeInterval
                                    
                                    RideDB?.child("Groups").child("GroupUsers").child(groupID).observeSingleEvent(of: .value, with: { (snapshot) in

                                        let value = snapshot.value as! NSDictionary
                                        let userIDParent = value["userIDs"]! as! NSDictionary
                                        let userIDs = userIDParent.allKeys as? Array<String>
                                        
                                        print("User IDs:", userIDs)
                                        
                                        let groupPhotoReference = RideStorage?.reference(forURL: groupPhotoURL)

                                        // Fetch the download URL
                                        groupPhotoReference?.downloadURL { url, error in
                                            if let error = error {
                                                //TODO: Handle errors
                                                // Handle any errors
                                                print("Error: \(error)")
                                            } else {
                                                guard let group = Group(id: groupID, name: groupName, photo: (url?.absoluteString)!, members: userIDs!, creator: groupCreator, timestamp: NSDate(timeIntervalSince1970: groupTimestamp!/1000)) else {
                                                    fatalError("Failed to instantiate group \(groupID)")
                                                }
                                                print("Group photo downloaded")
                                                
                                                if let originalGroup = self.groups.index(where: { $0._groupID == group._groupID }) {
                                                    self.groups.remove(at: originalGroup)
                                                }
                                                self.groups.append(group)
                                                self.groups.sort(by: { $0._groupTimestamp.compare($1._groupTimestamp as Date) == ComparisonResult.orderedDescending })
                                                print("Reloading table")
                                                sender.endRefreshing()
                                                self.tableView?.reloadData()
                                            }
                                        }
                                    })
                                })
                            }
                        } else {
                            sender.endRefreshing()
                        }
                    } else {
                        sender.endRefreshing()
                    }
                })
        } else {
            os_log("Failed to reach database", log: OSLog.default, type: .error)
        }
    }
}
