//
//  EmailCreateAccountViewController.swift
//  Ride
//
//  Created by Ben Mechen on 09/07/2018.
//  Copyright © 2018 Fuse Apps. All rights reserved.
//
import UIKit
import Crashlytics
import Firebase


class EmailCreateAccountViewController: UIViewController {
    
    @IBOutlet weak var titleText: UILabel!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var confirmPasswordTextField: UITextField!
    @IBOutlet weak var createAccountButton: UIButton!
    
    var userManager: UserManagerProtocol!
    lazy var RideDB = Database.database().reference()
    var vSpinner: UIView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Set the system colours
        titleText.textColor = UIColor(named: "Main")
        nameTextField.layer.borderWidth = 1
        nameTextField.layer.borderColor = UIColor(named: "Accent")?.cgColor
        emailTextField.layer.borderWidth = 1
        emailTextField.layer.borderColor = UIColor(named: "Accent")?.cgColor
        passwordTextField.layer.borderWidth = 1
        passwordTextField.layer.borderColor = UIColor(named: "Accent")?.cgColor
        confirmPasswordTextField.layer.borderWidth = 1
        confirmPasswordTextField.layer.borderColor = UIColor(named: "Accent")?.cgColor
        createAccountButton.backgroundColor = UIColor(named: "Accent")
        
        self.hideKeyboardWhenTappedAround()
    }
    
    
    /*
     // MARK: - Navigation
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destination.
     // Pass the selected object to the new view controller.
     }
     */
    @IBAction func createAccount(_ sender: UIButton) {
        if emailTextField.text != "" && passwordTextField.text != "" && confirmPasswordTextField.text != "" && nameTextField.text != "" {
            self.vSpinner = self.showSpinner(onView: self.view)
            self.view.endEditing(true)
            if passwordTextField.text == confirmPasswordTextField.text {
                Auth.auth().createUser(withEmail: emailTextField.text!, password: passwordTextField.text!) { (authResult, error) in
                    if error != nil {
                        self.removeSpinner(spinner: self.vSpinner!)
                        let alert = UIAlertController(title: error?.localizedDescription, message: "", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: { _ in
                            NSLog("Firebase Auth create account error")
                        }))
                        self.present(alert, animated: true, completion: nil)
                    } else {
                        print("Successful login")
                        let changeRequest = Auth.auth().currentUser!.createProfileChangeRequest()
                        
                        changeRequest.photoURL = URL(string: "https://firebasestorage.googleapis.com/v0/b/fuse-ride.appspot.com/o/UserProfiles%2Fplaceholder.jpg?alt=media&token=abfeb0ec-6d83-4d8f-b9fe-aa3316aef96b")!
                        changeRequest.displayName = self.nameTextField.text
                        changeRequest.commitChanges { error in
                            if let error = error {
                                self.removeSpinner(spinner: self.vSpinner!)
                                let alert = UIAlertController(title: "An error occurred. Please try again.", message: "", preferredStyle: .alert)
                                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: { _ in
                                    NSLog(error.localizedDescription)
                                }))
                                self.present(alert, animated: true, completion: nil)
                            } else {
                                self.RideDB.child("Users").observeSingleEvent(of: .value, with: { (snapshot) in
                                    if !snapshot.hasChild(Auth.auth().currentUser!.uid){
                                        var userDetails = ["name": Auth.auth().currentUser?.displayName as Any, "photo": Auth.auth().currentUser?.photoURL?.absoluteString as Any, "car": ["type": "", "mpg": "", "seats": "", "registration": ""]]
                                        
                                        let defaults = UserDefaults.standard
                                        if let invitedBy = defaults.string(forKey: "invited_by") {
                                            userDetails["invited_by"] = invitedBy
                                            
                                            self.RideDB.child("Connections").child((Auth.auth().currentUser?.uid)!).child(invitedBy).setValue(true)
                                            self.RideDB.child("Connections").child(invitedBy).child((Auth.auth().currentUser?.uid)!).setValue(true)
                                        }
                                        self.RideDB.child("Users").child((Auth.auth().currentUser?.uid)!).setValue(userDetails)
                                    }
                                    
                                    self.userManager!.getCurrentUser(completion: {(_,_) in })
                                    moveToWelcomeController()
                                })
                                self.removeSpinner(spinner: self.vSpinner!)
                                self.dismiss(animated: true, completion: {moveToWelcomeController()})
                            }
                        }
                    }
                }
            } else {
                self.removeSpinner(spinner: self.vSpinner!)
                let alert = UIAlertController(title: "Passwords do not match", message: "", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: { _ in
                    NSLog("Passwords match error")
                }))
                self.present(alert, animated: true, completion: nil)
            }
        } else {
            self.removeSpinner(spinner: self.vSpinner!)
            print("Fields empty")
            let alert = UIAlertController(title: "Please fill all fields", message: "", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: { _ in
                NSLog("Fields empty")
            }))
            self.present(alert, animated: true, completion: nil)
        }
    }
}
