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
    
    override func viewDidLoad() {
        super.viewDidLoad()

        //Set the system colours
        titleText.textColor = rideRed
        nameTextField.layer.borderWidth = 1
        nameTextField.layer.borderColor = rideClickableRed.cgColor
        emailTextField.layer.borderWidth = 1
        emailTextField.layer.borderColor = rideClickableRed.cgColor
        passwordTextField.layer.borderWidth = 1
        passwordTextField.layer.borderColor = rideClickableRed.cgColor
        confirmPasswordTextField.layer.borderWidth = 1
        confirmPasswordTextField.layer.borderColor = rideClickableRed.cgColor
        createAccountButton.backgroundColor = rideClickableRed
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
            self.showSpinner(onView: self.view)
            self.view.endEditing(true)
            if passwordTextField.text == confirmPasswordTextField.text {
                Auth.auth().createUser(withEmail: emailTextField.text!, password: passwordTextField.text!) { (authResult, error) in
                    if error != nil {
                        self.removeSpinner()
                        let alert = UIAlertController(title: error?.localizedDescription, message: "", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: { _ in
                            NSLog("Firebase Auth create account error")
                        }))
                        self.present(alert, animated: true, completion: nil)
                    } else {
                        print("Successful login")
                        currentUser = Auth.auth().currentUser
                        let changeRequest = currentUser?.createProfileChangeRequest()
                        
                        changeRequest?.photoURL =
                            URL(string: "https://firebasestorage.googleapis.com/v0/b/fuse-ride.appspot.com/o/UserProfiles%2Fplaceholder.jpg?alt=media&token=abfeb0ec-6d83-4d8f-b9fe-aa3316aef96b")!
                        changeRequest?.displayName = self.nameTextField.text
                        changeRequest?.commitChanges { error in
                            if let error = error {
                                self.removeSpinner()
                                let alert = UIAlertController(title: "An error occurred. Please try again.", message: "", preferredStyle: .alert)
                                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: { _ in
                                    NSLog(error.localizedDescription)
                                }))
                                self.present(alert, animated: true, completion: nil)
                            } else {
                                currentUser = Auth.auth().currentUser
                                RideDB?.child("Users").observeSingleEvent(of: .value, with: { (snapshot) in
                                    if !snapshot.hasChild((currentUser?.uid)!){
                                        RideDB?.child("Users").child((currentUser?.uid)!).setValue(["name": currentUser?.displayName as Any, "photo": currentUser?.photoURL?.absoluteString as Any, "car": ["type": "", "mpg": "", "seats": "", "registration": ""]])
                                        
                                        mainUser = User(id: (currentUser?.uid)!, name: (currentUser?.displayName)!, photo: (currentUser?.photoURL?.absoluteString)!, car: ["type": "", "mpg": "", "seats": "", "registration": ""], available: [:], location: [:], timestamp: 0.0)
                                        
                                        RideDB?.child("Connections").child((currentUser?.uid)!).setValue([])
                                    } else {
                                        getMainUser(welcome: true)
                                    }
                                })
                                self.removeSpinner()
                                self.dismiss(animated: true, completion: {moveToWelcomeController()})
                            }
                        }
                    }
                }
            } else {
                self.removeSpinner()
                let alert = UIAlertController(title: "Passwords do not match", message: "", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: { _ in
                    NSLog("Passwords match error")
                }))
                self.present(alert, animated: true, completion: nil)
            }
        } else {
            self.removeSpinner()
            print("Fields empty")
            let alert = UIAlertController(title: "Please fill all fields", message: "", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: { _ in
                NSLog("Fields empty")
            }))
            self.present(alert, animated: true, completion: nil)
        }
    }
}
