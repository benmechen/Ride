//
//  EmailViewController.swift
//  Ride
//
//  Created by Ben Mechen on 09/07/2018.
//  Copyright © 2018 Fuse Apps. All rights reserved.
//

import UIKit
import Crashlytics
import Firebase
import QuartzCore

class EmailLoginViewController: UIViewController {

    @IBOutlet weak var titleText: UILabel!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var createAccountButton: UIButton!
    @IBOutlet weak var forgotPasswordButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        //Set the system colours
        titleText.textColor = rideRed
        emailTextField.layer.borderWidth = 1
        emailTextField.layer.borderColor = rideClickableRed.cgColor
        passwordTextField.layer.borderWidth = 1
        passwordTextField.layer.borderColor = rideClickableRed.cgColor
        loginButton.backgroundColor = rideClickableRed
        createAccountButton.setTitleColor(rideClickableRed, for: .normal)
        forgotPasswordButton.setTitleColor(rideClickableRed, for: .normal)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    @IBAction func closePopover(_ sender: Any) {
        view.endEditing(true)
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func logIn(_ sender: Any) {
        if emailTextField.text != "" && passwordTextField.text != "" {
            self.view.endEditing(true)
            self.showSpinner(onView: self.view)
            Auth.auth().signIn(withEmail: emailTextField.text!, password: passwordTextField.text!) { (user, error) in
                if error != nil {
                    self.removeSpinner()
                    let alert = UIAlertController(title: error?.localizedDescription, message: "", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: { _ in
                        NSLog("Firebase Auth login error")
                    }))
                    self.present(alert, animated: true, completion: nil)
                } else {
                    currentUser = Auth.auth().currentUser
                    RideDB?.child("Users").observeSingleEvent(of: .value, with: { (snapshot) in
                        if !snapshot.hasChild((currentUser?.uid)!){
                            RideDB?.child("Users").child((currentUser?.uid)!).setValue(["name": currentUser?.displayName as Any, "photo": currentUser?.photoURL?.absoluteString as Any, "car": ["type": "", "mpg": "", "seats": "", "registration": ""]])
                            
                            mainUser = User(id: (currentUser?.uid)!, name: (currentUser?.displayName)!, photo: (currentUser?.photoURL?.absoluteString)!, car: ["type": "", "mpg": "", "seats": "", "registration": ""], available: [:], location: [:], timestamp: 0.0)
                            
                        } else {
                            self.dismiss(animated: true, completion: {getMainUser(welcome: true)})
                        }
                        self.removeSpinner()
                    })
                }
            }
        } else {
            self.removeSpinner()
            let alert = UIAlertController(title: "Email or password field empty", message: "", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: { _ in
                NSLog("Email or password empty.")
            }))
            self.present(alert, animated: true, completion: nil)
        }
    }
}
