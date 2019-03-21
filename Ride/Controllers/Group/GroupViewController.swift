//
//  GroupViewController.swift
//  Ride
//
//  Created by Ben Mechen on 04/10/2018.
//  Copyright © 2018 Fuse Apps. All rights reserved.
//

import UIKit
import Crashlytics
import ObjectiveC
import MapKit
import Firebase
import Kingfisher
import os.log

protocol GroupTableViewCellDelegate {
    func callSegueFromCell(data dataobject: AnyObject)
}

class GroupViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, MKMapViewDelegate, CLLocationManagerDelegate, GroupViewControllerDelegate, UserMapCalloutViewDelegate, GroupTableViewCellDelegate {
    func detailsRequestedForPerson(user: User) {
        
    }
    
    @IBOutlet weak var groupMapView: MKMapView!
    @IBOutlet weak var groupMembersTable: UITableView!
    let locationManager = CLLocationManager()
    var centered = false
    var group: Group = Group()!
    var availableMembers: Array<User> = []
    var unavailableMembers: Array<User> = []
    var memberAnnotations: Array<MKAnnotation> = []
    weak var welcomeViewControllerDelegate: WelcomeViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        
        groupMapView.delegate = self
        
        let button =  UIButton(type: .custom)
        button.frame = CGRect(x: 0, y: 0, width: 100, height: 40)
        button.backgroundColor = UIColor.clear
        button.titleLabel?.textColor = UIColor.white
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 20)
        button.setTitle(group._groupName, for: .normal)
        button.addTarget(self, action: #selector(self.clickOnButton), for: .touchUpInside)
        self.navigationItem.titleView = button
        
        checkLocationAuthorizationStatus()

        sortMembers()
        groupMapView.showAnnotations(memberAnnotations, animated: true)
        
        groupMapView.showsUserLocation = true
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        
        RideDB?.child("Groups").child("UserGroups").child(mainUser!._userID).child("groupIDs").observeSingleEvent(of: .value, with: { snapshot in
            var count = 0
            if let value = snapshot.value as? [String: Bool] {
                for key in value.keys {
                    if value[key]!{
                        count += 1
                    }
                }
            }
            
            if count == 0 {
                self.locationManager.stopUpdatingLocation()
            }
        })
    }
    
    // MARK: - Map view
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation { return nil }
        
        let identifier = "Annotation"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        
        if annotationView == nil {
            annotationView = MapAnnotationView(annotation: annotation, reuseIdentifier: identifier, delegate: self)
            annotationView!.canShowCallout = false
        } else {
            annotationView!.annotation = annotation
        }
        
//        if annotation.propertiesToSend["type"] == "" || annotation.propertiesToSend["type"] == nil || annotation.propertiesToSend["type"] == "Other" {
//            annotation.propertiesToSend["type"] = "hatchback"
//        }
        
        annotation.propertiesToSend["type"] = annotation.propertiesToSend["type"]?.lowercased()
        
        if !["hatchback", "convertible", "estate", "suv", "coupe", "mpv", "pick up", "saloon"].contains(annotation.propertiesToSend["type"]) {
            annotation.propertiesToSend["type"] = "hatchback"
        }
        
        let type = String((annotation.propertiesToSend["type"]!.lowercased()).filter { !" \n\t\r".contains($0) })
        let pinImage = UIImage(named: type)
        let size = CGSize(width: 50, height: 50)
        UIGraphicsBeginImageContext(size)
        pinImage!.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()

        annotationView!.image = resizedImage
        
        return annotationView
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations[0]
        
        if !centered {
            let span: MKCoordinateSpan = MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
            let userLocation = CLLocationCoordinate2DMake(location.coordinate.latitude, location.coordinate.longitude)
            let region: MKCoordinateRegion = MKCoordinateRegion(center: userLocation, span: span)
            
            groupMapView.setRegion(region, animated: true)
            
            centered = true
        }
        
        self.groupMapView.showsUserLocation = true
    }
    
    
    // MARK: - Table view data source
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let view = view as? UITableViewHeaderFooterView {
//            view.backgroundView?.backgroundColor = UIColor.init(red: 0.82, green: 0.33, blue: 0.33, alpha: 1.00)
            view.backgroundView?.backgroundColor = UIColor.white
            view.textLabel!.backgroundColor = UIColor.clear
            view.textLabel!.textColor = rideRed
        }
        
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "Available"
        } else {
            return "Unavailable"
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
//            if availableMembers.count > 0 {
            return availableMembers.count
//            }
//            return 1
        } else {
            return unavailableMembers.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = "GroupTableViewCell"
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? GroupTableViewCell else {
            fatalError("The dequeued cell is not an instance of GroupTableViewCell")
        }
        
        cell.selectionStyle = .none
        
        if indexPath.section == 0 {
            if availableMembers.count > 0 {
                guard indexPath.row < availableMembers.count else {
                    return cell
                }
                
                let user = availableMembers[indexPath.row]
                
                if cell.requestButton != nil {
                    cell.requestButton.isHidden = false
                    cell.delegate = self
                }
                
                cell.user = user
                
                cell.userName.text = user._userName
                
                if user._userLocation["latitude"] != nil && user._userLocation["longitude"] != nil && locationManager.location != nil {
                    cell.userCar.text = user._userCar._carType + " - " + String(format: "%.1f miles away", (locationManager.location?.distance(from: CLLocation(latitude: user._userLocation["latitude"]!, longitude: user._userLocation["longitude"]!)))! / 1609.344)
                } else {
                    cell.userCar.text = user._userCar._carType
                }
                
                
                cell.userImage.kf.setImage(
                    with: user._userPhotoURL,
                    placeholder: UIImage(named: "groupPlaceholder"),
                    options: ([
                        .transition(.fade(1)),
                        .cacheOriginalImage
                    ] as KingfisherOptionsInfo)) { result in
                    switch result {
                    case .success(let value):
                        print("Task done for: \(value.source.url?.absoluteString ?? "")")
                    case .failure(let error):
                        os_log("Error: %@", log: OSLog.default, type: .error, error.localizedDescription)
                    }
                }
                
                cell.userImage.layer.borderWidth = 1
                cell.userImage.layer.borderColor = UIColor.red.cgColor
            }
        } else if indexPath.section == 1 {
            if unavailableMembers.count > 0 {
                guard indexPath.row < unavailableMembers.count else {
                    return cell
                }
                
                let user = unavailableMembers[indexPath.row]
                
                if cell.requestButton != nil {
                    cell.requestButton.isHidden = true
                }
                
                cell.userName.frame.size.width = 311
                
                cell.userName.text = user._userName
                
                if user._userCar._carType != "undefined" && user._userCar._carType != "" {
                    cell.userCar.text = user._userCar._carType
                }
                
                cell.userImage.kf.setImage(
                    with: user._userPhotoURL,
                    placeholder: UIImage(named: "groupPlaceholder"),
                    options: ([
                        .transition(.fade(1)),
                        .cacheOriginalImage
                        ] as KingfisherOptionsInfo)) { result in
                            switch result {
                            case .success(let value):
                                print("Task done for: \(value.source.url?.absoluteString ?? "")")
                            case .failure(let error):
                                os_log("Error: %@", log: OSLog.default, type: .error, error.localizedDescription)
                            }
                }
            }
        }
        
        return cell
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        print("Preparing to segue: \(String(describing: segue.identifier))")
        
        switch(segue.identifier ?? "") {
        case "showGroupSettings":
            os_log("Showing group settings", log: OSLog.default, type: .debug)
            
            let navVC = segue.destination as? UINavigationController
            let groupSettingsViewController = navVC?.viewControllers.first as! GroupSettingsTableViewController

            groupSettingsViewController.group = group
            groupSettingsViewController.groupViewControllerDelegate = self
        case "requestRide":
            os_log("Showing request ride", log: OSLog.default, type: .debug)
            let navVC = segue.destination as? UINavigationController
            let requestViewController = navVC?.viewControllers.first as! RequestViewController
            requestViewController.region = self.groupMapView.region
            let user = sender as! User
            requestViewController.user = user
        default:
            fatalError("Unexpected Segue Identifier: \(String(describing: segue.identifier))")
        }
    }
    
    func callSegueFromCell(data dataobject: AnyObject) {
        self.performSegue(withIdentifier: "requestRide", sender: dataobject)
    }
    
    func updateGroupName(group: Group) {
        self.group = group

        let button = UIButton(type: .custom)
        button.frame = CGRect(x: 0, y: 0, width: 100, height: 40)
        button.backgroundColor = UIColor.clear
        button.titleLabel?.textColor = UIColor.white
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 20)
        button.setTitle(group._groupName, for: .normal)
        button.addTarget(self, action: #selector(self.clickOnButton), for: .touchUpInside)

        self.navigationItem.titleView = button
    }
    
    func updateGroupMembers(group: Group) {
        self.group = group
        
        sortMembers()
    }
    
    @objc func clickOnButton(button: UIButton) {
        performSegue(withIdentifier: "showGroupSettings", sender: self)
    }
    
    func checkLocationAuthorizationStatus() {
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            groupMapView.showsUserLocation = true
        } else {
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    private func sortMembers() {
        self.availableMembers = []
        self.unavailableMembers = []
        self.memberAnnotations = []
        
        for user in group._groupUsers {
            if user._userID != currentUser?.uid {
                if user._userAvailable[self.group._groupID] != nil {
                    if user._userAvailable[self.group._groupID]! as Bool {
                        self.availableMembers.append(user)
                        guard let userAnnotation = MapAnnotation(user: user) else {
                            continue
                        }
                        
                        userAnnotation.propertiesToSend["type"] = user._userCar._carType
                        self.memberAnnotations.append(userAnnotation)
                    } else {
                        self.unavailableMembers.append(user)
                    }
                } else {
                    self.unavailableMembers.append(user)
                }
            }
        }
        
        self.groupMapView.addAnnotations(memberAnnotations)
    }
    
    private func dateFormat(date: Double) -> String {
        
        let date1:Date = Date() // Same you did before with timeNow variable
        let date2: Date = Date(timeIntervalSince1970: date)
        
        let calender:Calendar = Calendar.current
        let components: DateComponents = calender.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date1, to: date2)

        var returnString:String = ""

        if components.second! < 60 {
            returnString = "Just Now"
        }else if components.minute! >= 1{
            returnString = String(describing: components.minute) + " min ago"
        }else if components.hour! >= 1{
            returnString = String(describing: components.hour) + " hour ago"
        }else if components.day! >= 1{
            returnString = String(describing: components.day) + " days ago"
        }else if components.month! >= 1{
            returnString = String(describing: components.month)+" month ago"
        }else if components.year! >= 1 {
            returnString = String(describing: components.year)+" year ago"
        }
        return returnString
    }
}

private var key: Void? = nil // the address of key is a unique id.

extension MKAnnotation {
    var propertiesToSend: [String: String] {
        get { return objc_getAssociatedObject(self, &key) as? [String: String] ?? [:] }
        set { objc_setAssociatedObject(self, &key, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }
}
