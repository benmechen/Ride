//
//  TabViewController.swift
//  Ride
//
//  Created by Ben Mechen on 03/01/2019.
//  Copyright © 2019 Fuse Apps. All rights reserved.
//

import UIKit
import os.log
import Firebase
import Kingfisher
import Alamofire

class TabViewController: UITabBarController, WelcomeViewControllerDelegate {
    
    @IBOutlet weak var navigationBar: UINavigationItem!
    
    var userManager: UserManagerProtocol!
    lazy var RideDB = Database.database().reference()
    var profileButton: UIImageView!
    var vSpinner: UIView?
    override var canResignFirstResponder: Bool {return false}
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.vSpinner = self.showSpinner(onView: self.view)
        
        RideDB.child("stripe_customers").child(Auth.auth().currentUser!.uid).child("account_id").observeSingleEvent(of: .value, with: { snapshot in
            if let value = snapshot.value as? String, let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                appDelegate.getSecretKey(completion: { (secretKey) in
                    Alamofire.request("https://api.stripe.com/v1/accounts/\(value)", method: .get, headers: ["Authorization": "Bearer \(secretKey)"]).responseJSON(completionHandler: { response in
                        if let error = response.error {
                            print(error)
                        } else {
                            if let result = response.result.value as? NSDictionary {
                                self.RideDB.child("stripe_customers").child(Auth.auth().currentUser!.uid).child("account").setValue(result)
                                if let verification = result["verification"] as? NSDictionary {
                                    if let fieldsNeeded = verification["fields_needed"] as? NSArray {
                                        if fieldsNeeded.count > 0 {
                                            if let legalEntity = result["legal_entity"] as? NSDictionary, let legalEntityVerification = legalEntity["verification"] as? NSDictionary {
                                                if let status = legalEntityVerification["status"] as? String {
                                                    if status != "pending" {
                                                        self.removeSpinner(spinner: self.vSpinner!)
                                                        self.performSegue(withIdentifier: "showSettings", sender: nil)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    })
                })
            }
        })
        
        self.navigationController?.navigationBar.shadowImage = UIImage()
        
        //Set the left bar button to user's profile picture
        self.profileButton = UIImageView(frame: CGRect(x: 0, y: 0, width: 38, height: 38))
                
        userManager?.getCurrentUser(completion: { (success, user) in
            guard success && user != nil else {
                return
            }
            
            if self.vSpinner != nil {
                self.removeSpinner(spinner: self.vSpinner!)
            }
            
            if ((user!.car._carType == "undefined" || user!.car._carType == "") && user!.car._carMPG != "nil") {
                self.performSegue(withIdentifier: "showSetup", sender: nil)
            } else {
                if let welcomeVC = self.viewControllers?[0] as? WelcomeTableViewController {
                    welcomeVC.walkthrough()
                }
            }
            
            self.profileButton.kf.setImage(
                with: user!.photo,
                placeholder: UIImage(named: "groupPlaceholder"),
                options: [
                    .transition(.fade(1)),
                    .cacheOriginalImage
                ])
        })
        
        profileButton.backgroundColor = .white
        profileButton.layer.masksToBounds = true
        profileButton.layer.cornerRadius = profileButton.frame.height/2
        profileButton.layer.borderWidth = 1
        profileButton.layer.borderColor = UIColor(named: "Accent")?.cgColor
        profileButton.isUserInteractionEnabled = true
        let widthConstraint = profileButton.widthAnchor.constraint(equalToConstant: 38)
        let heightConstraint = profileButton.heightAnchor.constraint(equalToConstant: 38)
        heightConstraint.isActive = true
        widthConstraint.isActive = true
        profileButton.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.showSettings)))
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: profileButton)
        
        //Set navigation bar title to custom text for logo
        let rideLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 21))
        rideLabel.text = "Ride"
        rideLabel.textColor = UIColor.white
        rideLabel.textAlignment = .center
        rideLabel.font = UIFont(name: "HelveticaNeue-Light", size: 30.0)
        navigationBar.titleView = rideLabel
        
        RideDB.child("Users").child(Auth.auth().currentUser!.uid).child("requests").observeSingleEvent(of: .value, with: { snapshot in
            var count = 0
            if let value = snapshot.value as? [String: [String: [String: Any]]] {
                if let sent = value["sent"] {
                    for request in sent.keys {
                        if sent[request]!["new"] as! Bool {
                            count += 1
                        }
                    }
                }
                if let received = value["received"] {
                    for request in received.keys {
                        if received[request]!["new"] as! Bool {
                            count += 1
                        }
                    }
                }
            }
            if count > 0 {
                self.tabBar.items?[1].badgeValue = String(count)
            } else {
                self.tabBar.items?[1].badgeValue = nil
            }
            self.tabBar.items?[1].badgeColor = UIColor(named: "Accent")
        })
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        print("Preparing to segue: \(String(describing: segue.identifier))")
        
        switch(segue.identifier ?? "") {
        case "showSettings":
            let navVC = segue.destination as? UINavigationController
            if let settingsViewController = navVC?.viewControllers.first as? SettingsTableViewController {
                settingsViewController.welcomeViewControllerDelegate = self
                settingsViewController.userManager = userManager
            }
            os_log("Showing settings", log: OSLog.default, type: .debug)
        case "showCreateGroup":
            let navVC = segue.destination as? UINavigationController
            if let createGroupTableViewController = navVC?.viewControllers.first as? CreateGroupTableViewController {
                createGroupTableViewController.userManager = userManager
            }
            os_log("Showing create new group", log: OSLog.default, type: .debug)
        case "showSetup":
            let navVC = segue.destination as? UINavigationController
            if let setupViewController = navVC?.viewControllers.first as? SetupViewController, let welcomeTableViewController = self.viewControllers?[0] as? WelcomeTableViewController {
                setupViewController.welcomeTableViewController = welcomeTableViewController
                setupViewController.userManager = userManager
            }
            os_log("Showing car setup", log: OSLog.default, type: .debug)
        default:
            fatalError("Unexpected Segue Identifier; \(String(describing: segue.identifier))")
        }
    }
    
    @objc private func showSettings() {
        performSegue(withIdentifier: "showSettings", sender: self)
    }
    
    public func changeProfilePhoto(image: UIImage) {
        self.profileButton.image = image
    }
    
    public func updateWelcomeGroupName(id: String, name: String) {
//        if let group = groups.first(where: {$0._groupID == id}) {
//            group._groupName = name
//            tableView.reloadData()
//        }
    }
    
    override func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        if item == self.tabBar.items?[0] {
            self.navigationBar.rightBarButtonItem?.isEnabled = true
            self.navigationBar.rightBarButtonItem?.tintColor = .white
        } else {
            self.tabBar.items?[1].badgeValue = nil
            self.navigationBar.rightBarButtonItem?.isEnabled = false
            self.navigationBar.rightBarButtonItem?.tintColor = .clear
        }
    }
}
