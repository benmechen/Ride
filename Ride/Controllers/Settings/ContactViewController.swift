//
//  ContactViewController.swift
//  Ride
//
//  Created by Ben Mechen on 04/03/2019.
//  Copyright © 2019 Fuse Apps. All rights reserved.
//

import UIKit
import Firebase

class ContactViewController: UIViewController {

    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var messageTextField: UITextView!
    
    var userManager: UserManagerProtocol!
    var vSpinner: UIView?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        userManager?.getCurrentUser(completion: { (success, user) in
            guard success && user != nil else {
                return
            }
            
            self.nameTextField.text = user!.name
        })
        
        emailTextField.text = Auth.auth().currentUser?.email
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
    @IBAction func sendMessage(_ sender: Any) {
        guard self.nameTextField.text != nil && self.emailTextField.text != nil && self.messageTextField.text != nil else {
            return
        }
        
        self.vSpinner = self.showSpinner(onView: self.view)
        userManager?.getCurrentUser(completion: { (success, user) in
            guard success && user != nil else {
                return
            }
            let smtpSession = MCOSMTPSession()
            smtpSession.hostname = "smtp.gmail.com"
            smtpSession.port = 465
            smtpSession.username = "mailmyother3@gmail.com"
            smtpSession.password = "Trevlorado08!"
            smtpSession.connectionType = MCOConnectionType.TLS
            
            let builder = MCOMessageBuilder()
            builder.header.to = [MCOAddress(displayName: "Ride Support", mailbox: "bmechen@icloud.com")]
            builder.header.from = MCOAddress(displayName: self.nameTextField.text, mailbox: "mailmyother3@gmail.com")
            builder.header.subject = "Ride Support Request"
            builder.htmlBody = "<h2>From: \(String(describing: self.nameTextField.text!))</h2><h3>Email: \(String(describing: self.emailTextField.text!))</h3><br> \(String(describing: self.messageTextField.text!)) <br><br><small>\(user!.name)</small>"
            
            let rfc822Data = builder.data()
            let sendOperation = smtpSession.sendOperation(with: rfc822Data)
            sendOperation!.start { (error) -> Void in
                self.removeSpinner(spinner: self.vSpinner!)
                if (error != nil) {
                    let alert = UIAlertController(title: "An error occurred. Please try again.", message: "", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                    NSLog("Error sending email: \(String(describing: error))")
                } else {
                    NSLog("Successfully sent email!")
                    self.dismiss(animated: true, completion: nil)
                }
            }
        })
    }

}
