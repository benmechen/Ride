//
//  ReceivedRequestViewController.swift
//  Ride
//
//  Created by Ben Mechen on 10/02/2019.
//  Copyright © 2019 Fuse Apps. All rights reserved.
//

import UIKit
import Firebase
import Crashlytics
import MapKit
import CoreLocation
import Alamofire

class ReceivedRequestViewController: UIViewController, MKMapViewDelegate {

    var userManager: UserManagerProtocol!
    lazy var RideDB = Database.database().reference()
    var request: Request? = nil
    var userName: String? = nil
    var distance: CLLocationDistance? = nil
    var fees: Double = 0.15
    var min: Double = 1.0
    var message: String = ""
    var fuel: Double = 0.0
    lazy var geocoder = CLGeocoder()
    var price: [String: Double] = [:]
    let currencyFormatter = NumberFormatter()
    var euroToPound = 1.00
    var currency = 1.00
    var vSpinner: UIView?
    
    @IBOutlet weak var page1Title: UILabel!
    @IBOutlet weak var page1Time: UILabel!
    @IBOutlet weak var page1Passengers: UILabel!
    @IBOutlet weak var page1MapView: MKMapView!
    @IBOutlet weak var page1Accept: UIButton!
    
    @IBOutlet weak var page2Title: UILabel!
    
    @IBOutlet weak var page3Title: UILabel!
    @IBOutlet weak var page3Total: UILabel!
    @IBOutlet weak var page3Price: UITextField!
    @IBOutlet weak var page3Fuel: UILabel!
    @IBOutlet weak var page3Profit: UILabel!
    @IBOutlet weak var page3Fees: UILabel!
    @IBOutlet weak var page3Send: UIButton!
    @IBOutlet weak var page3Plus1: UILabel!
    @IBOutlet weak var page3Plus2: UILabel!
    
    @IBOutlet weak var page4Time: UILabel!
    @IBOutlet weak var page4Price: UILabel!
    @IBOutlet weak var page4Passengers: UILabel!
    @IBOutlet weak var page4Status: UILabel!
    @IBOutlet weak var page4MapView: MKMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        currencyFormatter.usesGroupingSeparator = true
        currencyFormatter.numberStyle = .currency
        // localize to your grouping and decimal separator
        currencyFormatter.locale = Locale.current

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
            to.title = (request?._toName ?? "") + "(Drop off)"
            
            let from = MKPointAnnotation()
            from.coordinate = self.request!._from
            from.title = (request?._fromName ?? "") + "(Pick up)"
            
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
                if let routeResponse = response?.routes {
                    let quickestRouteForSegment: MKRoute = routeResponse.sorted(by: {$0.expectedTravelTime < $1.expectedTravelTime})[0]
                    self.page1Accept.isEnabled = true
                    self.page1MapView.addOverlay(quickestRouteForSegment.polyline, level: MKOverlayLevel.aboveRoads)
                }
            })
        } else if (page2Title != nil) {
            if request?.status == -1 {
                page2Title.text = "This Ride request has been declined by " + String(userName?.split(separator: " ").first ?? "the other user")
            } else {
                page2Title.text = page2Title.text! + (userName?.split(separator: " ").first ?? "the other user")
            }
        } else if (page3Title != nil) {
            RideDB.child("Requests").child(request!._id!).observeSingleEvent(of: .value, with: { (snapshot) in
                if snapshot.hasChild("price")  {
                    self.page3Sent()
                } else {
                    self.userManager?.getCurrentUser(completion: { (success, user) in
                        guard success && user != nil else {
                            return
                        }
                        
                        guard user?.car._carMPG != "" && user?.car._carMPG != "nil" else {
                            let alert = UIAlertController(title: "Error", message: "User's MPG not set", preferredStyle: .alert)
                            
                            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { (action) in
                                self.navigationController?.popViewController(animated: true)
                            }))
                            self.present(alert, animated: true)
                            return
                        }
                        
                        self.vSpinner = self.showSpinner(onView: self.view)
                        
                        self.RideDB.child("fuel").observeSingleEvent(of: .value, with: { (snapshot) in
                            if let value = snapshot.value {
                                let directionsRequest = MKDirections.Request()
                                let sourcePlacemark = MKPlacemark(coordinate: self.request!._to)
                                let destinationPlacemark = MKPlacemark(coordinate: self.request!._from)
                                let source = MKMapItem(placemark: sourcePlacemark)
                                let destination = MKMapItem(placemark: destinationPlacemark)
                                directionsRequest.destination = destination
                                directionsRequest.source = source
                                directionsRequest.transportType = .automobile
                                
                                let directions = MKDirections(request: directionsRequest)
                                directions.calculate(completionHandler: { (response, error) in
                                    if let routeResponse = response?.routes {
                                        let quickestRouteForSegment: MKRoute = routeResponse.sorted(by: {$0.expectedTravelTime < $1.expectedTravelTime})[0]
                                        self.fuel = self.calculateFuelCost(distance: quickestRouteForSegment.distance, mpg: Int(user!.car._carMPG)!, fuel: value as! Double)
                                        NSLog("http://data.fixer.io/api/latest?access_key=d10ce9ff8cb3863166fc5fcc6af7a2d6&base=GBP&symbols=\(Locale.current.currencyCode!)")
                                        Alamofire.request("http://data.fixer.io/api/latest?access_key=d10ce9ff8cb3863166fc5fcc6af7a2d6&base=EUR&symbols=EUR,GBP,\(Locale.current.currencyCode!)", method: .get).responseJSON(completionHandler: { (response) in                                            
                                            if let result = response.result.value, let json = result as? [String: AnyObject] {
                                                guard (json["success"] as! Bool) == true else {
                                                    self.removeSpinner(spinner: self.vSpinner!)
                                                    NSLog(response.error?.localizedDescription ?? "")
                                                    let alert = UIAlertController(title: "Error", message: "Could not fetch currency rates", preferredStyle: .alert)
                                                    alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: { (_) in
                                                        self.navigationController?.popViewController(animated: true)
                                                    }))
                                                    self.present(alert, animated: true, completion: nil)
                                                    return
                                                }
                                                
                                                if var rates = json["rates"] as? [String: Double] {
                                                    if let euroToPound = rates["GBP"], let currency = rates[(Locale.current.currencyCode)!] {
                                                        self.removeSpinner(spinner: self.vSpinner!)
                                                        self.euroToPound = euroToPound
                                                        self.currency = currency
                                                        self.fuel = self.convertToLocalCurrency(pound: self.fuel)
                                                        self.min = self.convertToLocalCurrency(pound: self.min)
                                                        self.page3Price.text = self.currencyFormatter.string(from: NSNumber(value: self.fuel))
                                                        self.page3Fuel.attributedText = self.attributedText(withString: String(format: "Estimated Fuel Cost: %@", self.currencyFormatter.string(from: NSNumber(value: self.fuel))!), boldString: "Estimated Fuel Cost", font: self.page3Fuel.font!)
                                                        self.updateFees(self)
                                                        self.page3Price.text = String(format: "%@", self.currencyFormatter.string(from: NSNumber(value: self.fuel + self.calculateFee(cost: self.fuel)))!)
                                                    }
                                                }
                                            }
                                        })
                                    }
                                })
                            }
                        })
                    })
                    
                    self.page3Total.text = self.page3Total.text! + (self.userName?.split(separator: " ").first ?? "user")
                    
                    let toolBar = UIToolbar()
                    toolBar.sizeToFit()
                    
                    let flexibleButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil)
                    let doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(ReceivedRequestViewController.dismissKeyboard))
                    toolBar.setItems([flexibleButton, doneButton], animated: false)
                    toolBar.isUserInteractionEnabled = true
                    
                    self.page3Price.inputAccessoryView = toolBar
                }
            })
        } else if (page4Time != nil) {
            page4MapView.delegate = self
            
            let date = Date(timeIntervalSince1970: Double(request!._time))
            let dateFormatter = DateFormatter()
            dateFormatter.timeStyle = .short
            dateFormatter.dateStyle = .medium
            
            page4Time.attributedText = attributedText(withString: String(format: "Pickup Time: %@", dateFormatter.string(from: date)), boldString: "Pickup Time", font: page4Time.font)
            
            RideDB.child("Requests").child(request!._id!).child("price").observeSingleEvent(of: .value, with: { (snapshot) in
                if let value = snapshot.value as? [String: Double] {
                    self.page4Price.attributedText = self.attributedText(withString: String(format: "Price: £%.2f", value["total"]!), boldString: "Price", font: self.page4Price.font)
                }
            })
            
            page4Passengers.attributedText = attributedText(withString: String(format: "Passengers: %d", request!._passengers), boldString: "Passengers", font: page4Passengers.font)
            
            if self.request?.status != 4 {
                var status = "Unpaid"
                if self.request?.status == 3 {
                    status = "Payment received"
                }
                page4Status.attributedText = attributedText(withString: String(format: "Status: %@", status), boldString: "Status", font: page4Status.font)
            } else {
                var paidCount = 1
                RideDB.child("Requests").child(self.request!._id!).child("split").observeSingleEvent(of: .value, with: { snapshot in
                    if let users = snapshot.value as? [String: Bool] {
                        for user in users.keys {
                            if users[user]! {
                                paidCount += 1
                            }
                        }
                        
                        if paidCount >= users.count + 1 {
                            self.page4Status.attributedText = self.attributedText(withString: String(format: "Status: %@", "Payment received"), boldString: "Status", font: self.page4Status.font)
                        } else {
                            self.page4Status.attributedText = self.attributedText(withString: String(format: "Status: %@", "\(paidCount)/\(users.count + 1) users have paid"), boldString: "Status", font: self.page4Status.font)
                        }
                    }
                })
            }
            
            let to = MKPointAnnotation()
            to.coordinate = request!._to
            to.title = (request?._toName ?? "") + "(Drop off)"
            
            let from = MKPointAnnotation()
            from.coordinate = self.request!._from
            from.title = (request?._fromName ?? "") + "(Pick up)"
            
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
                    self.page4MapView.addOverlay(quickestRouteForSegment.polyline, level: MKOverlayLevel.aboveRoads)
                }
            })
        }
        
        if request?._driver == Auth.auth().currentUser!.uid {
            RideDB.child("Users").child(Auth.auth().currentUser!.uid).child("requests").child("received").child((request?._id)!).child("new").setValue(false)
        } else {
            RideDB.child("Users").child(Auth.auth().currentUser!.uid).child("requests").child("sent").child((request?._id)!).child("new").setValue(false)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        RideDB.child("fees").observeSingleEvent(of: .value, with: { (snapshot) in
            if let value = snapshot.value as? Double {
                self.fees = value
            }
        })
        
        RideDB.child("min").observeSingleEvent(of: .value, with: { (snapshot) in
            if let value = snapshot.value as? Double {
                self.min = value
            }
        })
        
        RideDB.child("message").observeSingleEvent(of: .value, with: { (snapshot) in
            if let value = snapshot.value as? String {
                self.message = value
            }
        })
        
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
        self.navigationController?.navigationBar.isTranslucent = true
        self.navigationController?.view.backgroundColor = .clear
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.navigationController?.navigationBar.setBackgroundImage(nil, for: .default)
        self.navigationController?.navigationBar.shadowImage = nil
        self.navigationController?.navigationBar.isTranslucent = true
        self.navigationController?.view.backgroundColor = UIColor(named: "Main")
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
        if let navigationViewController = segue.destination as? UINavigationController {
            if let requestsChatViewController = navigationViewController.viewControllers.first as? RequestsChatViewController {
                requestsChatViewController.userManager = userManager
                requestsChatViewController.request = request
                requestsChatViewController.userName = userName
            }
        }
        
        if segue.identifier == "moveToReceivedRequest_page1-3" || segue.identifier == "moveToReceivedRequest_page3-4" {
            if let receivedRequestsViewController = segue.destination as? ReceivedRequestViewController {
                receivedRequestsViewController.userManager = userManager
                receivedRequestsViewController.request = request
                receivedRequestsViewController.userName = userName
            }
        }
    }
    
    
    // MARK: - Actions
    @IBAction func accept(_ sender: Any) {
        self.performSegue(withIdentifier: "moveToReceivedRequest_page1-3", sender: self)
    }
    
    @IBAction func updateFees(_ sender: Any) {
        var currentPrice = self.currencyFormatter.number(from: page3Price.text!)?.doubleValue
        
        if (currentPrice ?? 0.0) < self.min {
            page3Price.text = self.currencyFormatter.string(from: NSNumber(value: self.min))
            currentPrice = self.min
        }
        
        if currentPrice != nil {
            page3Fees.attributedText = attributedText(withString: String(format: "Ride Fees: %1@ %2@", self.currencyFormatter.string(from: NSNumber(value: self.calculateFee(cost: currentPrice!)))!, self.message), boldString: "Ride Fees", font: UIFont(name: "HelveticaNeue-Thin", size: 17)!)
            
            var profit = (currentPrice ?? 1 ) - self.calculateFee(cost: currentPrice!) - self.fuel
            if profit < 0 {
                profit = 0
            }
            
            page3Profit.attributedText = attributedText(withString: String(format: "Your Profit: %@", self.currencyFormatter.string(from: NSNumber(value: profit))!), boldString: "Your Profit", font: UIFont(name: "HelveticaNeue-Thin", size: 17)!)
            
            self.price["total"] = currentPrice
            self.price["fees"] = self.calculateFee(cost: currentPrice!)
            self.price["user"] = profit + self.fuel
        }
    }
    
    @IBAction func send(_ sender: Any) {
        RideDB.child("Requests").child(request!._id!).child("status").setValue(1)
        RideDB.child("Users").child((request?._sender)!).child("requests").child("sent").child((request?._id)!).child("new").setValue(true)
        RideDB.child("Requests").child(request!._id!).child("price").setValue(self.price)
        // RideDB?.child("Requests").child(request!._id!).child("price").setValue(Double(removeSpecialCharsFromString(text: page3Price.text!)))
        
        self.page3Sent()
    }
    
    @IBAction func openInMaps(_ sender: Any) {
        let from = MKMapItem(placemark: MKPlacemark(coordinate: request!._from, addressDictionary:nil))
        from.name = "Pick up"
        
        let to = MKMapItem(placemark: MKPlacemark(coordinate: request!._to, addressDictionary:nil))
        to.name = "Drop off"
        
        MKMapItem.openMaps(with: [from, to], launchOptions: [MKLaunchOptionsDirectionsModeKey : MKLaunchOptionsDirectionsModeDriving])
        
        //        to.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey : MKLaunchOptionsDirectionsModeDriving])
    }
    
    @IBAction func decline(_ sender: Any) {
        RideDB.child("Requests").child(request!._id!).child("deleted").setValue(true)
        RideDB.child("Requests").child(request!._id!).child("status").setValue(-1)
        RideDB.child("Users").child(request!._driver!).child("requests").child("received").child(request!._id!).removeValue()
        self.navigationController?.popViewController(animated: true)
    }
    
    // MARK: - Private functions
    @IBAction func priceFieldDidChange(_ sender: Any) {
        if let amountString = page3Price.text?.currencyInputFormatting() {
            page3Price.text = amountString
        }
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc func dismissView() {
        self.navigationController?.popViewController(animated: true)
//        self.dismiss(animated: true, completion: nil)
    }
    
    func convertToLocalCurrency(pound: Double) -> Double {
        return (pound / euroToPound) * currency
    }
    
    func page3Sent() {
        page3Total.isHidden = true
        page3Profit.isHidden = true
        page3Fees.isHidden = true
        page3Price.isHidden = true
        page3Plus1.isHidden = true
        page3Plus2.isHidden = true
        page3Send.isHidden = true
        page3Title.text = "Your quote has been sent."
        
        page3Fuel.numberOfLines = 3
        page3Fuel.lineBreakMode = .byWordWrapping
        page3Fuel.text = "Once it has been accepted by " + String((userName?.split(separator: " ").first ?? "the user")) + ", you will receive a notification."
    }
    
    func removeSpecialCharsFromString(text: String) -> String {
        let okayChars : Set<Character> =
            Set("0123456789.")
        return String(text.filter {okayChars.contains($0) })
    }
    
    func calculateFuelCost(distance: CLLocationDistance, mpg: Int, fuel: Double) -> Double {
        return self.convertToLocalCurrency(pound: (fuel * (((distance / 1609.344) / Double(mpg)) * 4.546)) / 100)
    }
    
    func calculateFee(cost: Double) -> Double {
        let fee = cost * fees
        
        if fee < self.min {
            return self.min
        }
        
        return fee
    }
    
    func attributedText(withString string: String, boldString: String, font: UIFont) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: string,
                                                         attributes: [NSAttributedString.Key.font: font])
        let boldFontAttribute: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: font.pointSize)]
        let range = (string as NSString).range(of: boldString)
        attributedString.addAttributes(boldFontAttribute, range: range)
        return attributedString
    }
}

extension ReceivedRequestViewController: UserManagerClient {
    func setUserManager(_ userManager: UserManagerProtocol) {
        self.userManager = userManager
    }
}

extension String {
    
    // formatting text for currency textField
    func currencyInputFormatting() -> String {
        
        var number: NSNumber!
        let formatter = NumberFormatter()
        formatter.usesGroupingSeparator = true
        formatter.numberStyle = .currencyAccounting
//        formatter.currencySymbol = "£"
        formatter.locale = Locale.current
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        
        var amountWithPrefix = self
        
        // remove from String: "$", ".", ","
        let regex = try! NSRegularExpression(pattern: "[^0-9]", options: .caseInsensitive)
        amountWithPrefix = regex.stringByReplacingMatches(in: amountWithPrefix, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSMakeRange(0, self.count), withTemplate: "")
        
        let double = (amountWithPrefix as NSString).doubleValue
        number = NSNumber(value: (double / 100))
        
        // if first number is 0 or all numbers were deleted
        guard number != 0 as NSNumber else {
            return ""
        }
        
        return formatter.string(from: number)!
    }
}
