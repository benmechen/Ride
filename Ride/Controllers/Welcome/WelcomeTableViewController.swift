//
//  WelcomeTableViewController.swift
//  Ride
//
//  Created by Ben Mechen on 09/07/2018.
//  Copyright © 2018 Fuse Apps. All rights reserved.
//

import UIKit
import Crashlytics
import Firebase
import FacebookCore
import FacebookLogin
import os.log
import MapKit
import Kingfisher
import Alamofire


class WelcomeTableViewController: UITableViewController, CLLocationManagerDelegate, AlertOnboardingDelegate, WelcomeViewControllerDelegate {
    
    //MARK: Properties
    @IBOutlet weak var navigationBar: UINavigationItem!
    var searchController: UISearchController!
    var profileButton: UIImageView!
    var groups = [Group]()
    var payoutsEnabled: Bool = false
    var alertView: AlertOnboarding!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadUserGroups()
        
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(handleRefresh(_:)), for: UIControl.Event.valueChanged)
        self.tableView.refreshControl = refreshControl
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if mainUser == nil {
            getMainUser(welcome: false)
        }
        
        self.clearsSelectionOnViewWillAppear = true
        
        if let indexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: indexPath, animated: true)
        }
        
        RideDB?.child("stripe_customers").child(mainUser!._userID).child("account_id").observeSingleEvent(of: .value, with: { snapshot in
            if let value = snapshot.value as? String {
                Alamofire.request("https://api.stripe.com/v1/accounts/\(value)", method: .get, headers: ["Authorization": "Bearer \(secretKey)"]).responseJSON(completionHandler: { response in
                    if let error = response.error {
                        print(error)
                    } else {
                        if let result = response.result.value as? NSDictionary {
                            if let enabled = result["payouts_enabled"] as? Bool {
                                self.payoutsEnabled = enabled
                                self.tableView.reloadData()
                            }
                        }
                    }
                })
            }
        })
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func alertOnboardingCompleted() {
        RideDB?.child("Users").child(mainUser!._userID).child("walkthrough").setValue(true)
    }
    
    func alertOnboardingSkipped(_ currentStep: Int, maxStep: Int) {
        RideDB?.child("Users").child(mainUser!._userID).child("walkthrough").setValue(true)
    }
    
    func alertOnboardingNext(_ nextStep: Int) {
        // Do nothing
    }
    
    
    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return groups.count
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if mainUser!._userCar._carType != "undefined" && mainUser!._userCar._carType != "" {
            return true
        }
        
        return false
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt: IndexPath) -> [UITableViewRowAction]? {
        var available = UITableViewRowAction(style: .normal, title: "Set Ride status to available") { action, index in
            RideDB?.child("Users").child(currentUser!.uid).child("available").child(self.groups[editActionsForRowAt.row]._groupID).setValue(true)
            RideDB?.child("Groups").child("GroupMeta").child(self.groups[editActionsForRowAt.row]._groupID).child("timestamp").setValue(ServerValue.timestamp())
            RideDB?.child("Groups").child("GroupMeta").child(self.groups[editActionsForRowAt.row]._groupID).child("available").child(currentUser!.uid).setValue(true)
        }
        available.backgroundColor = rideClickableRed
        
        print("Main user available:", mainUser!._userAvailable)
        
        if !(mainUser!._userAvailable.isEmpty) {
            if mainUser!._userAvailable[groups[editActionsForRowAt.row]._groupID] != nil {
                if mainUser!._userAvailable[groups[editActionsForRowAt.row]._groupID]! as Bool == true {
                    available = UITableViewRowAction(style: .normal, title: "Set Ride status to unavailable") { action, index in
                        RideDB?.child("Users").child(currentUser!.uid).child("available").child(self.groups[editActionsForRowAt.row]._groupID).setValue(false)
                        RideDB?.child("Groups").child("GroupMeta").child(self.groups[editActionsForRowAt.row]._groupID).child("available").child(currentUser!.uid).setValue(false)
                        
                    }
                    available.backgroundColor = .lightGray
                }
            }
        }
        
        if self.payoutsEnabled {
            return [available]
        } else {
            for group in self.groups {
                RideDB?.child("Users").child(currentUser!.uid).child("available").child(group._groupID).setValue(false)
                RideDB?.child("Groups").child("GroupMeta").child(group._groupID).child("available").child(currentUser!.uid).setValue(false)
            }
        }

        return []
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = "WelcomeTableViewCell"
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? WelcomeTableViewCell else {
            fatalError("The dequeued cell is not an instance of WelcomeTableViewCell")
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        if groups.count > 0 {
            let group = groups[indexPath.row]
            
            cell.checkIfAvailable(groupID: group._groupID)
            
            group.generateName(completion: { name in
                if let name = name {
                    cell.groupName.text = name
                } else {
                    cell.groupName.text = ""
                }
            })

            if group.availableCount > 0 {
                cell.groupAvailable.text = String(group.availableCount) + " available"
//                cell.groupName.frame.origin.y = 2.0
            } else {
                cell.groupAvailable.text = ""
//                print(cell.groupName.frame.origin.y)
//                cell.groupName.frame.origin.y = 7.0
            }

            cell.groupImage.kf.setImage(
                with: group._groupPhoto!,
                placeholder: UIImage(named: "groupPlaceholder"),
                options: ([
                    .transition(.fade(1)),
                    .cacheOriginalImage
                    ] as KingfisherOptionsInfo)) { result in
                        switch result {
                        case .success(let value):
                            print("Task done for: \(value.source.url?.absoluteString ?? "")")
                        case .failure(let error):
                            os_log("Error: %@", log: OSLog.default, type: .error, error.localizedDescription)
                        }
            }
        }

        return cell
    }
    
    @objc func handleRefresh(_ refreshControl: UIRefreshControl) {
        groups.removeAll()
        loadUserGroups(refreshControl)
        
        self.tableView.reloadData()
    }
    

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        print("Preparing to segue: \(String(describing: segue.identifier))")
        
        switch(segue.identifier ?? "") {
        case "showGroup":
            os_log("Showing group", log: OSLog.default, type: .debug)
            guard let groupViewController = segue.destination as? GroupViewController else {
                os_log("Unexpected destination: %@", log: OSLog.default, type: .error, segue.destination)
                return
            }
            guard let selectedGroupController = sender as? WelcomeTableViewCell else {
                os_log("Unexpected sender: %@", log: OSLog.default, type: .error, String(describing: sender))
                return
            }
            guard let indexPath = tableView.indexPath(for: selectedGroupController) else {
                os_log("Selected cell not being displayed by table", log: OSLog.default, type: .error)
                return
            }
            
            if indexPath.row < groups.count {
                let selectedGroup = groups[indexPath.row]
                print(selectedGroup._groupUsers.count)
                groupViewController.group = selectedGroup
                groupViewController.welcomeViewControllerDelegate = self
            } else {
                os_log("Index %@ out of range %@", log: OSLog.default, type: .error, indexPath.row, groups.count)
                return
            }
        case "showSettings":
            let navVC = segue.destination as? UINavigationController
            let settingsViewController = navVC?.viewControllers.first as! SettingsTableViewController
            settingsViewController.welcomeViewControllerDelegate = self
            os_log("Showing settings", log: OSLog.default, type: .debug)
        case "showCreateGroup":
            os_log("Showing create new group", log: OSLog.default, type: .debug)
        case "showSetup":
            os_log("Showing car setup", log: OSLog.default, type: .debug)
        default:
            fatalError("Unexpected Segue Identifier; \(String(describing: segue.identifier))")
        }
    }
    
    //MARK: Custom Methods
    
    @objc private func showSettings() {
        performSegue(withIdentifier: "showSettings", sender: self)
    }
    
    public func walkthrough() {
        RideDB?.child("Users").child(mainUser!._userID).child("walkthrough").observeSingleEvent(of: .value, with: { snapshot in
            var completed = false
            
            if let value = snapshot.value as? Bool {
                if value {
                    completed = true
                }
            }
            
            if !completed {
                let arrayOfImage = ["page1", "page2", "page3"]
                let arrayOfTitle = ["CREATE GROUPS", "REQUEST RIDES", "VIEW RIDES"]
                
                self.alertView = AlertOnboarding(arrayOfImage: arrayOfImage, arrayOfTitle: arrayOfTitle, arrayOfDescription: ["", "", ""])
                self.alertView.delegate = self
                
                self.alertView.percentageRatioHeight = 0.7
                self.alertView.percentageRatioWidth = 0.8
                
                self.alertView.titleSkipButton = "SKIP"
                self.alertView.titleGotItButton = "GOT IT!"
                
                self.alertView.colorButtonText = rideClickableRed
                self.alertView.colorButtonBottomBackground = .white
                
                self.alertView.show()
            }
        })
    }
    
    public func changeProfilePhoto(image: UIImage) {
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
                if !(snapshot.value is NSNull), let value = snapshot.value as? NSDictionary {
                        let groupIDParent = value["groupIDs"]! as! NSDictionary
                        let groupIDs = groupIDParent.allKeys as? Array<String>
                    
                        if groupIDs != nil {
                            for groupID: String in groupIDs! {
                                RideDB?.child("Groups").child("GroupMeta").child(groupID).observe(.value, with: { (snapshot) in
                                    let value = snapshot.value as? NSDictionary
                                    let groupName = value?["name"] as? String ?? ""
                                    let groupPhotoURL = value?["photo"] as? String ?? ""
                                    let groupCreator = value?["creator"] as? String ?? ""
                                    let groupTimestamp = value?["timestamp"] as? TimeInterval
                                    let groupAvailability = value?["available"] as? [String: Bool] ?? [:]
                                    
                                    RideDB?.child("Groups").child("GroupUsers").child(groupID).observeSingleEvent(of: .value, with: { (snapshot) in

                                        let value = snapshot.value as! NSDictionary
                                        let userIDParent = value["userIDs"]! as! NSDictionary
                                        let userIDs = userIDParent.allKeys as? Array<String>
                                        
                                        let groupPhotoReference = RideStorage?.reference(forURL: groupPhotoURL)

                                        // Fetch the download URL
                                        groupPhotoReference?.downloadURL { url, error in
                                            if let error = error {
                                                //TODO: Handle errors
                                                // Handle any errors
                                                print("Error: \(error)")
                                            } else {
                                                guard let group = Group(id: groupID, name: groupName, photo: (url?.absoluteString)!, members: userIDs!, creator: groupCreator, timestamp: NSDate(timeIntervalSince1970: groupTimestamp!/1000), available: groupAvailability) else {
                                                    fatalError("Failed to instantiate group \(groupID)")
                                                }
                                                
                                                if let originalGroup = self.groups.index(where: { $0._groupID == group._groupID }) {
                                                    self.groups.remove(at: originalGroup)
                                                }
                                                                                                
                                                self.groups.append(group)
                                                self.groups.sort(by: { $0._groupTimestamp.compare($1._groupTimestamp as Date) == ComparisonResult.orderedDescending })

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
