//
//  SettingsTableViewController.swift
//  Ride
//
//  Created by Ben Mechen on 10/07/2018.
//  Copyright © 2018 Fuse Apps. All rights reserved.
//

import UIKit
import Firebase
import Stripe
import Crashlytics
import FacebookLogin
import FacebookCore
import Kingfisher
import MessageUI
import os.log

protocol WelcomeViewControllerDelegate: class {
    func changeProfilePhoto(image: UIImage)
    func updateWelcomeGroupName(id: String, name: String)
}

class SettingsTableViewController: UITableViewController, UITextFieldDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIPickerViewDataSource, UIPickerViewDelegate, MFMailComposeViewControllerDelegate {

    @IBOutlet weak var profilePhoto: UIImageView!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var carTypeDetail: UILabel!
    @IBOutlet weak var carMPGDetail: UILabel!
    @IBOutlet weak var carSeatsDetail: UILabel!
    @IBOutlet weak var carRegistrationDetail: UILabel!
    @IBOutlet weak var carTypeTextField: UITextField!
    @IBOutlet weak var carMPGTextField: UITextField!
    @IBOutlet weak var carSeatsTextField: UITextField!
    @IBOutlet weak var carRegistrationTextField: UITextField!
    @IBOutlet weak var contactCell: UITableViewCell!

    
    weak var welcomeViewControllerDelegate: WelcomeViewControllerDelegate?
    var imagePicker = UIImagePickerController()
    var selectedType: String?
    var carTypes = ["Hatchback", "Estate", "SUV", "Saloon", "Coupe", "MPV", "Convertible", "Pick Up", "Other"]
    var handle: UInt? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard mainUser != nil else {
            moveToLoginController()
            return
        }
        
        tableView.keyboardDismissMode = .onDrag // .interactive
        tableView.tableFooterView = UIView()
            
        
        // Main settings page
        if profilePhoto != nil {
            //Set profile picture image view
            profilePhoto.layer.borderWidth = 1
            profilePhoto.layer.masksToBounds = false
            profilePhoto.layer.borderColor = UIColor.red.cgColor
            profilePhoto.layer.cornerRadius = profilePhoto.frame.height/2
            profilePhoto.clipsToBounds = true
            
            let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(changeProfileImage(tapGestureRecognizer:)))
            profilePhoto.isUserInteractionEnabled = true
            profilePhoto.addGestureRecognizer(tapGestureRecognizer)
            
            profilePhoto.kf.setImage(
                with: mainUser?._userPhotoURL,
                placeholder: UIImage(named: "groupPlaceholder"),
                options: [
                    .transition(.fade(1)),
                    .cacheOriginalImage
                ])
            
            nameTextField.text = currentUser?.displayName
        }
        
        if self.carTypeDetail != nil {
            self.carTypeDetail.text = mainUser?._userCar._carType
            self.carMPGDetail.text = mainUser?._userCar._carMPG
            self.carSeatsDetail.text = mainUser?._userCar._carSeats
            self.carRegistrationDetail.text = mainUser?._userCar._carRegistration
        } else if self.carTypeTextField != nil {
            self.createPickerView(type: mainUser?._userCar._carType)
            self.createToolbar()
            self.selectedType = mainUser?._userCar._carType
            self.carTypeTextField.text = mainUser?._userCar._carType
        } else if self.carMPGTextField != nil {
            self.carMPGTextField.text = ""
            if mainUser?._userCar._carMPG != "nil" {
                self.carMPGTextField.text = mainUser?._userCar._carMPG
            }
        } else if self.carSeatsTextField != nil {
            self.carSeatsTextField.text = ""
            if mainUser?._userCar._carSeats != "nil" {
                self.carSeatsTextField.text = mainUser?._userCar._carSeats
            }
        } else if self.carRegistrationTextField != nil {
            self.carRegistrationTextField.text = ""
            if mainUser?._userCar._carRegistration != "nil" {
                self.carRegistrationTextField.text = mainUser?._userCar._carRegistration
            }
        }
        
        if carTypeTextField != nil {
            carTypeTextField.borderStyle = UITextField.BorderStyle.none
        } else if carMPGTextField != nil {
            carMPGTextField.borderStyle = UITextField.BorderStyle.none
            createToolbar()
        }
        if carSeatsTextField != nil {
            carSeatsTextField.borderStyle = UITextField.BorderStyle.none
            createToolbar()
        }
        if carRegistrationTextField != nil {
            carRegistrationTextField.borderStyle = UITextField.BorderStyle.none
            createToolbar()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        
        if carTypeDetail != nil {
            self.carTypeDetail.text = mainUser?._userCar._carType
            self.carMPGDetail.text = ""
            self.carSeatsDetail.text = ""
            self.carRegistrationDetail.text = ""
            if mainUser?._userCar._carMPG != "nil" {
                self.carMPGDetail.text = mainUser?._userCar._carMPG
            }
            if mainUser?._userCar._carSeats != "nil" {
                self.carSeatsDetail.text = mainUser?._userCar._carSeats
            }
            if mainUser?._userCar._carRegistration != "nil" {
                self.carRegistrationDetail.text = mainUser?._userCar._carRegistration
            }
            
//            RideDB?.child("Users").child((currentUser?.uid)!).observeSingleEvent(of: .value, with: { (snapshot) in
//                let value = snapshot.value as? NSDictionary
//                var car = value!["car"] as! [String: String]
//
//                if car["type"] == "none" {
//                    car["type"] = ""
//                    car["mpg"] = ""
//                    car["seats"] = ""
//                }
//
//                self.carTypeDetail.text = car["type"]
//                self.carMPGDetail.text = car["mpg"]
//                self.carSeatsDetail.text = car["seats"]
//            })
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        if self.handle != nil {
            RideDB?.removeObserver(withHandle: self.handle!)
        }
    }

    // MARK: - Table view data source

    /*
    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CardTableViewCell", for: indexPath) as! CardsTableViewCell

        // Configure the cell...
        if cards[indexPath.row]["brand"] as! String == "Visa" {

        } else if cards[indexPath.row]["brand"] as! String == "Mastercard" {

        }

        cell.cardNumber.text = cell.cardNumber.text! + (cards[indexPath.row]["last4"] as! String)
        cell.cardExpiry.text = (cards[indexPath.row]["exp_month"] as! String) + "/" + (cards[indexPath.row]["exp_year"] as! String)

        return cell
    }
     */
    

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        if segue.identifier == "showSetupFromSettings" {
            let navigationController = segue.destination as! UINavigationController
            let setupViewController = navigationController.viewControllers.first as! SetupViewController
            setupViewController.skip = true
        }
        
        if segue.identifier == "showPrivacyPolicy" {
            let navigationController = segue.destination as! UINavigationController
            let legalViewController = navigationController.viewControllers.first as! LegalViewController
            legalViewController.url = URL(string: "https://fuse-ride.firebaseapp.com/terms/privacy.html")
        }
        
        if segue.identifier == "showSSA" {
            let navigationController = segue.destination as! UINavigationController
            let legalViewController = navigationController.viewControllers.first as! LegalViewController
            legalViewController.url = URL(string: "https://stripe.com/gb/ssa")
        }
    }
    
    
    @IBAction func nameTextFieldReturn(_ sender: UITextField) {
        sender.resignFirstResponder()
        
        let changeRequest = currentUser?.createProfileChangeRequest()
        
        changeRequest?.displayName = self.nameTextField.text
        
        RideDB?.child("Users").child((mainUser?._userID)!).child("name").setValue(self.nameTextField.text)
        
        mainUser?._userName = self.nameTextField.text!
        
        changeRequest?.commitChanges { error in
            if let error = error {
                let alert = UIAlertController(title: "An error occurred. Please try again.", message: "", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: { _ in
                    NSLog(error.localizedDescription)
                }))
                sender.resignFirstResponder()
                self.present(alert, animated: true, completion: nil)
            } else {
                sender.resignFirstResponder()
            }
        }
        
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return carTypes.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return carTypes[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedType = carTypes[row]
        carTypeTextField.text = selectedType
//        car["type"] = selectedType
    }
    
    func createPickerView(type: String?) {
        let pickerView = UIPickerView()
        pickerView.delegate = self
        
        carTypeTextField.inputView = pickerView
        
        if type != nil && type != "" && type != "undefined" {
            pickerView.selectRow(carTypes.firstIndex(of: type!)!, inComponent: 0, animated: true)
        }
    }
    
    func createToolbar() {
        let toolBar = UIToolbar()
        toolBar.sizeToFit()
        
        let flexibleButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(SettingsTableViewController.dismissKeyboard))
        toolBar.setItems([flexibleButton, doneButton], animated: false)
        toolBar.isUserInteractionEnabled = true
        
        if carTypeTextField != nil {
            carTypeTextField.inputAccessoryView = toolBar
        } else if carMPGTextField != nil {
            carMPGTextField.inputAccessoryView = toolBar
        } else if carSeatsTextField != nil {
            carSeatsTextField.inputAccessoryView = toolBar
        } else if carRegistrationTextField != nil {
            carRegistrationTextField.inputAccessoryView = toolBar
        }
    }
    
    @objc func dismissKeyboard() {
        if carTypeTextField != nil {
            updateCarType()
        } else if carMPGTextField != nil {
            updateCarMPG()
        } else if carSeatsTextField != nil {
            updateCarSeats()
        } else if carRegistrationTextField != nil {
            updateCarRegistration()
        }
        view.endEditing(true)
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if self.profilePhoto != nil {
            if indexPath.section == 0 {
                return 200.0
            }
            
            if indexPath.section == 1 {
                if mainUser?._userCar._carType != "" {
                    if indexPath.row == 4 {
                        return 0.0
                    }
                } else {
                    if indexPath.row != 4 {
                        return 0.0
                    }
                }
            }
        }
        
        return 44.0
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case 1:
            if mainUser?._userCar._carType == "" {
                if indexPath.row == 0 {
//                    moveToSetupController(skip: true)
                }
            }
        case 2:
            if indexPath.row == 2 {
//                let addCardViewController = STPAddCardViewController()
//                addCardViewController.delegate = self
//                self.navigationController?.pushViewController(addCardViewController, animated: true)
            }
        case 3:
            if indexPath.row == 0 {
                logOut()
            } else if indexPath.row == 1 {
                let alert = UIAlertController(title: "Confirm account deletion", message: "All of your data will be deleted", preferredStyle: .alert)
                
                alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { (action: UIAlertAction) in
                    self.deleteAccount()
                }))
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                
                self.present(alert, animated: true)
            }
        default:
            os_log("Section error", log: OSLog.default, type: .error)
        }
    
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    @IBAction func closeSettings(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc private func changeProfileImage(tapGestureRecognizer: UITapGestureRecognizer) {
//        _ = tapGestureRecognizer.view as! UIImageView
        
        if UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum) {
            imagePicker.delegate = self
            imagePicker.allowsEditing = false
            
            self.present(imagePicker, animated: true, completion: nil)
        }
    }
    
    @objc func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        self.dismiss(animated: true, completion: { () -> Void in
            var image = info["UIImagePickerControllerOriginalImage"] as? UIImage
            
            // Crop to square
            image = image?.resize(width: 200)
            
            self.profilePhoto.image = image
            self.welcomeViewControllerDelegate?.changeProfilePhoto(image: image!)
            
            let profileRef = RideStorage?.reference().child("UserProfiles/" + (currentUser?.uid)! + ".jpg")
            
            if let imageData = image?.jpeg(.lowest) {
                profileRef?.putData(imageData, metadata: nil) { metadata, error in
                    // You can also access to download URL after upload.
                    profileRef?.downloadURL { (url, error) in
                        guard let downloadURL = url else {
                            // Uh-oh, an error occurred!
                            return
                        }
                        
                        RideDB?.child("Users").child((currentUser?.uid)!).child("photo").setValue(downloadURL.absoluteString)
                        
                        let changeRequest = currentUser?.createProfileChangeRequest()
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
        
        print("Info:", info)
    }

    
    private func logOut() {        
        if fbAccessToken != nil {
            AccessToken.current = nil
            fbAccessToken = nil
        }
        
        let firebaseAuth = Auth.auth()
        
        do {
            try firebaseAuth.signOut()
        } catch let signOutError as NSError {
            print ("Error signing out: %@", signOutError)
        }
        
        let loginManager = LoginManager()
        loginManager.logOut()
        
        RideDB?.child("Users").child(currentUser!.uid).child("token").removeValue()
        
        currentUser = nil
        mainUser = nil
        moveToLoginController()
    }
    
    private func deleteAccount() {
        let id = currentUser?.uid
        Auth.auth().currentUser?.delete { error in
            if let error = error {
                let alert = UIAlertController(title: "Could not delete account", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: { _ in
                    NSLog("Firebase Auth delete account error: \(error.localizedDescription)")
                }))
                self.present(alert, animated: true, completion: nil)
            } else {
                if id != nil {
                    RideDB?.child("Users").child(id!).removeValue()
                    RideDB?.child("Connections").child(id!).removeValue()
                    RideDB?.child("stripe_customers").child(id!).removeValue()
                }
                
                let alert = UIAlertController(title: "Account deleted", message: "", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: { _ in
                    NSLog("Firebase Auth delete account success")
                }))
                self.present(alert, animated: true, completion: nil)
                self.logOut()
                moveToLoginController()
            }
        }
    }
    
    private func updateCarType() {
        RideDB?.child("Users").child((currentUser?.uid)!).child("car").child("type").setValue(selectedType)
    }
    
    private func updateCarMPG() {
        RideDB?.child("Users").child((currentUser?.uid)!).child("car").child("mpg").setValue(carMPGTextField.text)
    }
    
    private func updateCarSeats() {
        RideDB?.child("Users").child((currentUser?.uid)!).child("car").child("seats").setValue(carSeatsTextField.text)
    }
    
    private func updateCarRegistration() {
        RideDB?.child("Users").child((currentUser?.uid)!).child("car").child("registration").setValue(carRegistrationTextField.text)
    }
}
