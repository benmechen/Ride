//
//  TabViewController.swift
//  Ride
//
//  Created by Ben Mechen on 03/01/2019.
//  Copyright © 2019 Fuse Apps. All rights reserved.
//

import UIKit
import os.log
import Kingfisher

class TabViewController: UITabBarController, WelcomeViewControllerDelegate {
    
    @IBOutlet weak var navigationBar: UINavigationItem!
    
    var profileButton: UIImageView!
    
    override func viewDidLoad() {
        guard mainUser != nil else {
            moveToLoginController()
            return
        }
        
        if ((mainUser!._userCar._carType == "undefined" || mainUser!._userCar._carType == "") && mainUser?._userCar._carMPG != "nil") {
            self.performSegue(withIdentifier: "showSetup", sender: nil)
        } else {
            if let welcomeVC = self.viewControllers?[0] as? WelcomeTableViewController {
                welcomeVC.walkthrough()
            }
        }
    
        super.viewDidLoad()
        
        navigationController?.navigationBar.shadowImage = UIImage()
        
        //Set the right bar button to user's profile picture
        profileButton = UIImageView(frame: CGRect(x: 0, y: 0, width: 38, height: 38))
        
        profileButton.kf.setImage(
            with: mainUser?._userPhotoURL,
            placeholder: UIImage(named: "groupPlaceholder"),
            options: [
                .transition(.fade(1)),
                .cacheOriginalImage
            ])
        
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
        //        }
        
        //Set navigation bar title to custom text for logo
        let rideLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 21))
        rideLabel.text = "Ride"
        rideLabel.textColor = UIColor.white
        rideLabel.textAlignment = .center
        rideLabel.font = UIFont(name: "HelveticaNeue-Light", size: 30.0)
        navigationBar.titleView = rideLabel
        
        RideDB?.child("Users").child(mainUser!._userID).child("requests").observeSingleEvent(of: .value, with: { snapshot in
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
            self.tabBar.items?[1].badgeColor = rideClickableRed
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
            }
            os_log("Showing settings", log: OSLog.default, type: .debug)
        case "showCreateGroup":
            os_log("Showing create new group", log: OSLog.default, type: .debug)
        case "showSetup":
            let navVC = segue.destination as? UINavigationController
            if let setupViewController = navVC?.viewControllers.first as? SetupViewController, let welcomeTableViewController = self.viewControllers?[0] as? WelcomeTableViewController {
                setupViewController.welcomeTableViewController = welcomeTableViewController
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
        if self.navigationBar.rightBarButtonItem!.isEnabled {
           self.navigationBar.rightBarButtonItem?.isEnabled = false
           self.navigationBar.rightBarButtonItem?.tintColor = .clear
        } else {
            self.navigationBar.rightBarButtonItem?.isEnabled = true
            self.navigationBar.rightBarButtonItem?.tintColor = .white
        }
    }
}
