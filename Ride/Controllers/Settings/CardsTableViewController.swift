//
//  CardsTableViewController.swift
//  Ride
//
//  Created by Ben Mechen on 16/02/2019.
//  Copyright © 2019 Fuse Apps. All rights reserved.
//

import UIKit
import Stripe
import Crashlytics

protocol CardsTableViewControllerDelegate {
    func reloadAccounts()
}

class CardsTableViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, CardsTableViewControllerDelegate {

    @IBOutlet var cardsTableView: UITableView!
    @IBOutlet var accountsTableView: UITableView!
    @IBOutlet weak var sortCodeTextField: UITextField!
    @IBOutlet weak var accountNoTextField: UITextField!
    var cardsTableViewControllerDelegate: CardsTableViewControllerDelegate? = nil
    
    var currentlyEditing: Bool = false
    var cards: [[String: Any]] = []
    var cardIDs: Array<String> = []
    var accounts: [[String: Any]] = []
    var accountIDs: Array<String> = []
    var handle: UInt? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard mainUser != nil else {
            moveToLoginController()
            return
        }
        
        if self.cardsTableView != nil {
            self.cardsTableView.delegate = self
            self.cardsTableView.dataSource = self
            self.cardsTableView.tableFooterView = UIView()
        } else if self.accountsTableView != nil {
            self.accountsTableView.delegate = self
            self.accountsTableView.dataSource = self
            self.accountsTableView.tableFooterView = UIView()
        } else if self.sortCodeTextField != nil {
            self.sortCodeTextField.borderColor = .white
            self.accountNoTextField.borderColor = .white
            
            self.sortCodeTextField.delegate = self
            
            let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard))
            view.addGestureRecognizer(tap)
        }
        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        
        if self.cardsTableView != nil {
            self.navigationItem.rightBarButtonItem = self.editButtonItem
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if self.cardsTableView != nil {
            cardIDs.removeAll()
            cards.removeAll()
            getUserCards()
        } else if self.accountsTableView != nil {
            accountIDs.removeAll()
            accounts.removeAll()
            getUserAccounts()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        if self.handle != nil {
            RideDB?.removeObserver(withHandle: self.handle!)
        }
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Table view data source

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (self.cards.count <= 1) && !self.currentlyEditing {
            self.navigationItem.rightBarButtonItem?.isEnabled = false
        } else {
            self.navigationItem.rightBarButtonItem?.isEnabled = true
        }
        if self.cardsTableView != nil {
            return self.cards.count + 1
        } else {
            return self.accounts.count + 1
        }
    }

    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CardTableViewCell", for: indexPath) as! CardsTableViewCell
        
        if self.cardsTableView != nil {
            if indexPath.row == 0 {
                cell.backgroundColor = UIColor.init(white: 1.0, alpha: 0.8)
                cell.cardNumber.isHidden = true
                cell.cardExpiry.isHidden = true
                cell.isHidden = true
            } else if indexPath.row < self.cards.count && indexPath.row > 0 {
                cell.cardTypeImage.isHidden = false
                cell.cardExpiry.isHidden = false
                cell.cardNumber.textColor = .black
                
                let brand = (cards[indexPath.row]["brand"] as! String).lowercased()
                
                if brand.contains("visa") {
                    cell.cardTypeImage.image = UIImage(named: "visa")
                } else if brand.contains("mastercard") {
                    cell.cardTypeImage.image = UIImage(named: "mastercard")
                } else if brand.contains("american express") {
                    cell.cardTypeImage.image = UIImage(named: "amex")
                } else {
                    cell.cardTypeImage.image = UIImage(named: "credit")
                }
                
                cell.cardNumber.text = "**** **** **** " + (cards[indexPath.row]["last4"] as! String)
                
                let month: NSNumber = cards[indexPath.row]["exp_month"] as! NSNumber
                let year: NSNumber = cards[indexPath.row]["exp_year"] as! NSNumber
                
                cell.cardExpiry.text = month.stringValue + "/" + year.stringValue
            } else {
                cell.cardNumber.text = "Add a card"
                cell.cardNumber.textColor = UIButton(type: UIButton.ButtonType.system).titleColor(for: .normal)!
                cell.cardExpiry.isHidden = true
                cell.cardTypeImage.isHidden = true
            }
        } else if self.accountsTableView != nil {
            if indexPath.row == 0 {
                cell.backgroundColor = UIColor.init(white: 1.0, alpha: 0.8)
                cell.name.isHidden = true
                cell.accountNo.isHidden = true
                cell.isHidden = true
            } else if indexPath.row < self.accounts.count && indexPath.row > 0 {
                cell.name.text = accounts[indexPath.row]["bank_name"] as? String
                cell.name.textColor = .black
                cell.accountNo.text = "****" + ((accounts[indexPath.row]["last4"] as? String)!)
                cell.accountNo.isHidden = false
            } else {
                cell.name.text = "Add an account"
                cell.name.textColor = UIButton(type: UIButton.ButtonType.system).titleColor(for: .normal)!
                cell.accountNo.isHidden = true
            }
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView == self.cardsTableView {
            self.cardsTableView.deselectRow(at: indexPath, animated: true)
            
            if indexPath.row == self.cards.count {
                let addCardViewController = STPAddCardViewController()
                addCardViewController.delegate = self
                self.navigationController?.pushViewController(addCardViewController, animated: true)
            }
        } else {
            self.accountsTableView.deselectRow(at: indexPath, animated: true)
            
            if indexPath.row == self.accounts.count {
                self.performSegue(withIdentifier: "showAddBank", sender: self)
            }
        }
    }

    // Override to support conditional editing of the table view.
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if tableView == self.cardsTableView {
            if indexPath.row == self.cards.count {
                return false
            }
        } else {
            return false
        }
        
        return true
    }

    // Override to support editing the table view.
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            if tableView == self.cardsTableView {
                if self.cards.count > 1 {
                    self.currentlyEditing = true
                    // Delete the row from the data source
                    RideDB?.child("stripe_customers").child(currentUser!.uid).child("sources").child(cardIDs[indexPath.row]).child("deleted").setValue(true)
                    RideDB?.child("stripe_customers").child(currentUser!.uid).child("sources").child(cardIDs[indexPath.row]).child("error").observe(.value, with: { (snapshot) in
                        if let value = snapshot.value as? String {
                            let alert = UIAlertController(title: "Error deleting card", message: value, preferredStyle: .alert)
                            
                            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                            
                            snapshot.ref.parent?.child("deleted").removeValue()
                            
                            self.present(alert, animated: true)
                        } else {
                            if indexPath.row < self.cards.count {
                                self.cards.remove(at: indexPath.row)
                                self.cardsTableView.deleteRows(at: [indexPath], with: .fade)
                                self.cardsTableView.numberOfRows(inSection: 0)
                            }
                        }
                    })
                } else {
                    let alert = UIAlertController(title: "Cannot delete card", message: "You must have at least one card on your account at all times. Add another before deleting this one.", preferredStyle: .alert)
                    
                    alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                    
                    self.present(alert, animated: true)
                    self.setEditing(false, animated: true)
                }
            } else {
                if self.accounts.count > 2 {
                    self.currentlyEditing = true
                    // Delete the row from the data source
                    RideDB?.child("stripe_customers").child(currentUser!.uid).child("account").child(String(indexPath.row)).child("deleted").setValue(true)
                    RideDB?.child("stripe_customers").child(currentUser!.uid).child("account").child(String(indexPath.row)).child("error").observe(.value, with: { (snapshot) in
                        if let value = snapshot.value as? String {
                            let alert = UIAlertController(title: "Error deleting account", message: value, preferredStyle: .alert)
                            
                            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                            
                            self.present(alert, animated: true)
                        } else {
                            self.accounts.remove(at: indexPath.row)
                            self.accountsTableView.deleteRows(at: [indexPath], with: .fade)
                            self.accountsTableView.numberOfRows(inSection: 0)
                        }
                    })
                } else {
                    let alert = UIAlertController(title: "Cannot delete card", message: "You must have at least one card on your account at all times. Add another before deleting this one.", preferredStyle: .alert)
                    
                    alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                    
                    self.present(alert, animated: true)
                    self.setEditing(false, animated: true)
                }
            }
        }
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
//        super.setEditing(editing, animated: true)
        if editing {
            self.currentlyEditing = true
            if self.cardsTableView != nil {
                self.cardsTableView.setEditing(editing, animated: true)
            }
        } else {
            self.currentlyEditing = false
            if self.cardsTableView != nil {
                self.cardsTableView.setEditing(editing, animated: true)
            }
            self.cardsTableView.numberOfRows(inSection: 0)
        }
    }

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
     @IBAction func addAccount(_ sender: Any) {
        self.showSpinner(onView: self.view)
        if sortCodeTextField.text?.count == 8 && accountNoTextField.text?.count == 8 {
            RideDB?.child("stripe_customers").child(mainUser!._userID).child("account").child("individual").observeSingleEvent(of: .value, with: { snapshot in
                if let value = snapshot.value as? [String: Any] {
                    var name = mainUser?._userName.split(separator: " ")
                    name?.remove(at: 0)
                    
                    var account: [String: Any] = [
                        "id": mainUser?._userID as Any,
                        "ip": self.getWiFiAddress() as Any,
                        "account_number": self.accountNoTextField.text as Any,
                        "sort_code": self.sortCodeTextField.text?.replacingOccurrences(of: "-", with: "") as Any,
                        "first_name": mainUser?._userName.split(separator: " ").first as Any,
                        "last_name": name?.joined() as Any
                    ]
                    if let address = value["address"] as? [String: String] {
                        account["address_country"] = address["country"]
                        account["address_line1"] = address["line1"]
                        account["address_line2"] = address["line2"] ?? ""
                        account["address_city"] = address["city"]
                        account["address_state"] = address["state"] ?? ""
                        account["address_postcode"] = address["postal_code"]
                    }
                    
                    if let dob = value["dob"] as? [String: Int] {
                        account["dob_day"] = dob["day"]
                        account["dob_month"] = dob["month"]
                        account["dob_year"] = dob["year"]
                    }
                    account["identity_document"] = "n/a"
                
                    RideDB?.child("stripe_customers").child(mainUser!._userID).child("account").setValue(account)
                }
            })
            
            self.handle = RideDB?.child("stripe_customers").child(mainUser!._userID).child("account").observe(.value, with: { snapshot in
                if snapshot.hasChild("error") {
                    if let value = snapshot.value as? [String: String] {
                        let alert = UIAlertController(title: "Error", message: value["error"], preferredStyle: .alert)
                        
                        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { (action: UIAlertAction) in
                            self.navigationController?.popViewController(animated: true)
                        }))
                        
                        self.present(alert, animated: true)
                    }
                } else if snapshot.hasChild("id") {
                    self.cardsTableViewControllerDelegate?.reloadAccounts()
                    self.removeSpinner()
                    self.dismiss(animated: true, completion: nil)
                    RideDB?.removeObserver(withHandle: self.handle!)
                }
            })
            
        }
    }
    
    func reloadAccounts() {
        self.viewWillAppear(true)
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        var groupSize = 1
        let separator = "-"
        if string.count == 0 {
            groupSize = 4
        }
        let formatter = NumberFormatter()
        formatter.groupingSeparator = separator
        formatter.groupingSize = groupSize
        formatter.usesGroupingSeparator = true
        formatter.secondaryGroupingSize = 2
        formatter.maximumIntegerDigits = 8
        
        if var number = textField.text, string != "" {
            number = number.replacingOccurrences(of: separator, with: "")
            if let doubleVal = Double(number) {
                let requiredString = formatter.string(from: NSNumber.init(value: doubleVal))
                textField.text = requiredString
            }
            
        }
        return true
    }
    
    func getWiFiAddress() -> String? {
        var address : String?
        
        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }
        
        // For each interface ...
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            
            // Check for IPv4 or IPv6 interface:
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                
                // Check interface name:
                let name = String(cString: interface.ifa_name)
                if  name == "en0" {
                    
                    // Convert interface address to a human readable string:
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        freeifaddrs(ifaddr)
        
        return address
    }
    
    
     // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showAddBank" {
            let navigationController = segue.destination as! UINavigationController
            navigationController.navigationItem.backBarButtonItem = UIBarButtonItem(title: "Cancel", style: .done, target: self, action: Selector(("dismissAddBank")))
            navigationController.navigationItem.rightBarButtonItem?.isEnabled = false
            navigationController.navigationItem.rightBarButtonItem?.tintColor = .clear
            let cardsTableViewController = navigationController.viewControllers.first as! CardsTableViewController
            cardsTableViewController.cardsTableViewControllerDelegate = self
            cardsTableViewController.accounts = self.accounts
        }
    }
    
    @IBAction func dismissAddBank(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Private functions
    
    private func getUserCards() {
        self.cards.append([:])
        self.cardIDs.append("")
        RideDB?.child("stripe_customers").child(currentUser!.uid).child("sources").observeSingleEvent(of: .value, with: { (snapshot) in
            if let value = snapshot.value as? [String: [String: Any]] {
                for sourceID in value.keys {
                    if (!(value[sourceID]?.keys.contains("error"))!) {
                        if let deleted = value[sourceID]?["deleted"] as? Bool {
                            if !deleted {
                                self.cardIDs.append(sourceID)
                                self.cards.append(value[sourceID]!)
                            }
                        } else {
                            self.cardIDs.append(sourceID)
                            self.cards.append(value[sourceID]!)
                        }
                    }
                }
                
                self.cardsTableView.reloadData()
                self.cardsTableView.numberOfRows(inSection: 0)
            }
//            self.accounts.append([""])
        })
    }
    
    private func getUserAccounts() {
        self.accounts.append([:])
        self.accountIDs.append("")
        RideDB?.child("stripe_customers").child(currentUser!.uid).child("account").child("external_accounts").child("data").observeSingleEvent(of: .value, with: { (snapshot) in
            if let value = snapshot.value as? [[String: Any]] {
                print(value)
                for account in value {
                    if (account["error"] as? String) != nil {
                        // Don't append account
                    } else {
                        self.accounts.append(account)
                    }
                }
                
                print(self.accounts)
                
                self.accountsTableView.reloadData()
                self.accountsTableView.numberOfRows(inSection: 0)
            }
        })
    }

}

extension CardsTableViewController: STPAddCardViewControllerDelegate {
    
    func addCardViewControllerDidCancel(_ addCardViewController: STPAddCardViewController) {
        navigationController?.popViewController(animated: true)
        
        if (self.handle != nil) {
            RideDB?.removeObserver(withHandle: self.handle!)
        }
    }
    
    func addCardViewController(_ addCardViewController: STPAddCardViewController, didCreateToken token: STPToken, completion: @escaping STPErrorBlock) {
        
        let cardRef = RideDB?.child("stripe_customers").child(mainUser!._userID).child("sources").childByAutoId()
        
        cardRef?.child("token").setValue(token.tokenId) { (error, ref) -> Void in
            if let error = error {
                completion(error)
            } else {
                
                self.handle = RideDB?.child("stripe_customers").child(mainUser!._userID).child("sources").child(cardRef!.key!).observe(.value, with: { (snapshot) in
                    if snapshot.hasChild("error") {
                        if let value = snapshot.value as? [String: String] {
                            let alert = UIAlertController(title: "Error", message: value["error"], preferredStyle: .alert)
                            
                            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { (action: UIAlertAction) in
                                self.navigationController?.popViewController(animated: true)
                            }))
                            
                            self.present(alert, animated: true)
                        }
                    } else if snapshot.hasChild("id") {
                        RideDB?.removeObserver(withHandle: self.handle!)
                        self.navigationController?.popViewController(animated: true)
                    }
                })
            }
        }
    }
}


