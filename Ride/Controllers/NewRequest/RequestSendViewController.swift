//
//  RequestSendViewController.swift
//  Ride
//
//  Created by Ben Mechen on 01/01/2019.
//  Copyright © 2019 Fuse Apps. All rights reserved.
//

import UIKit
import Crashlytics
import Firebase
import MapKit

class RequestSendViewController: UIViewController {
    @IBOutlet weak var fromTextField: UITextField!
    @IBOutlet weak var toTextField: UITextField!
    @IBOutlet weak var timeTextField: UITextField!
    @IBOutlet weak var peopleTextField: UITextField!
    @IBOutlet weak var seatsWarning: UILabel!
    @IBOutlet weak var sendRequestButton: UIButton!
    
    var userManager: UserManagerProtocol!
    var users: [User] = []
    var groupID: String!
    var from: MKPlacemark? = nil
    var to: MKPlacemark? = nil
    let datePickerView = UIDatePicker()
    var dateStamp: TimeInterval? = nil
    var timeZone: TimeZone?
    var eta: Date? = nil
    var vSpinner: UIView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard users.count > 0 else {
            self.dismiss(animated: true, completion: nil)
            return
        }
        
        if users.count == 1, (users[0].available[groupID] ?? false) == true, let latitude = users[0].location["latitude"], let longitude = users[0].location["longitude"]  {
            let directionsRequest = MKDirections.Request()
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            let sourcePlacemark = MKPlacemark(coordinate: coordinate)
            let destination = MKMapItem(placemark: from!)
            let source = MKMapItem(placemark: sourcePlacemark)
            directionsRequest.destination = destination
            directionsRequest.source = source
            directionsRequest.transportType = .automobile
            
            let directions = MKDirections(request: directionsRequest)
            directions.calculateETA { (etaResponse, error) in
                if let error = error {
                    let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: UIAlertController.Style.alert)
                    alert.addAction(UIAlertAction(title: "Ok", style: UIAlertAction.Style.cancel, handler: { action in
                        self.dismiss(animated: true, completion: nil)
                    }))
                    self.present(alert, animated: true, completion: nil)
                    return
                } else {
                    self.eta = etaResponse?.expectedArrivalDate
                }
            }
        } else {
            self.eta = Date()
        }
        

        // Do any additional setup after loading the view.
        fromTextField.text = from?.title
        toTextField.text = to?.title
        
        var spacerView = UIView(frame:CGRect(x:0, y:0, width:10, height:10))
        fromTextField.leftViewMode = UITextField.ViewMode.always
        fromTextField.leftView = spacerView
        fromTextField.layer.shadowColor = UIColor.black.cgColor
        fromTextField.layer.shadowRadius = 2
        fromTextField.layer.shadowOpacity = 0.2
        fromTextField.layer.shadowOffset = CGSize(width: 0.0, height: 0.0)
        
        spacerView = UIView(frame:CGRect(x:0, y:0, width:10, height:10))
        toTextField.leftViewMode = UITextField.ViewMode.always
        toTextField.leftView = spacerView
        toTextField.layer.shadowColor = UIColor.black.cgColor
        toTextField.layer.shadowRadius = 2
        toTextField.layer.shadowOpacity = 0.2
        toTextField.layer.shadowOffset = CGSize(width: 0.0, height: 0.0)
        
        spacerView = UIView(frame:CGRect(x:0, y:0, width:10, height:10))
        timeTextField.leftViewMode = UITextField.ViewMode.always
        timeTextField.leftView = spacerView
        timeTextField.layer.shadowColor = UIColor.black.cgColor
        timeTextField.layer.shadowRadius = 2
        timeTextField.layer.shadowOpacity = 0.2
        timeTextField.layer.shadowOffset = CGSize(width: 0.0, height: 0.0)
        
        spacerView = UIView(frame:CGRect(x:0, y:0, width:10, height:10))
        peopleTextField.leftViewMode = UITextField.ViewMode.always
        peopleTextField.leftView = spacerView
        peopleTextField.layer.shadowColor = UIColor.black.cgColor
        peopleTextField.layer.shadowRadius = 2
        peopleTextField.layer.shadowOpacity = 0.2
        peopleTextField.layer.shadowOffset = CGSize(width: 0.0, height: 0.0)
        
        self.hideKeyboardWhenTappedAround() 
    }
    

    // MARK: - Actions
    
    @IBAction func selectNoOfPeople(_ sender: Any) {
        let toolBar = UIToolbar()
        toolBar.sizeToFit()
        
        let flexibleButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(RequestSendViewController.dismissKeyboard))
        toolBar.setItems([flexibleButton, doneButton], animated: false)
        toolBar.isUserInteractionEnabled = true
        
        peopleTextField.inputAccessoryView = toolBar
    }
    
    @IBAction func noOfPeopleDidEndEditing(_ sender: Any) {
        if let numberOfPeople = Int(peopleTextField.text!) {
            if users.count == 1 {
                if let numberOfSeats = Int(users[0].car._carSeats) {
                    if numberOfPeople >= numberOfSeats {
                        seatsWarning.text = (users[0].name) + "'s car can only take " + String(numberOfSeats - 1) + " passengers. This Ride will require multiple trips."
                        return
                    }
                }
            }
        }
        seatsWarning.text = ""
        
        checkIfDone()
    }
    
    @IBAction func sendRequest(_ sender: Any) {
        self.vSpinner = self.showSpinner(onView: self.view)
        let timestampInt = Int(dateStamp!)
        if let noOfPeople = Int(peopleTextField.text!) {
            for user in users {
                let request = Request(driver: user.id, sender: Auth.auth().currentUser!.uid, from: (from?.coordinate)!, fromName: (from?.title)!, to: (to?.coordinate)!, toName: (to?.title)! , time: timestampInt, timeZone: timeZone ?? TimeZone.current, passengers: noOfPeople, status: 0)
                
                request.send(userManager: userManager) { (success, key) in
                    if success {
                        let alert = UIAlertController(title: "Request sent", message: "Once the other user has accepted the request and sent a price back, you will be notified", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: { _ in
                            self.dismiss(animated: true, completion: nil)
                        }))
                        self.present(alert, animated: true, completion: nil)
                    } else {
                        let alert = UIAlertController(title: "Error", message: "Something went wrong, please try again", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: { _ in
                            self.dismiss(animated: true, completion: nil)
                        }))
                        self.present(alert, animated: true, completion: nil)
                    }
                    self.removeSpinner(spinner: self.vSpinner!)
                }
            }
        }
    }
    
    // MARK: - Time Picker
    @IBAction func pickTime(_ sender: UITextField) {
        createToolbar()
        datePickerView.datePickerMode = UIDatePicker.Mode.dateAndTime
        datePickerView.minuteInterval = 5
        
        let calendar = Calendar(identifier: .gregorian)
        var comps = DateComponents()
        comps.minute = 5
        if eta != nil {
            let minDate = calendar.date(byAdding: comps, to: (eta)!)
            datePickerView.minimumDate = minDate
        }
        sender.inputView = datePickerView
        datePickerView.addTarget(self, action: #selector(datePickerValueChanged), for: UIControl.Event.valueChanged)
    }
    
    @objc func datePickerValueChanged(sender: UIDatePicker) {
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = DateFormatter.Style.medium
        timeFormatter.timeStyle = DateFormatter.Style.short
        
        let date = timeFormatter.date(from: timeFormatter.string(from: sender.date))
//        let offset = timeFormatter.timeZone.daylightSavingTimeOffset(for: date!)
//        date! += offset
        dateStamp = date?.timeIntervalSince1970
        timeZone = sender.timeZone
        
        timeTextField.text = timeFormatter.string(from: sender.date)
    }
    
    func createToolbar() {
        let toolBar = UIToolbar()
        toolBar.sizeToFit()
        
        let flexibleButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(RequestSendViewController.dismissKeyboard))
        toolBar.setItems([flexibleButton, doneButton], animated: false)
        toolBar.isUserInteractionEnabled = true
        
        timeTextField.inputAccessoryView = toolBar
    }
    
    private func checkIfDone() {
        if !(timeTextField.text?.isEmpty)! && !(peopleTextField.text?.isEmpty)! {
            sendRequestButton.isHidden = false
        } else {
            sendRequestButton.isHidden = true
        }
    }
}
