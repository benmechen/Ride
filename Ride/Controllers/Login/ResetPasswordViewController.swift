//
//  ResetPasswordViewController.swift
//  Ride
//
//  Created by Ben Mechen on 09/07/2018.
//  Copyright © 2018 Fuse Apps. All rights reserved.
//

import UIKit
import Crashlytics
import Firebase

class ResetPasswordViewController: UIViewController {

    @IBOutlet weak var titleText: UILabel!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var resetPasswordButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        //Set system colours
        titleText.textColor = UIColor(named: "Main")
        emailTextField.layer.borderWidth = 1
        emailTextField.layer.borderColor = UIColor(named: "Accent")?.cgColor
        resetPasswordButton.backgroundColor = UIColor(named: "Accent")
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    @IBAction func resetPassword(_ sender: Any) {
        guard emailTextField.text != nil else {
            return
        }
        
        Auth.auth().sendPasswordReset(withEmail: (emailTextField.text?.trimmingCharacters(in: .whitespaces))!) { error in
            if error != nil {
                let alert = UIAlertController(title: error?.localizedDescription, message: "", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: { _ in
                    NSLog("Firebase Auth reset password error")
                }))
                self.present(alert, animated: true, completion: nil)
            } else {
                let alert = UIAlertController(title: "Password reset email sent", message: "Please check your emails and follow the link to reset your password", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: { _ in
                    NSLog("Firebase Auth password reset")
                }))
                self.present(alert, animated: true, completion: nil)
                moveToLoginController()
            }
        }
    }
    
}
