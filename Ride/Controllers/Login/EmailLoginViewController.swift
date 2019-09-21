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
    
    var userManager: UserManagerProtocol!
    var vSpinner: UIView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Set the system colours
        titleText.textColor = UIColor(named: "Main")
        emailTextField.layer.borderWidth = 1
        emailTextField.layer.borderColor = UIColor(named: "Accent")?.cgColor
        passwordTextField.layer.borderWidth = 1
        passwordTextField.layer.borderColor = UIColor(named: "Accent")?.cgColor
        loginButton.backgroundColor = UIColor(named: "Accent")
        createAccountButton.setTitleColor(UIColor(named: "Accent"), for: .normal)
        forgotPasswordButton.setTitleColor(UIColor(named: "Accent"), for: .normal)
        
        self.hideKeyboardWhenTappedAround() 
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        if segue.identifier == "showCreateAccount" {
            if let emailCreateAccountViewController = segue.destination as? EmailCreateAccountViewController {
                emailCreateAccountViewController.userManager = self.userManager
            }
        }
     }
    
    @IBAction func closePopover(_ sender: Any) {
        view.endEditing(true)
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func logIn(_ sender: Any) {
        let RideDB = Database.database().reference()
        
        if emailTextField.text != "" && passwordTextField.text != "" {
            self.view.endEditing(true)
            self.vSpinner = self.showSpinner(onView: self.view)
            Auth.auth().signIn(withEmail: emailTextField.text!, password: passwordTextField.text!) { (user, error) in
                if error != nil {
                    self.removeSpinner(spinner: self.vSpinner!)
                    let alert = UIAlertController(title: error?.localizedDescription, message: "", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: { _ in
                        NSLog("Firebase Auth login error")
                    }))
                    self.present(alert, animated: true, completion: nil)
                } else {
                    RideDB.child("Users").observeSingleEvent(of: .value, with: { (snapshot) in
                        if !snapshot.hasChild((Auth.auth().currentUser?.uid)!){
                            RideDB.child("Users").child((Auth.auth().currentUser?.uid)!).setValue(["name": Auth.auth().currentUser?.displayName as Any, "photo": Auth.auth().currentUser?.photoURL?.absoluteString as Any, "car": ["type": "", "mpg": "", "seats": "", "registration": ""]])
                        }
                        
                        self.userManager!.getCurrentUser(completion: {(_,_) in })
                        RideDB.child("Users").child(Auth.auth().currentUser!.uid).child("token").setValue(Messaging.messaging().fcmToken)
                        self.removeSpinner(spinner: self.vSpinner!)
                        moveToWelcomeController()
                    })
                }
            }
        } else {
            self.removeSpinner(spinner: self.vSpinner!)
            let alert = UIAlertController(title: "Email or password field empty", message: "", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: { _ in
                NSLog("Email or password empty.")
            }))
            self.present(alert, animated: true, completion: nil)
        }
    }
}
