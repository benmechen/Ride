//
//  SentRequestViewController.swift
//  Ride
//
//  Created by Ben Mechen on 10/02/2019.
//  Copyright © 2019 Fuse Apps. All rights reserved.
//

import UIKit
import Crashlytics
import MapKit
import CoreLocation
import Stripe
import Firebase
import Alamofire
import os.log

protocol PaymentDelegate {
    func setPaymentButton()
    func addUsers(users: [String: Array<Connection>])
}

protocol RequestsViewControllerDelegate {
    func performSegue(withIdentifier: String, sender: Any?)
}

class SentRequestViewController: UIViewController, MKMapViewDelegate, STPPaymentContextDelegate, PaymentDelegate {
    
    var userManager: UserManagerProtocol!
    lazy var RideDB = Database.database().reference()
    var requestsViewControllerDelegate: RequestsViewControllerDelegate!
    var request: Request? = nil
    var userName: String? = nil
    var price: [String: Double] = [:]
    var connections = [String: Array<Connection>]()
    var textFields = Array<UITextField>()
    lazy var geocoder = CLGeocoder()
    let customerContext = STPCustomerContext(keyProvider: StripeClient.shared)
    var paymentContext = STPPaymentContext(customerContext: STPCustomerContext(keyProvider: StripeClient.shared))
    var completePaymentDelegate: PaymentDelegate? = nil
    var vSpinner: UIView?
    
    @IBOutlet weak var page1Title: UILabel!
    @IBOutlet weak var page1Time: UILabel!
    @IBOutlet weak var page1Passengers: UILabel!
    @IBOutlet weak var page1MapView: MKMapView!
    
    @IBOutlet weak var page2Deleted: UILabel!
    
    @IBOutlet weak var page3Price: UITextField!
    @IBOutlet weak var page3Title: UILabel!
    
    @IBOutlet weak var page4Title: UILabel!
    @IBOutlet weak var page4Time: UILabel!
    @IBOutlet weak var page4Price: UILabel!
    @IBOutlet weak var page4Passengers: UILabel!
    @IBOutlet weak var page4Car: UILabel!
    @IBOutlet weak var page4Pay: UIButton!
    @IBOutlet weak var page4MapView: MKMapView!
    @IBOutlet weak var page4Cancel: UIButton!
    
    @IBOutlet weak var payTitle: UILabel!
    @IBOutlet weak var payPrice: UILabel!
    @IBOutlet weak var payMethod: UIButton!
    @IBOutlet weak var payButton: UIButton!
    @IBOutlet weak var payUsers: UIScrollView!
    @IBOutlet weak var paySplitPrice: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        if (page1Title != nil) {
            page1MapView.delegate = self
            
            page1Title.text = (page1Title.text ?? "") + (userName?.components(separatedBy: " ").first ?? "")
            
            let date = Date(timeIntervalSince1970: Double(request!._time))
            let dateFormatter = DateFormatter()
            dateFormatter.timeStyle = .short
            dateFormatter.dateStyle = .medium
        
            page1Time.attributedText = attributedText(withString: String(format: "Pickup Time: %@", dateFormatter.string(from: date)), boldString: "Pickup Time", font: page1Time.font)
            
            page1Passengers.attributedText = attributedText(withString: String(format: "Passengers: %@", String(request!._passengers)), boldString: "Passengers", font: page1Passengers.font)
            
            let to = MKPointAnnotation()
            to.coordinate = request!._to
            to.title = request?._toName
            
            let from = MKPointAnnotation()
            from.coordinate = self.request!._from
            from.title = request?._fromName
            
            self.page1MapView.addAnnotations([to, from])
            self.page1MapView.showAnnotations([to, from], animated: true)
            
            let directionsRequest = MKDirections.Request()
            let sourcePlacemark = MKPlacemark(coordinate: self.request!._to)
            let destinationPlacemark = MKPlacemark(coordinate: self.request!._from)
            let source = MKMapItem(placemark: sourcePlacemark)
            let destination = MKMapItem(placemark: destinationPlacemark)
            directionsRequest.destination = destination
            directionsRequest.source = source
            directionsRequest.transportType = .automobile
            directionsRequest.departureDate = date
            
            let directions = MKDirections(request: directionsRequest)
            directions.calculate(completionHandler: { (response, error) in
                if let error = error {
                    print(error)
                } else {
                    self.page1MapView.addOverlay((response?.routes.first!.polyline)!, level: MKOverlayLevel.aboveRoads)
                }
            })
        } else if (page2Deleted != nil) {
            if request?.status == -1 {
                page2Deleted.text = "You Ride request has been declined by " + String(userName?.split(separator: " ").first ?? "the other user")
            } else {
                page2Deleted.text = page2Deleted.text! + (userName?.split(separator: " ").first ?? "the other user")
            }
        } else if (page3Title != nil) {
            page3Title.text = page3Title.text! + String(userName?.split(separator: " ").first ?? "the other user")
            
            RideDB.child("Requests").child(request!._id!).child("price").observeSingleEvent(of: .value, with: { (snapshot) in
                if let value = snapshot.value as? [String: Double] {
                    self.page3Price.text = String(format: "£%.2f", value["total"]!)
                }
            })
        } else if (page4Title != nil) {
            page4MapView.delegate = self
        
            if self.request?.status != 3 {
                page4Pay.setAttributedTitle(self.attributedText(withString: String(format: "Pay %@", String((userName?.split(separator: " ").first)!)), boldString: "", font: page4Pay.titleLabel!.font), for: .normal)
            } else {
                self.setPaymentButton()
            }
            
            RideDB.child("Requests").child(request!._id!).child("price").observeSingleEvent(of: .value, with: { (snapshot) in
                if let value = snapshot.value as? [String: Double] {
                    self.price = value
                    self.page4Price.attributedText = self.attributedText(withString: String(format: "Price: £%.2f", value["total"]!), boldString: "Price", font: self.page4Price.font)
                }
            })
            
            let date = Date(timeIntervalSince1970: Double(request!._time))
            let dateFormatter = DateFormatter()
            dateFormatter.timeStyle = .short
            dateFormatter.dateStyle = .medium
            
            page4Time.attributedText = attributedText(withString: String(format: "Pickup Time: %@", dateFormatter.string(from: date)), boldString: "Pickup Time", font: page4Time.font)
            
            page4Passengers.attributedText = attributedText(withString: String(format: "Passengers: %@", String(request!._passengers)), boldString: "Passengers", font: page4Passengers.font)
            
            self.getCar(user: request!._driver) { (car) in
                self.page4Car.attributedText = self.attributedText(withString: String(format: "Car: %@, \n   %@", car._carType, car._carRegistration), boldString: "Car", font: self.page4Car.font)
            }
            
            let to = MKPointAnnotation()
            to.coordinate = request!._to
            to.title = request?._toName
            
            let from = MKPointAnnotation()
            from.coordinate = self.request!._from
            from.title = request?._fromName
            
            self.page4MapView.addAnnotations([to, from])
            self.page4MapView.showAnnotations([to, from], animated: true)
            
            let directionsRequest = MKDirections.Request()
            let sourcePlacemark = MKPlacemark(coordinate: self.request!._to)
            let destinationPlacemark = MKPlacemark(coordinate: self.request!._from)
            let source = MKMapItem(placemark: sourcePlacemark)
            let destination = MKMapItem(placemark: destinationPlacemark)
            directionsRequest.destination = destination
            directionsRequest.source = source
            directionsRequest.transportType = .automobile
            directionsRequest.departureDate = date
            
            let directions = MKDirections(request: directionsRequest)
            directions.calculate(completionHandler: { (response, error) in
                if let routeResponse = response?.routes {
                    let quickestRouteForSegment: MKRoute = routeResponse.sorted(by: {$0.expectedTravelTime < $1.expectedTravelTime})[0]
                    self.page4MapView.addOverlay((quickestRouteForSegment.polyline), level: MKOverlayLevel.aboveRoads)
                }
            })
            
            if self.request?.status == 4 {
                self.page4Cancel.isHidden = true
            }
        } else if (payTitle != nil) {            
            self.paymentContext.delegate = self
            self.paymentContext.hostViewController = self
            
            let cancel = UIButton()
            cancel.setTitleColor(UIColor(named: "Accent"), for: .normal)
            cancel.setTitle("Cancel", for: .normal)
            cancel.addTarget(self, action: Selector(("closePay")), for: .touchUpInside)
            
            let leftBarButton = UIBarButtonItem()
            leftBarButton.customView = cancel
            self.navigationItem.leftBarButtonItem = leftBarButton
            
            payTitle.text = payTitle.text! + userName!
            payButton.backgroundColor = payButton.backgroundColor?.withAlphaComponent(0.75)
            if self.request?.status == 4 {
                payPrice.text = String(format: "£%.2f", self.price["split_total"]!)
            } else {
                payPrice.text = String(format: "£%.2f", self.price["total"]!)
                
                let input = UITextField(frame: CGRect(x: 0, y: 0, width: 303, height: 40))
                input.placeholder = " + Select users to split the payment"
                input.borderWidth = 1
                input.borderColor = UIColor(named: "Accent")
                input.leftViewMode = UITextField.ViewMode.always
                input.leftView = UIView(frame:CGRect(x:0, y:0, width:10, height:10))
                input.addTarget(self, action: #selector(showAddUsers(textfield:)), for: .editingDidBegin)
                self.payUsers.addSubview(input)
                self.payUsers.contentSize = CGSize(width: self.payUsers.frame.width, height: self.payUsers.contentSize.height + 50)
            }
        }
        
        if request?._driver == Auth.auth().currentUser!.uid {
            RideDB.child("Users").child(Auth.auth().currentUser!.uid).child("requests").child("received").child((request?._id)!).child("new").setValue(false)
        } else {
            RideDB.child("Users").child(Auth.auth().currentUser!.uid).child("requests").child("sent").child((request?._id)!).child("new").setValue(false)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if payTitle != nil {
            self.navigationController?.navigationBar.setBackgroundImage(nil, for: .default)
            self.navigationController?.navigationBar.shadowImage = UIImage()
            self.navigationController?.navigationBar.barTintColor = .white
            self.navigationController?.navigationBar.isTranslucent = true
            self.navigationController?.view.backgroundColor = UIColor(named: "Main")
        } else {
            self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
            self.navigationController?.navigationBar.shadowImage = UIImage()
            self.navigationController?.navigationBar.isTranslucent = true
            self.navigationController?.view.backgroundColor = .clear
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.navigationController?.navigationBar.setBackgroundImage(nil, for: .default)
        self.navigationController?.navigationBar.shadowImage = nil
        self.navigationController?.navigationBar.isTranslucent = true
        self.navigationController?.view.backgroundColor = UIColor(named: "Main")
    }
    
    // Mark: - Actions
    
    @IBAction func accept(_ sender: Any) {
        RideDB.child("Requests").child(request!._id!).child("status").setValue(2)
        RideDB.child("Users").child((request?._driver)!).child("requests").child("received").child((request?._id)!).child("new").setValue(true)
        
        requestsViewControllerDelegate.performSegue(withIdentifier: "moveToSentRequest_page4", sender: self)
    }
    
    @IBAction func decline(_ sender: Any) {
        self.cancelRide()
    }
    
    @IBAction func cancel(_ sender: Any) {
        let alert = UIAlertController(title: "Confirm Cancel", message: "Are you sure you want to cancel this Ride?", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Yes", style: .destructive, handler: { (action: UIAlertAction) in
            self.cancelRide()
        }))
        alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
        
        self.present(alert, animated: true)
    }
    
    @IBAction func showPayPage(_ sender: Any) {
        self.performSegue(withIdentifier: "showPay", sender: nil)
    }
    
    @IBAction func selectPaymentMethod(_ sender: Any) {
        guard !STPPaymentConfiguration.shared().publishableKey.isEmpty else {
            os_log("No value assigned to publishableKey in AppDelegate", log: OSLog.default, type: .error)
            return
        }
                
//        self.navigationController?.navigationBar.setBackgroundImage(nil, for: .default)
//        self.navigationController?.navigationBar.shadowImage = nil
//        self.navigationController?.navigationBar.isTranslucent = true
//        self.navigationController?.view.backgroundColor = UIColor(named: "Main")
        self.paymentContext.presentPaymentOptionsViewController()
    }
    
    @IBAction func pay(_ sender: Any) {
        if self.paymentContext.selectedPaymentOption != nil {
            self.vSpinner = self.showSpinner(onView: self.view)
            if self.price["split_total"] != nil || self.request?.status == 4 {
                self.paymentContext.paymentAmount = Int(String(format: "%.2f", self.price["split_total"]!).replacingOccurrences(of: ".", with: ""))!
            } else {
                self.paymentContext.paymentAmount = Int(String(format: "%.2f", self.price["total"]!).replacingOccurrences(of: ".", with: ""))!
            }
            self.paymentContext.paymentCurrency = Constants.defaultCurrency
            self.paymentContext.requestPayment()
        }
    }
    
    @objc func showAddUsers(textfield: UITextField) {
        view.endEditing(true)
        self.performSegue(withIdentifier: "showAddUserPay", sender: self)
    }
    
    // MARK: - Map View
    func mapView(_ mapView: MKMapView, rendererFor
        overlay: MKOverlay) -> MKOverlayRenderer {
        
        let renderer = MKPolylineRenderer(overlay: overlay)
        renderer.strokeColor = UIColor(named: "Accent")
        renderer.lineWidth = 5.0
        return renderer
    }
    
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        print("Preparing to segue: \(String(describing: segue.identifier))")
        
        if segue.identifier == "showPay" {
            let navigationController = segue.destination as! UINavigationController
            let sentRequestViewController = navigationController.viewControllers.first as! SentRequestViewController
            sentRequestViewController.userManager = userManager
            sentRequestViewController.price = self.price
            sentRequestViewController.request = self.request
            sentRequestViewController.userName = self.userName
            sentRequestViewController.completePaymentDelegate = self
        }
        
        if segue.identifier == "showAddUserPay" {
            let navigationController = segue.destination as! UINavigationController
            let createGroupTableViewController = navigationController.viewControllers.first as! CreateGroupTableViewController
            createGroupTableViewController.userManager = userManager
            createGroupTableViewController.paymentDelegate = self
            createGroupTableViewController.paymentMode = true
            createGroupTableViewController.connections = self.connections
            createGroupTableViewController.driver = self.request!._driver
        }
        
        if let navigationViewController = segue.destination as? UINavigationController {
            if let requestsChatViewController = navigationViewController.viewControllers.first as? RequestsChatViewController {
                requestsChatViewController.userManager = userManager
                requestsChatViewController.request = request
                requestsChatViewController.userName = userName
            }
        }
    }
    
    @objc func closePay() {
        self.dismiss(animated: true) {
            print("Setting nav to clear")
            self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
            self.navigationController?.navigationBar.shadowImage = UIImage()
            self.navigationController?.navigationBar.isTranslucent = true
            self.navigationController?.view.backgroundColor = .clear
        }
    }
    
    func dismissPayController() {
        self.dismiss(animated: true) {
            if self.completePaymentDelegate != nil {
                self.completePaymentDelegate?.setPaymentButton()
            }
        }
    }
    
    func addUsers(users: [String: Array<Connection>]) {
        for textField in self.textFields {
            textField.removeFromSuperview()
            self.textFields.remove(at: self.textFields.index(of: textField)!)
            self.payUsers.contentSize = CGSize(width: self.payUsers.frame.width, height: 50)
        }
        for user in users["selected"]! {
            let input = UITextField(frame: CGRect(x: 0, y: (50 * (users["selected"]!.index(of: user)! + 1)), width: 303, height: 40))
            input.isEnabled = false
            input.text = user._userName
            input.borderWidth = 1
            input.borderColor = UIColor(named: "Accent")
            input.leftViewMode = UITextField.ViewMode.always
            input.leftView = UIView(frame:CGRect(x: 0, y: 0, width: 10, height: 10))
            self.textFields.append(input)
            self.payUsers.addSubview(input)
            self.payUsers.contentSize = CGSize(width: self.payUsers.frame.width, height: self.payUsers.contentSize.height + 50)
        }
        
        var splitPriceTotal = self.splitPrice(users: users["selected"]!.count + 1, price: self.price["total"]!)
        let splitPriceUser = self.splitPrice(users: users["selected"]!.count + 1, price: self.price["user"]!)
        
        let splitPriceFees: Double = splitPriceTotal - splitPriceUser
        let stripeFees: Double = 0.2 + (splitPriceTotal * 0.029)
        
        print("T:", splitPriceTotal)
        print("U:", splitPriceUser)
        print("SPF:", splitPriceFees)
        print("SF:", stripeFees)
        print("Profit:", splitPriceFees - stripeFees)
        
        if splitPriceFees - stripeFees < 1 / Double(users["selected"]!.count + 1) {
            splitPriceTotal = splitPriceUser + stripeFees + 1 / Double(users["selected"]!.count + 1)
        }
        
        if splitPriceTotal != self.price["total"] {
            self.price["split_total"] = splitPriceTotal.rounded(digits: 2)
            self.price["split_user"] = splitPriceUser.rounded(digits: 2)
            self.paySplitPrice.text = String(format: "You pay: £%.2f", splitPriceTotal)
        } else {
            self.price["split"] = nil
            self.paySplitPrice.text = ""
        }
        self.connections = users
    }
    
    func setPaymentButton() {
        if self.page4Pay != nil {
            self.page4Pay.isEnabled = false
            self.page4Pay.backgroundColor = .clear
            self.page4Pay.borderWidth = 2
            self.page4Pay.borderColor = .white
            self.page4Pay.setAttributedTitle(NSAttributedString(string: "\u{2713} Payment Successful", attributes: [NSAttributedString.Key.foregroundColor : UIColor.white, NSAttributedString.Key.font: self.page4Pay.titleLabel?.font as Any]), for: .disabled)
        }
    }
    
    // MARK - Payment
    
    func paymentContext(_ paymentContext: STPPaymentContext, didCreatePaymentResult paymentResult: STPPaymentResult, completion: @escaping STPErrorBlock) {
        self.getStripeAccountID(destination: self.request!._driver) { destination in
            self.RideDB.child("stripe_customers").child(Auth.auth().currentUser!.uid).observeSingleEvent(of: .value, with: { snapshot in
                if let customerID = (snapshot.value as! [String: Any])["customer_id"] as? String {
                    var total: Double?
                    var user: Double?
                    if self.price["split_total"] != nil && self.price["split_user"] != nil || self.request?.status == 4 {
//                        StripeClient.shared.completeCharge(paymentResult, customer: customerID, destination: destination, total: self.price["split_total"]!, user: self.price["split_user"]!, requestID: self.request!._id!, completion: completion)
                        total = self.price["split_total"]
                        user = self.price["split_user"]
                    } else {
//                        StripeClient.shared.completeCharge(paymentResult, customer: customerID, destination: destination, total: self.price["total"]!, user: self.price["user"]!, requestID: self.request!._id!, completion: completion)
                        total = self.price["total"]
                        user = self.price["user"]
                    }
                    
                    StripeClient.shared.completeCharge(paymentResult, customer: customerID, destination: destination, total: total!, user: user!, requestID: self.request!._id!) { (error) in
                        print("Error:", error)
                        guard error != nil else {
                            completion(error)
                            return
                        }
                        
                        if let sources = (snapshot.value as! [String: Any])["sources"] as? [String: [String: Any]] {
                            var found = false
                            for source in sources.values {
                                if let id = source["id"] as? String {
                                    if id == paymentResult.paymentMethod.stripeId {
                                        found = true
                                    }
                                }
                            }
                            
                            if !found {
                                let appDelegate = UIApplication.shared.delegate as? AppDelegate
                                appDelegate?.getSecretKey(completion: { (secretKey) in
                                    Alamofire.request("https://api.stripe.com/v1/customers/\(customerID)/sources/\(paymentResult.paymentMethod.stripeId)", method: .get, headers: ["Authorization": "Bearer \(secretKey)"]).responseJSON(completionHandler: { response in
                                        if let error = response.error {
                                            print(error)
                                        } else {
                                            if let result = response.result.value as? NSDictionary {
                                                self.RideDB.child("stripe_customers").child(Auth.auth().currentUser!.uid).child("sources").childByAutoId().setValue(result)
                                            }
                                        }
                                    })
                                })
                            }
                        }
                        completion(nil)
                    }
                }
            })
        }
    }
    
    func paymentContext(_ paymentContext: STPPaymentContext, didFinishWith status: STPPaymentStatus, error: Error?) {
        self.removeSpinner(spinner: self.vSpinner!)
        switch status {
        case .success:
            if let errorDescription = error?._userInfo?["description"] {
                let alert = UIAlertController(title: "Error", message: (errorDescription as! String), preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            } else {
                if self.price["split_total"] != nil && self.connections["selected"] != nil {
                    RideDB.child("Requests").child(self.request!._id!).child("status").setValue(4)
                    RideDB.child("Requests").child(self.request!._id!).child("price").setValue(self.price)
                    var i = 0
                    for user in self.connections["selected"]! {
                        RideDB.child("Requests").child(self.request!._id!).child("split").child(String(i)).setValue(user._connectionUser)
                        RideDB.child("Users").child(user._connectionUser).child("requests").child("sent").child((request?._id)!).setValue(["new": true, "split": true, "timestamp": ServerValue.timestamp()])
                        i += 1
                    }
                } else {
                    RideDB.child("Requests").child(self.request!._id!).child("status").setValue(3)
                    RideDB.child("Users").child((request?._driver)!).child("requests").child("received").child((request?._id)!).child("new").setValue(true)
                }
                self.dismissPayController()
            }
        case .error:
            // Present error to user
            if let requestRideError = error as? StripeClient.RequestRideError {
                switch requestRideError {
                case .missingBaseURL:
                    // Fail silently until base url string is set
                    os_log("No value assigned to `StripeClient.shared.baseURLString`", log: OSLog.default, type: .error)
                case .invalidResponse:
                    // Missing response from backend
                    os_log("Missing or malformed response when attempting to `MainAPIClient.shared.createCustomerKey`. Please check internet connection and backend response formatting.", log: OSLog.default, type: .error)
                    let alert = UIAlertController(title: "Error", message: "Could not make payment", preferredStyle: UIAlertController.Style.alert)
                    alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                }
            } else if let errorDescription = error?._userInfo?["description"] {
                os_log("Error making payment: `%@`", log: OSLog.default, type: .error, errorDescription)
                let alert = UIAlertController(title: "Error", message: (errorDescription as! String), preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            } else {
                // Use generic error message
                os_log("Unrecognized error while loading payment context: `%@`", log: OSLog.default, type: .error, error?.localizedDescription ?? "")
                let alert = UIAlertController(title: "Error", message: "Could not make payment", preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        case .userCancellation:
            os_log("Payment cancelled", log: OSLog.default, type: .debug)
        }
    }
    
    func paymentContext(_ paymentContext: STPPaymentContext, didFailToLoadWithError error: Error) {
        if let customerKeyError = error as? StripeClient.CustomerKeyError {
            switch customerKeyError {
            case .missingBaseURL:
                // Fail silently until base url string is set
                os_log("No value assigned to `StripeClient.shared.baseURLString`", log: OSLog.default, type: .error)
            case .invalidResponse:
                // Use customer key specific error message
                os_log("Missing or malformed response when attempting to `MainAPIClient.shared.createCustomerKey`. Please check internet connection and backend response formatting.", log: OSLog.default, type: .error)
                
                let alert = UIAlertController(title: "Error", message: "Could not retrieve customer information", preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(title: "Retry", style: .default, handler: { (action) in
                    paymentContext.retryLoading()
                }))
                self.present(alert, animated: true, completion: nil)
            }
        } else {
            // Use generic error message
            os_log("Unrecognized error while loading payment context: `%@`", log: OSLog.default, type: .error, error.localizedDescription)
            
            let alert = UIAlertController(title: "Error", message: "Could not retrieve customer information", preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "Retry", style: .default, handler: { (action) in
                paymentContext.retryLoading()
            }))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func paymentContextDidChange(_ paymentContext: STPPaymentContext) {
        guard paymentContext.selectedPaymentOption != nil else {
            self.payMethod.setTitle("Select Payment Method", for: .normal)
            self.payButton.isEnabled = false
            self.payButton.backgroundColor = UIColor(named: "Accent")?.withAlphaComponent(0.75)
            return
        }
        
//        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
//        self.navigationController?.navigationBar.shadowImage = UIImage()
//        self.navigationController?.navigationBar.isTranslucent = true
//        self.navigationController?.view.backgroundColor = .clear
        
        self.payMethod.setTitle(paymentContext.selectedPaymentOption?.label, for: .normal)
        self.payButton.isEnabled = true
        self.payButton.backgroundColor = UIColor(named: "Accent")
    }
    
    
    // MARK - Private functions
    
    private func getStripeAccountID(destination: String, completion: @escaping (String)->()) {
        RideDB.child("stripe_customers").child(destination).observeSingleEvent(of: .value, with: { snapshot in
            if snapshot.hasChild("account_id") {
                if let value = snapshot.value as? [String: Any] {
                    completion(value["account_id"] as! String)
                }
            }
        })
    }
    
    private func userHasCard(completion: @escaping (Bool)->()) {
        RideDB.child("stripe_customers").child(Auth.auth().currentUser!.uid).child("sources").observeSingleEvent(of: .value, with: { (snapshot) in
            completion(snapshot.hasChildren())
        })
    }
    
    private func getCar(user: String, completion: @escaping (Car)->()) {
        RideDB.child("Users").child(user).child("car").observeSingleEvent(of: .value, with: { (snapshot) in
            if let value = snapshot.value as? [String: String] {
                completion(Car(type: value["type"]!, mpg: value["mpg"]!, seats: value["seats"]!, registration: value["registration"]!))
            }
        })
    }
    
    private func cancelRide() {
        RideDB.child("Requests").child(request!._id!).child("deleted").setValue(true)
        RideDB.child("Requests").child(request!._id!).child("status").setValue(-1)
        RideDB.child("Users").child(request!._sender!).child("requests").child("sent").child(request!._id!).removeValue()
        self.navigationController?.popViewController(animated: true)
    }
    
    private func splitPrice(users: Int, price: Double, _ n: Int = 0) -> Double {
        let individual = (price / Double(users)).rounded(digits: 2)
        if individual < 0.01 {
            return 0.01
        }
        
        let diff = (price - (individual * Double(users))).rounded(digits: 2)
        if diff > 0 && n < 10 {
            return individual + splitPrice(users: users, price: diff, n + 1).rounded(digits: 2)
        }
        
        return individual
    }
    
    private func attributedText(withString string: String, boldString: String, font: UIFont) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: string,
                                                         attributes: [NSAttributedString.Key.font: font])
        let boldFontAttribute: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: font.pointSize)]
        let range = (string as NSString).range(of: boldString)
        attributedString.addAttributes(boldFontAttribute, range: range)
        return attributedString
    }
}

extension SentRequestViewController: STPAddCardViewControllerDelegate {
    func addCardViewControllerDidCancel(_ addCardViewController: STPAddCardViewController) {
        navigationController?.popViewController(animated: true)
    }
    
    func addCardViewController(_ addCardViewController: STPAddCardViewController, didCreatePaymentMethod paymentMethod: STPPaymentMethod, completion: @escaping STPErrorBlock) {
        RideDB.child("stripe_customers").child(Auth.auth().currentUser!.uid).child("sources").childByAutoId().child("token").setValue(paymentMethod.stripeId) { (error, ref) -> Void in
            if let error = error {
                completion(error)
            } else {
                completion(nil)
            }
        }
    }
}

extension SentRequestViewController: UserManagerClient {
    func setUserManager(_ userManager: UserManagerProtocol) {
        self.userManager = userManager
    }
}

extension Double {
    func rounded(digits: Int) -> Double {
        let multiplier = pow(10.0, Double(digits))
        return (self * multiplier).rounded() / multiplier
    }
}
