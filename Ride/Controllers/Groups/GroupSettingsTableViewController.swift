//
//  GroupSettingsTableViewController.swift
//  Ride
//
//  Created by Ben Mechen on 06/10/2018.
//  Copyright © 2018 Fuse Apps. All rights reserved.
//

import UIKit
import Crashlytics
import Firebase
import FacebookLogin
import FacebookCore
import Kingfisher
import Alamofire
import MapKit
import os.log

protocol GroupViewControllerDelegate: class {
    func updateGroupName(group: Group)
    func updateGroupMembers(group: Group)
}

class GroupSettingsTableViewController: UITableViewController, UITextFieldDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, GroupSettingsViewControllerDelegate {

    @IBOutlet weak var groupPhoto: UIImageView!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var memberCount: UILabel!
    @IBOutlet weak var available: UISwitch!
    
    var userManager: UserManagerProtocol!
    lazy var RideDB = Database.database().reference()
    var imagePicker = UIImagePickerController()
    var group: Group!
    var payoutsEnabled: Bool = false
    var locationManager = CLLocationManager()
    weak var groupViewControllerDelegate: GroupViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.keyboardDismissMode = .onDrag // .interactive
        tableView.tableFooterView = UIView()
        
        //Set profile picture image view
        groupPhoto.layer.borderWidth = 1
        groupPhoto.layer.masksToBounds = false
        groupPhoto.layer.borderColor = UIColor.red.cgColor
        groupPhoto.layer.cornerRadius = groupPhoto.frame.height/2
        groupPhoto.clipsToBounds = true
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(changeProfileImage(tapGestureRecognizer:)))
        groupPhoto.isUserInteractionEnabled = true
        groupPhoto.addGestureRecognizer(tapGestureRecognizer)

        groupPhoto.kf.setImage(
            with: group?._groupPhoto!,
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
        
        nameTextField.text = group?._groupName
        

        // Get members
        RideDB.child("Groups").child("GroupUsers").child(self.group!._groupID).child("userIDs").observe(.value, with: { (snapshot) in
            let value = snapshot.value as? NSDictionary
            
            if value != nil {
                self.memberCount.text = String(value!.count - 1)
            }
        })
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        userManager?.getCurrentUser(completion: { (success, user) in
            guard success && user != nil else {
                return
            }
            
            self.RideDB.child("stripe_customers").child(user!.id).child("account_id").observeSingleEvent(of: .value, with: { snapshot in
                if let value = snapshot.value as? String, let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                    appDelegate.getSecretKey(completion: { (secretKey) in
                        Alamofire.request("https://api.stripe.com/v1/accounts/\(value)", method: .get, headers: ["Authorization": "Bearer \(secretKey)"]).responseJSON(completionHandler: { response in
                            if let error = response.error {
                                print(error)
                            } else {
                                if let result = response.result.value as? NSDictionary {
                                    if let enabled = result["payouts_enabled"] as? Bool {
                                        self.payoutsEnabled = enabled
                                        if enabled {
                                            self.available.isEnabled = true
                                            if user!.available[self.group._groupID] != nil  && user!.available[self.group._groupID] == true {
                                                self.available.isOn = true
                                            } else {
                                                self.available.isOn = false
                                            }
                                        } else {
                                            self.available.isOn = false
                                        }
                                    }
                                }
                            }
                        })
                    })
                }
            })
        })
    }
    
    //MARK: - Table View
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case 3:
            if indexPath.row == 0 {
                group?.removeUser(id: Auth.auth().currentUser!.uid)
                locationManager.stopUpdatingLocation()
                moveToWelcomeController()
            }
        default:
            os_log("Section error", log: OSLog.default, type: .error)
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    
    // MARK: - Navigation
    /*
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
        case "showAddPeople":
            os_log("Showing add people to group", log: OSLog.default, type: .debug)
            
            let navVC = segue.destination as? UINavigationController
            let groupSettingsMembersViewController = navVC?.viewControllers.first as! GroupSettingsMembersTableViewController
            
            groupSettingsMembersViewController.group = group!
            groupSettingsMembersViewController.groupSettingsViewControllerDelegate = self
        case "showMembers":
            os_log("Showing group members", log: OSLog.default, type: .debug)
            
            let navVC = segue.destination as? UINavigationController
            let groupSettingsMembersViewController = navVC?.viewControllers.first as! GroupSettingsMembersTableViewController

            groupSettingsMembersViewController.group = group!
            groupSettingsMembersViewController.groupSettingsViewControllerDelegate = self
        default:
            fatalError("Unexpected Segue Identifier: \(String(describing: segue.identifier))")
        }
    }
    
    
    @IBAction func nameTextFieldReturn(_ sender: UITextField) {
        sender.resignFirstResponder()
        
        RideDB.child("Groups").child("GroupMeta").child(group!._groupID).child("name").setValue(self.nameTextField.text!)
        RideDB.child("Groups").child("GroupMeta").child(group!._groupID).child("timestamp").setValue(ServerValue.timestamp())
        
        group._groupName = self.nameTextField.text
        
        self.groupViewControllerDelegate?.updateGroupName(group: group)
        
        sender.resignFirstResponder()
        
    }
    
    @IBAction func closeSettings(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func availableSwitch(_ sender: Any) {
        if available.isOn {
            RideDB.child("Users").child((Auth.auth().currentUser?.uid)!).child("available").child(group._groupID).setValue(true)
            RideDB.child("Groups").child("GroupMeta").child(group._groupID).child("timestamp").setValue(ServerValue.timestamp())
        } else {
            RideDB.child("Users").child((Auth.auth().currentUser?.uid)!).child("available").child(group._groupID).setValue(false)
        }
    }
    
    func updateGroup(group: Group) {
        if self.group._groupName != group._groupName {
            self.groupViewControllerDelegate?.updateGroupName(group: group)
        }
        
        self.group = group
        
        nameTextField.text = self.group._groupName
        memberCount.text = String(self.group._groupMembers!.count)
        
        self.groupViewControllerDelegate?.updateGroupMembers(group: group)
    }

    @objc private func changeProfileImage(tapGestureRecognizer: UITapGestureRecognizer) {
        if UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum) {
            imagePicker.delegate = self
            imagePicker.allowsEditing = false
            
            self.present(imagePicker, animated: true, completion: nil)
        }
    }
    
    private func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        self.dismiss(animated: true, completion: { () -> Void in
            var image = info[.originalImage] as? UIImage
            
            // Crop to square
            image = image?.resize(width: 250)
            
            self.groupPhoto.image = image
            
            let profileRef = Storage.storage().reference().child("GroupPhotos/" + self.group._groupID + ".jpg")
            
            if let imageData = image?.jpeg(.lowest) {
                profileRef.putData(imageData, metadata: nil) { metadata, error in
                    profileRef.downloadURL { (url, error) in
                        guard let downloadURL = url else {
                            return
                        }
                        
                        self.RideDB.child("Groups").child("GroupMeta").child(self.group._groupID).child("photo").setValue(downloadURL.absoluteString)
                        
                        let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest()
                        changeRequest?.photoURL = downloadURL
                        changeRequest?.commitChanges { (error) in
                            if let error = error {
                                print(error)
                            }
                        }
                    }
                }
            }
        })
    }
}
