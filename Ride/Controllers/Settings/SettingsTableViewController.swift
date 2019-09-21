//
//  SettingsTableViewController.swift
//  Ride
//
//  Created by Ben Mechen on 10/07/2018.
//  Copyright © 2018 Fuse Apps. All rights reserved.
//

import UIKit
import Firebase
import FacebookLogin
import FacebookCore
import FBSDKLoginKit
import Stripe
import Crashlytics
import Kingfisher
import MessageUI
import MapKit
import Alamofire
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
    @IBOutlet weak var driverStatusLabel: UILabel!
    @IBOutlet weak var driverStatusIcon: UIImageView!
    @IBOutlet weak var verificationErrorLabel: UILabel!
    @IBOutlet weak var verificationActivityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var verificationCell: UITableViewCell!
    @IBOutlet weak var contactCell: UITableViewCell!
    @IBOutlet weak var versionNumber: UILabel!
    
    
    weak var welcomeViewControllerDelegate: WelcomeViewControllerDelegate?
    var userManager: UserManagerProtocol!
    lazy var RideDB = Database.database().reference()
    var imagePicker = UIImagePickerController()
    var selectedType: String?
    var carTypes = ["Hatchback", "Estate", "SUV", "Saloon", "Coupe", "MPV", "Convertible", "Pick Up", "Other"]
    var handle: UInt? = nil
    var currentUserCarType = ""
    let locationManager = CLLocationManager()
    var vSpinner: UIView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
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
            
            userManager?.getCurrentUser(completion: { (success, user) in
                guard success && user != nil else {
                    return
                }
                
                self.profilePhoto.kf.setImage(
                    with: user!.photo,
                    placeholder: UIImage(named: "groupPlaceholder"),
                    options: [
                        .transition(.fade(1)),
                        .cacheOriginalImage
                    ])
            })
            
            nameTextField.text = Auth.auth().currentUser?.displayName
            
            RideDB.child("stripe_customers").child(Auth.auth().currentUser!.uid).child("account_id").observeSingleEvent(of: .value, with: { snapshot in
                if let value = snapshot.value as? String, let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                    appDelegate.getSecretKey(completion: { (secretKey) in
                        Alamofire.request("https://api.stripe.com/v1/accounts/\(value)", method: .get, headers: ["Authorization": "Bearer \(secretKey)"]).responseJSON(completionHandler: { response in
                            if let error = response.error {
                                print(error)
                                NSLog(error.localizedDescription)
                            } else {
                                self.driverStatusLabel.text = "Driver status: Verified"
                                self.driverStatusIcon.image = UIImage(named: "check")
                                self.verificationCell.isUserInteractionEnabled = false
                                self.verificationCell.accessoryType = UITableViewCell.AccessoryType.none

                                if let result = response.result.value as? NSDictionary {
                                    self.RideDB.child("stripe_customers").child(Auth.auth().currentUser!.uid).child("account").setValue(result)
                                    if let verification = result["verification"] as? NSDictionary {
                                        if let fieldsNeeded = verification["fields_needed"] as? NSArray {
                                            if fieldsNeeded.count > 0 {
                                                self.verificationCell.isUserInteractionEnabled = true
                                                self.verificationCell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                                                self.driverStatusLabel.text = "Driver status: Unverified"
                                                if let legalEntity = result["legal_entity"] as? NSDictionary, let legalEntityVerification = legalEntity["verification"] as? NSDictionary {
                                                    if let status = legalEntityVerification["status"] as? String {
                                                        if status == "pending" {
                                                            self.driverStatusLabel.text = "Driver status: Pending"
                                                        }
                                                    }
                                                }
                                                
                                                self.driverStatusIcon.image = UIImage(named: "alert")
                                            }
                                        }
                                    }
                                }
                            }
                        })
                    })
                }
            })
            
            versionNumber.text = "v" + ((Bundle.main.infoDictionary!["CFBundleShortVersionString"] as? String)!) + " Build " + ((Bundle.main.infoDictionary!["CFBundleVersion"] as? String)!)

        }
        
        userManager?.getCurrentUser(completion: { (success, user) in
            guard success && user != nil else {
                return
            }
            
            if self.carTypeDetail != nil {
                self.carTypeDetail.text = user!.car._carType
                self.carMPGDetail.text = user!.car._carMPG
                self.carSeatsDetail.text = user!.car._carSeats
                self.carRegistrationDetail.text = user!.car._carRegistration
            } else if self.carTypeTextField != nil {
                self.createPickerView(type: user!.car._carType)
                self.createToolbar()
                self.selectedType = user!.car._carType
                self.carTypeTextField.text = user!.car._carType
            } else if self.carMPGTextField != nil {
                self.carMPGTextField.text = ""
                if user!.car._carMPG != "nil" {
                    self.carMPGTextField.text = user!.car._carMPG
                }
            } else if self.carSeatsTextField != nil {
                self.carSeatsTextField.text = ""
                if user!.car._carSeats != "nil" {
                    self.carSeatsTextField.text = user!.car._carSeats
                }
            } else if self.carRegistrationTextField != nil {
                self.carRegistrationTextField.text = ""
                if user!.car._carRegistration != "nil" {
                    self.carRegistrationTextField.text = user!.car._carRegistration
                }
            } else if self.verificationErrorLabel != nil {
                self.tableView.tableFooterView = UIView()
                self.RideDB.child("stripe_customers").child(Auth.auth().currentUser!.uid).child("account_id").observeSingleEvent(of: .value, with: { snapshot in
                    if let value = snapshot.value as? String, let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                        appDelegate.getSecretKey(completion: { (secretKey) in
                            Alamofire.request("https://api.stripe.com/v1/accounts/\(value)", method: .get, headers: ["Authorization": "Bearer \(secretKey)"]).responseJSON(completionHandler: { response in
                                if let error = response.error {
                                    print(error)
                                } else {
                                    if let result = response.result.value as? NSDictionary {
                                        print(result)
                                        if let legalEntity = result["legal_entity"] as? NSDictionary, let verification = legalEntity["verification"] as? NSDictionary, let details = verification["details"] as? String {
                                            self.verificationActivityIndicator.stopAnimating()
                                            self.verificationErrorLabel.text = details
                                        }
                                    }
                                }
                            })
                        })
                    }
                })
            }
        })
        
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
        
        userManager?.getCurrentUser(completion: { (success, user) in
            guard success && user != nil else {
                return
            }
            
            self.currentUserCarType = user!.car._carType
            
            if self.carTypeDetail != nil {
                self.carTypeDetail.text = user!.car._carType
                self.carMPGDetail.text = ""
                self.carSeatsDetail.text = ""
                self.carRegistrationDetail.text = ""
                if user!.car._carMPG != "nil" {
                    self.carMPGDetail.text = user!.car._carMPG
                }
                if user!.car._carSeats != "nil" {
                    self.carSeatsDetail.text = user!.car._carSeats
                }
                if user!.car._carRegistration != "nil" {
                    self.carRegistrationDetail.text = user!.car._carRegistration
                }
            }
        })
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        if self.handle != nil {
            RideDB.removeObserver(withHandle: self.handle!)
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
            if let navigationController = segue.destination as? UINavigationController, let setupViewController = navigationController.viewControllers.first as? SetupViewController {
                setupViewController.skip = true
                setupViewController.userManager = userManager
            }
        }
        
        if segue.identifier == "showPrivacyPolicy" {
            if let navigationController = segue.destination as? UINavigationController, let legalViewController = navigationController.viewControllers.first as? LegalViewController {
                legalViewController.url = URL(string: "https://fuse-ride.firebaseapp.com/terms/privacy.html")
            }
        }
        
        if segue.identifier == "showSSA" {
            if let navigationController = segue.destination as? UINavigationController, let legalViewController = navigationController.viewControllers.first as? LegalViewController {
                legalViewController.url = URL(string: "https://stripe.com/gb/ssa")
            }
        }
        
        if segue.identifier == "showContact" {
            if let contactViewController = segue.destination as? ContactViewController {
                contactViewController.userManager = userManager
            }
        }
        
        if segue.identifier == "rerunSetup" {
            if let setupViewController = segue.destination as? SetupViewController {
                setupViewController.userManager = userManager
            }
        }
        
        if let destination = segue.destination as? SettingsTableViewController {
            destination.userManager = userManager
        }
    }
    
    
    @IBAction func nameTextFieldReturn(_ sender: UITextField) {
        sender.resignFirstResponder()
        
        vSpinner = self.showSpinner(onView: self.view)
        
        RideDB.child("stripe_customers").child(Auth.auth().currentUser!.uid).observeSingleEvent(of: .value) { (snapshot) in
            if snapshot.hasChild("account") {
                let alert = UIAlertController(title: "Are you sure you want to change your name?", message: "Chaning your Ride name will require your account to be reverified - the new name must match that specified on the ID you supplied when the account was created.", preferredStyle: .alert)
                
                alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { _ in
                    snapshot.ref.child("account").child("legal_entity").child("first_name").setValue(self.nameTextField.text?.split(separator: " ").first)
                    snapshot.ref.child("account").child("legal_entity").child("last_name").setValue(self.nameTextField.text?.split(separator: " ").last)
                    
                    self.setName(self.nameTextField.text!)
                    self.removeSpinner(spinner: self.vSpinner!)
                }))
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
                    self.nameTextField.text = Auth.auth().currentUser?.displayName
                    self.removeSpinner(spinner: self.vSpinner!)
                }))
                
                
                self.present(alert, animated: true)
            } else {
                self.setName(self.nameTextField.text!)
                self.removeSpinner(spinner: self.vSpinner!)
            }
        }
    }
    
    func setName(_ name: String) {
        let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest()
        
        changeRequest?.displayName = name
        
        RideDB.child("Users").child(Auth.auth().currentUser!.uid).child("name").setValue(name)
        
        userManager?.updateCurrentUser()
        
        changeRequest?.commitChanges { error in
            if let error = error {
                let alert = UIAlertController(title: "An error occurred. Please try again.", message: "", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { _ in
                    NSLog(error.localizedDescription)
                }))
//                sender.resignFirstResponder()
                self.present(alert, animated: true, completion: nil)
            } else {
//                sender.resignFirstResponder()
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
    
    @objc override func dismissKeyboard() {
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
                if currentUserCarType != "" {
                    if indexPath.row == 5 {
                        return 0.0
                    }
                } else {
                    if indexPath.row != 5 {
                        return 0.0
                    }
                }
            } else if indexPath.section == 2 {
                if indexPath.row == 0 {
                    return 0.0
                }
            }
        }
        
        return 44.0
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case 1:
            userManager?.getCurrentUser(completion: { (success, user) in
                guard success && user != nil else {
                    return
                }
                if user!.car._carType == "" {
                    if indexPath.row == 0 {
    //                    moveToSetupController(skip: true)
                    }
                }
            })
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
    
    
    // MARK: - Image Picker
    
    @objc private func changeProfileImage(tapGestureRecognizer: UITapGestureRecognizer) {
//        _ = tapGestureRecognizer.view as! UIImageView
        
        if UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum) {
            imagePicker.delegate = self
            imagePicker.allowsEditing = false
            
            self.present(imagePicker, animated: true, completion: nil)
        }
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        self.dismiss(animated: true, completion: { () -> Void in
            var image = info[.originalImage] as? UIImage
            
            // Crop to square
            image = image?.resize(width: 200)
            
            self.profilePhoto.image = image
            self.welcomeViewControllerDelegate?.changeProfilePhoto(image: image!)
            
            let profileRef = Storage.storage().reference().child("UserProfiles/" + (Auth.auth().currentUser?.uid)! + ".jpg")
            
            if let imageData = image?.jpeg(.lowest) {
                profileRef.putData(imageData, metadata: nil) { metadata, error in
                    // You can also access to download URL after upload.
                    profileRef.downloadURL { (url, error) in
                        guard let downloadURL = url else {
                            // Uh-oh, an error occurred!
                            return
                        }
                        
                        self.RideDB.child("Users").child((Auth.auth().currentUser?.uid)!).child("photo").setValue(downloadURL.absoluteString)
                        
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
        
        print("Info:", info)
    }

    
    // MARK: - Private methods
    
    private func logOut() {
        FBSDKLoginKit.AccessToken.current = nil
        
        locationManager.stopUpdatingLocation()
        
        RideDB.child("Users").child(Auth.auth().currentUser!.uid).child("token").removeValue()
        
        let firebaseAuth = Auth.auth()
        
        do {
            try firebaseAuth.signOut()
        } catch let signOutError as NSError {
            print ("Error signing out: %@", signOutError)
        }
        
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.userManager.logout()
        }
        
        let loginManager = LoginManager()
        loginManager.logOut()
        
//        self.dismiss(animated: true)
        
        moveToLoginController()
    }
    
    private func deleteAccount() {
        let id = Auth.auth().currentUser?.uid
        Auth.auth().currentUser?.delete { error in
            if let error = error {
                let alert = UIAlertController(title: "Could not delete account", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: { _ in
                    NSLog("Firebase Auth delete account error: \(error.localizedDescription)")
                }))
                self.present(alert, animated: true, completion: nil)
            } else {
                if id != nil {
                    self.RideDB.child("Users").child(id!).removeValue()
                    self.RideDB.child("Connections").child(id!).removeValue()
                }
                
                let alert = UIAlertController(title: "Account deleted", message: "", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: { _ in
                    NSLog("Firebase Auth delete account success")
                }))
                self.present(alert, animated: true, completion: nil)
                
                if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                    appDelegate.userManager.logout()
                }

                let loginManager = LoginManager()
                loginManager.logOut()
                
                moveToLoginController()
            }
        }
    }
    
    private func updateCarType() {
        RideDB.child("Users").child((Auth.auth().currentUser?.uid)!).child("car").child("type").setValue(selectedType)
    }
    
    private func updateCarMPG() {
        RideDB.child("Users").child((Auth.auth().currentUser?.uid)!).child("car").child("mpg").setValue(carMPGTextField.text)
    }
    
    private func updateCarSeats() {
        RideDB.child("Users").child((Auth.auth().currentUser?.uid)!).child("car").child("seats").setValue(carSeatsTextField.text)
    }
    
    private func updateCarRegistration() {
        RideDB.child("Users").child((Auth.auth().currentUser?.uid)!).child("car").child("registration").setValue(carRegistrationTextField.text)
    }
}
