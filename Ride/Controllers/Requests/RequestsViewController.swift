//
//  RequestsViewController.swift
//  Ride
//
//  Created by Ben Mechen on 04/01/2019.
//  Copyright © 2019 Fuse Apps. All rights reserved.
//

import UIKit
import Firebase
import Crashlytics
import MapKit
import os.log

class RequestsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, RequestsViewControllerDelegate {

    @IBOutlet weak var sentRequestsTable: UITableView!
    @IBOutlet weak var receivedRequestsTable: UITableView!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var segmentedView: UIView!

    var userManager: UserManagerProtocol!
    lazy var RideDB = Database.database().reference()
    var sentRequestIDs: [String: Array<String>] = ["upcoming": [], "previous": []]
    var sentRequests: [String: [String: Request]] = ["upcoming":[:], "previous":[:]]
    var receivedRequestIDs: [String: Array<String>] = ["upcoming": [], "previous": []]
    var receivedRequests: [String: [String: Request]] = ["upcoming":[:], "previous":[:]]
    var index: IndexPath = IndexPath(row: -1, section: -1)
    var userName = ""
    var sectionChanged: Bool = false
    var refreshControl = UIRefreshControl()
    var changeSection: Bool = false
    override var canResignFirstResponder: Bool {return false}
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        changeSection = true
        
        //Hide NavBar bottom line
        self.navigationController?.navigationBar.setValue(true, forKey: "hidesShadow")
        
        //Set titles
        segmentedControl.setTitle("Sent Requests", forSegmentAt: 0)
        segmentedControl.setTitle("Received Requests", forSegmentAt: 1)
        
        //Get NavBar width
        let navigationBarWidth = Int(self.navigationController!.navigationBar.frame.width)
        //Create variable with width for Segmented Controller
        var segmentedControllerWidth = 0
        let segmentedControllerY = 0
        var xSC = 0
        
        if UIDevice().userInterfaceIdiom == .phone {
            switch UIScreen.main.nativeBounds.height {
            case 1136:
                //iPhone 5S or SE
                xSC = 16
                segmentedControllerWidth = navigationBarWidth-32
            case 1334:
                //iPhone 6/6S/7/8
                xSC = 16
                segmentedControllerWidth = navigationBarWidth-32
            case 2208:
                //iPhone 6+/6S+/7+/8+
                xSC = 22
                segmentedControllerWidth = navigationBarWidth-44
            case 2436:
                //iPhone X
                xSC = 16
                segmentedControllerWidth = navigationBarWidth-32
            default:
                //Unknown
                xSC = 16
                segmentedControllerWidth = navigationBarWidth-32
            }
        }
        
        let y = segmentedControl.frame.origin.y + CGFloat(segmentedControllerY)
        
        //Set width & opacity
        segmentedControl.frame = CGRect(x: CGFloat(xSC), y: y, width: CGFloat(segmentedControllerWidth), height: segmentedControl.frame.size.height + 5)
        
        sentRequestsTable.delegate = self
        sentRequestsTable.dataSource = self
        sentRequestsTable.separatorStyle = .none
        receivedRequestsTable.separatorStyle = .none
        receivedRequestsTable.delegate = self
        receivedRequestsTable.dataSource = self
        
        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl.addTarget(self, action: "refresh:", for: .valueChanged)
        sentRequestsTable.addSubview(refreshControl)
        receivedRequestsTable.addSubview(refreshControl)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        sentRequestIDs["upcoming"]?.removeAll()
        sentRequestIDs["previous"]?.removeAll()
        sentRequests["upcoming"]?.removeAll()
        sentRequests["previous"]?.removeAll()
        receivedRequests["upcoming"]?.removeAll()
        receivedRequests["previous"]?.removeAll()
        receivedRequestIDs["upcoming"]?.removeAll()
        receivedRequestIDs["previous"]?.removeAll()
        
        getUserRequests()
        
        //Set navigation bar title to custom text for logo
        let rideLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 21))
        rideLabel.text = "Lifts"
        rideLabel.textColor = UIColor.white
        rideLabel.textAlignment = .center
        rideLabel.font = UIFont(name: "HelveticaNeue-Light", size: 30.0)
        if let tabViewController = self.parent as? TabViewController {
            tabViewController.navigationBar.titleView = rideLabel
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        //Set navigation bar title to custom text for logo
        let rideLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 21))
        rideLabel.text = "Ride"
        rideLabel.textColor = UIColor.white
        rideLabel.textAlignment = .center
        rideLabel.font = UIFont(name: "HelveticaNeue-Light", size: 30.0)
        if let tabViewController = self.parent as? TabViewController {
            tabViewController.navigationBar.titleView = rideLabel
        }
    }
    
    
    // MARK: - Table stuff
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if tableView == self.sentRequestsTable {
            if (self.sentRequests["previous"]?.count ?? 0) > 0 {
                return 2
            }
            return 1
        }
        
        if (self.receivedRequests["previous"]?.count ?? 0) > 0 {
            return 2
        }
        return 1
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "Upcoming Requests"
        }
        
        return "Previous Requests"
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == self.sentRequestsTable {
            if section == 0 {
                return self.sentRequests["upcoming"]?.count ?? 0
            } else {
                return self.sentRequests["previous"]?.count ?? 0
            }
        }
        
        if section == 0 {
            return self.receivedRequests["upcoming"]?.count ?? 0
        } else {
            return self.receivedRequests["previous"]?.count ?? 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = "RequestsTableCell"
        
        if tableView == self.sentRequestsTable {
            if indexPath.section == 0 {
                guard self.sentRequestIDs["upcoming"]!.count > indexPath.row else {
                    self.sentRequestsTable.reloadData()
                    let cell = sentRequestsTable.dequeueReusableCell(withIdentifier: "BlankRequestTableCell", for: indexPath) as! BlankRequestTableViewCell
                    
                    return cell
                }
                
                if self.sentRequestIDs["upcoming"]?[indexPath.row] == "nil" {
                    let cell = sentRequestsTable.dequeueReusableCell(withIdentifier: "BlankRequestTableCell", for: indexPath) as! BlankRequestTableViewCell
                    
                    return cell
                }
            }
            
            guard let cell = sentRequestsTable.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? RequestsTableViewCell else {
                fatalError("The dequeued cell is not an instance of RequestsTableViewCell")
            }
            
            sentRequestsTable.deselectRow(at: indexPath, animated: true)
            
            if indexPath.section == 0 {
                if indexPath.row >= sentRequestIDs["upcoming"]!.count {
                    self.sentRequestsTable.reloadData()
                    return cell
                }
            } else {
                if indexPath.row >= sentRequestIDs["previous"]!.count {
                    self.sentRequestsTable.reloadData()
                    return cell
                }
            }
            
            var request: Request
            if indexPath.section == 0 {
                request = (sentRequests["upcoming"]?[sentRequestIDs["upcoming"]![indexPath.row]])!
            } else {
                request = (sentRequests["previous"]?[sentRequestIDs["previous"]![indexPath.row]])!
            }
            
            // Name & profile image
            RideDB.child("Users").child((request._driver)!).observeSingleEvent(of: .value) { (snapshot) in
                if let value = snapshot.value as? [String : Any] {
                    cell.name.text = (value["name"] as! String)
                    cell.profileImage.image(fromUrl: value["photo"] as! String)
                    cell.profileImage.isHidden = false
                    cell.isUserInteractionEnabled = true
                } else {
                    cell.name.text = "User deleted"
                    cell.profileImage.isHidden = true
                    cell.isUserInteractionEnabled = false
                }
            }
            
            // To
            let date = Date(timeIntervalSince1970: Double((request._time)!))
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale.current
            dateFormatter.timeStyle = .short
            dateFormatter.dateStyle = .none
//            let offset = dateFormatter.timeZone.daylightSavingTimeOffset(for: date)
//            date += offset
            cell.start.text = dateFormatter.string(from: date)
            
            // People
            cell.people.text = String(request._passengers ?? 0)
            if request._passengers == 1 {
                cell.people.text = cell.people.text! + " person"
            } else {
                cell.people.text = cell.people.text! + " people"
            }
            
            dateFormatter.timeStyle = .none
            dateFormatter.dateStyle = .short
            dateFormatter.doesRelativeDateFormatting = true
            dateFormatter.locale = Locale(identifier: "en_UK")
            
            cell.people.text = cell.people.text! + " | " + dateFormatter.string(from: date)
            
            
            // Location calculation
            let directionsRequest = MKDirections.Request()
            let sourcePlacemark = MKPlacemark(coordinate: (request._from)!)
            let destinationPlacemark = MKPlacemark(coordinate: (request._to)!)
            let source = MKMapItem(placemark: sourcePlacemark)
            let destination = MKMapItem(placemark: destinationPlacemark)
            directionsRequest.destination = destination
            directionsRequest.source = source
            directionsRequest.transportType = .automobile
            directionsRequest.departureDate = date
            
            let directions = MKDirections(request: directionsRequest)
            directions.calculateETA { (etaResponse, error) in
                if let error = error {
                    os_log("Error calculating route: @%", log: OSLog.default, type: .error, error.localizedDescription)
                    self.dismiss(animated: true, completion: nil)
                    return
                } else {
                    dateFormatter.timeStyle = .short
                    dateFormatter.dateStyle = .none
                    cell.end.text = dateFormatter.string(from: (etaResponse?.expectedArrivalDate)!)
                }
            }
            
            cell.from.text = request._fromName
            cell.to.text = request._toName
            
            if request.new {
                cell.name.font = UIFont.systemFont(ofSize: 19.0, weight: .bold)
                cell.profileImage.borderWidth = 2
                cell.profileImage.borderColor = UIColor.red
            } else {
                cell.name.font = UIFont.systemFont(ofSize: 18.0, weight: .regular)
                cell.profileImage.borderWidth = 0
            }
            
            return cell
        } else {
            guard let cell = receivedRequestsTable.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? RequestsTableViewCell else {
                fatalError("The dequeued cell is not an instance of RequestsTableViewCell")
            }
            
            receivedRequestsTable.deselectRow(at: indexPath, animated: true)
            
            if indexPath.section == 0 {
                if indexPath.row >= receivedRequestIDs["upcoming"]!.count {
                    self.receivedRequestsTable.reloadData()
                    return cell
                }
            } else {
                if indexPath.row >= receivedRequestIDs["previous"]!.count {
                    self.receivedRequestsTable.reloadData()
                    return cell
                }
            }
            
            var request: Request
            if indexPath.section == 0 {
                request = (receivedRequests["upcoming"]?[receivedRequestIDs["upcoming"]![indexPath.row]])!
            } else {
                request = (receivedRequests["previous"]?[receivedRequestIDs["previous"]![indexPath.row]])!
            }
            
            // Name & profile image
            RideDB.child("Users").child((request._sender)!).observeSingleEvent(of: .value) { (snapshot) in
                if let value = snapshot.value as? [String : Any] {
                    cell.name.text = (value["name"] as! String)
                    cell.profileImage.image(fromUrl: value["photo"] as! String)
                    cell.profileImage.isHidden = false
                    cell.isUserInteractionEnabled = true
                } else {
                    cell.name.text = "User deleted"
                    cell.profileImage.isHidden = true
                    cell.isUserInteractionEnabled = false
                }
            }
            
            // To
            let date = Date(timeIntervalSince1970: Double((request._time)!))
            let dateFormatter = DateFormatter()
            dateFormatter.timeStyle = .short
            dateFormatter.dateStyle = .none
            dateFormatter.timeZone = TimeZone.current
//            let offset = dateFormatter.timeZone.daylightSavingTimeOffset(for: date)
//            date += offset
            cell.start.text = dateFormatter.string(from: date)
            
            // People
            cell.people.text = String(request._passengers ?? 0)
            if request._passengers == 1 {
                cell.people.text = cell.people.text! + " person"
            } else {
                cell.people.text = cell.people.text! + " people"
            }
            
            dateFormatter.timeStyle = .none
            dateFormatter.dateStyle = .short
            
            cell.people.text = cell.people.text! + " | " + dateFormatter.string(from: date)
            
            
            // Location calculation
            let directionsRequest = MKDirections.Request()
            let sourcePlacemark = MKPlacemark(coordinate: (request._from)!)
            let destinationPlacemark = MKPlacemark(coordinate: (request._to)!)
            let source = MKMapItem(placemark: sourcePlacemark)
            let destination = MKMapItem(placemark: destinationPlacemark)
            directionsRequest.destination = destination
            directionsRequest.source = source
            directionsRequest.transportType = .automobile
            directionsRequest.departureDate = date
            
            let directions = MKDirections(request: directionsRequest)
            directions.calculateETA { (etaResponse, error) in
                if let error = error {
                    os_log("Error calculating route: @%", log: OSLog.default, type: .error, error.localizedDescription)
                    self.dismiss(animated: true, completion: nil)
                    return
                } else {
                    dateFormatter.timeStyle = .short
                    dateFormatter.dateStyle = .none
                    cell.end.text = dateFormatter.string(from: (etaResponse?.expectedArrivalDate)!)
                }
            }
            
            cell.from.text = request._fromName
            cell.to.text = request._toName
            
            if request.new {
                cell.name.font = UIFont.systemFont(ofSize: 19.0, weight: .bold)
                cell.profileImage.borderWidth = 2
                cell.profileImage.borderColor = UIColor.red
            } else {
                cell.name.font = UIFont.systemFont(ofSize: 18.0, weight: .regular)
                cell.profileImage.borderWidth = 0
            }
            
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView == self.sentRequestsTable {
            if indexPath.section == 0 {
                guard self.sentRequestIDs["upcoming"]?[indexPath.row] != "nil" else {
                    return
                }
            }
        }
        
        self.index = indexPath
        let cell = tableView.cellForRow(at: indexPath) as! RequestsTableViewCell
        
        self.userName = cell.name.text ?? ""
        
        var section = ""
        if index.section == 0 {
            section = "upcoming"
        } else {
            section = "previous"
        }
        
        if tableView == self.sentRequestsTable {
            if indexPath.row < sentRequestIDs[section]?.count ?? 0, let id = sentRequestIDs[section]?[indexPath.row] {
                print(id)
                if let request = sentRequests[section]?[id] {
                    switch request.status {
                    case 0:
                        self.performSegue(withIdentifier: "moveToSentRequest_page1", sender: self)
                    case 1:
                        self.performSegue(withIdentifier: "moveToSentRequest_page3", sender: self)
                    case 2, 3, 4:
                        self.performSegue(withIdentifier: "moveToSentRequest_page4", sender: self)
                    default:
                        if request.deleted {
                            self.performSegue(withIdentifier: "moveToSentRequest_page2", sender: self)
                        }
                    }
                }
            }
        } else {
            if indexPath.row < receivedRequestIDs[section]?.count ?? 0, let id = receivedRequestIDs[section]?[indexPath.row] {
                print(id)
                if let request = receivedRequests[section]?[id] {
                    switch request.status {
                    case 0:
                        self.performSegue(withIdentifier: "moveToReceivedRequest_page1", sender: self)
                    case 1:
                        self.performSegue(withIdentifier: "moveToReceivedRequest_page3", sender: self)
                    case 2, 3, 4:
                        self.performSegue(withIdentifier: "moveToReceivedRequest_page4", sender: self)
                    default:
                        if request.deleted {
                            self.performSegue(withIdentifier: "moveToReceivedRequest_page2", sender: self)
                        }
                    }
                }
            }
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt: IndexPath) -> [UITableViewRowAction]? {
        let delete = UITableViewRowAction(style: .destructive, title: "Delete") { action, index in
            var section = ""
            if editActionsForRowAt.section == 0 {
                section = "upcoming"
            } else {
                section = "previous"
            }
            if self.segmentedControl.selectedSegmentIndex == 0 {
                self.RideDB.child("Requests").child((self.sentRequestIDs[section]?[editActionsForRowAt.row])!).child("deleted").setValue(true)
                self.RideDB.child("Users").child((self.sentRequests[section]?[self.sentRequestIDs[section]![editActionsForRowAt.row]]?._sender)!).child("requests").child("sent").child(self.sentRequestIDs[section]![editActionsForRowAt.row]).removeValue()
                self.sentRequests[section]?.removeValue(forKey: (self.sentRequestIDs[section]?[editActionsForRowAt.row])!)
//                self.sentRequests[section].removeValue(forKey: )
                self.sentRequestIDs[section]?.remove(at: editActionsForRowAt.row)
                self.sentRequestsTable.reloadData()
            } else if self.segmentedControl.selectedSegmentIndex == 1 {
                self.RideDB.child("Requests").child(self.receivedRequestIDs[section]![editActionsForRowAt.row]).child("deleted").setValue(true)
                self.RideDB.child("Users").child((self.receivedRequests[section]?[self.receivedRequestIDs[section]![editActionsForRowAt.row]]?._driver)!).child("requests").child("received").child(self.receivedRequestIDs[section]![editActionsForRowAt.row]).removeValue()
                self.receivedRequests[section]?.removeValue(forKey: self.receivedRequestIDs[section]![editActionsForRowAt.row])
                self.receivedRequestIDs[section]?.remove(at: editActionsForRowAt.row)
                self.receivedRequestsTable.reloadData()
            }
        }
        
        return [delete]
    }
    
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        print("Preparing to segue: \(String(describing: segue.identifier))")
        
        if let sentRequestViewControllerParent = sender as? SentRequestViewController {
            if let sentRequestViewController = segue.destination as? SentRequestViewController {
                sentRequestViewController.userManager = sentRequestViewControllerParent.userManager
                sentRequestViewController.request = sentRequestViewControllerParent.request
                sentRequestViewController.userName = sentRequestViewControllerParent.userName
                sentRequestViewController.navigationItem.title = sentRequestViewControllerParent.userName
            }
        } else {
            var section = ""
            if index.section == 0 {
                section = "upcoming"
            } else {
                section = "previous"
            }
            
            switch(segue.identifier ?? "") {
            case "moveToSentRequest_page1", "moveToSentRequest_page2", "moveToSentRequest_page3", "moveToSentRequest_page4":
                guard let request = sentRequests[section]?[sentRequestIDs[section]![index.row]] else {
                    return
                }
                
                if let sentRequestViewController = segue.destination as? SentRequestViewController {
                    sentRequestViewController.userManager = userManager
                    sentRequestViewController.request = request
                    sentRequestViewController.userName = userName
                    sentRequestViewController.navigationItem.title = userName
                    sentRequestViewController.requestsViewControllerDelegate = self
                }
                
                if sentRequests[section]?[sentRequestIDs[section]![index.row]]?.new ?? false {
                    if let value = Int(self.tabBarController?.tabBar.items?[1].badgeValue ?? "0") {
                        if value > 1 {
                            self.tabBarController?.tabBar.items?[1].badgeValue = String(value - 1)
                        } else {
                            self.tabBarController?.tabBar.items?[1].badgeValue = nil
                        }
                    }
                }
            case "moveToReceivedRequest_page1", "moveToReceivedRequest_page2", "moveToReceivedRequest_page3", "moveToReceivedRequest_page4":
                guard let request = receivedRequests[section]?[receivedRequestIDs[section]![index.row]] else {
                    return
                }
                
                if let receivedRequestViewController = segue.destination as? ReceivedRequestViewController {
                    receivedRequestViewController.userManager = userManager
                    receivedRequestViewController.request = request
                    receivedRequestViewController.userName = userName
                    receivedRequestViewController.navigationItem.title = userName
                }
                
                if receivedRequests[section]?[receivedRequestIDs[section]![index.row]]?.new ?? false {
                    if let value = Int(self.tabBarController?.tabBar.items?[1].badgeValue ?? "0") {
                        if value > 1 {
                            self.tabBarController?.tabBar.items?[1].badgeValue = String(value - 1)
                        } else {
                            self.tabBarController?.tabBar.items?[1].badgeValue = nil
                        }
                    }
                }
            default:
                fatalError("Unknown segue identifier - RequestViewController")
            }
        }
    }
    
    // MARK: - Actions
    
    @IBAction func switchSections(_ sender: Any) {
        switch segmentedControl.selectedSegmentIndex {
        case 0:
            sentRequestsTable.isHidden = false
            receivedRequestsTable.isHidden = true
        case 1:
            sentRequestsTable.isHidden = true
            receivedRequestsTable.isHidden = false
        default:
            break
        }    }
    
    
    // MARK: - Private functions
    
    @objc func refresh(sender: AnyObject) {
        getUserRequests()
        refreshControl.endRefreshing()
    }
    
    private func getUserRequests() {
        self.RideDB.child("Users").child(Auth.auth().currentUser!.uid).child("requests").child("sent").queryOrdered(byChild: "timestamp").observe(.value, with: { (snapshot) in
            for child in snapshot.children.reversed() {
                let snap = child as! DataSnapshot
                self.RideDB.child("Requests").child(snap.key).observeSingleEvent(of: .value, with: { (snapshot) in
                    if let sentValue = snapshot.value as? [String: Any] {
                        let from = sentValue["from"] as! [String: Any]
                        let fromLat: Double = from["latitude"] as! Double
                        let fromLong: Double = from["longitude"] as! Double
                        let fromName: String = from["name"] as! String
                        
                        let to = sentValue["to"] as! [String: Any]
                        let toLat: Double = to["latitude"] as! Double
                        let toLong: Double = to["longitude"] as! Double
                        let toName: String = to["name"] as! String
                        let timeZone = sentValue["timeZone"] as? String ?? ""
                        
                        let request = Request(id: snap.key, driver: sentValue["driver"] as! String, sender: sentValue["sender"] as! String, from: CLLocationCoordinate2DMake(fromLat, fromLong), fromName: fromName, to: CLLocationCoordinate2DMake(toLat, toLong), toName: toName, time: sentValue["time"] as! Int, timeZone: TimeZone.init(identifier: timeZone) ?? TimeZone.current, passengers: sentValue["passengers"] as! Int, status: sentValue["status"] as! Int, sent: sentValue["sent"] as? Int)
                        
                        if let value = snap.value as? [String: Any] {
                            request.new = value["new"] as! Bool
                        }
                        request.deleted = sentValue["deleted"] as! Bool
                        
                        let date = Date(timeIntervalSince1970: Double(request._time))
                        if date.timeIntervalSinceNow < 0 {
                            self.sentRequests["previous"]?[snap.key] = request
                            if !(self.sentRequestIDs["previous"]?.contains(snap.key))! {
                                self.sentRequestIDs["previous"]?.append(snap.key)
                            }
                        } else {
                            self.sentRequests["upcoming"]?[snap.key] = request
                            if !(self.sentRequestIDs["upcoming"]?.contains(snap.key))! {
                                self.sentRequestIDs["upcoming"]?.insert(snap.key, at: 0)
//                                self.sentRequestIDs["upcoming"]?.append(snap.key)
                            }
                        }
                        
                        self.sentRequestsTable.reloadData()
                        self.sentRequestsTable.numberOfRows(inSection: 0)
                        
                        let sentCount = self.sentRequestIDs["upcoming"]!.count + self.sentRequestIDs["previous"]!.count
                        let receivedCount = self.receivedRequestIDs["upcoming"]!.count + self.receivedRequestIDs["previous"]!.count
                        
                        if (sentCount > 0 || receivedCount > 0) && !self.sectionChanged && self.changeSection {
                            if sentCount < receivedCount {
                                self.segmentedControl.selectedSegmentIndex = 1
                            } else {
                                self.segmentedControl.selectedSegmentIndex = 0
                            }
                            
                            self.switchSections(self)
                            self.sectionChanged = true
                        }
                    }
                })
            }
            
            if snapshot.childrenCount == 0 {
                self.sentRequestIDs["upcoming"]?.append("nil")
                
                let request = Request(id: "nil", driver: "", sender: "", from: CLLocationCoordinate2D(), fromName: "", to: CLLocationCoordinate2D(), toName: "", time: 0, timeZone: TimeZone.current, passengers: 0, status: 0)
                self.sentRequests["upcoming"]?["nil"] = request
                self.sentRequestsTable.reloadData()
            }
        })
        
        self.RideDB.child("Users").child(Auth.auth().currentUser!.uid).child("requests").child("received").queryOrdered(byChild: "timestamp").observe(.value, with: { (snapshot) in
            for child in snapshot.children.reversed() {
                let snap = child as! DataSnapshot
                self.RideDB.child("Requests").child(snap.key).observeSingleEvent(of: .value, with: { (snapshot) in
                    if let receivedValue = snapshot.value as? [String: Any] {
                        let from = receivedValue["from"] as! [String: Any]
                        let fromLat: Double = from["latitude"] as! Double
                        let fromLong: Double = from["longitude"] as! Double
                        let fromName: String = from["name"] as! String
                        
                        let to = receivedValue["to"] as! [String: Any]
                        let toLat: Double = to["latitude"] as! Double
                        let toLong: Double = to["longitude"] as! Double
                        let toName: String = to["name"] as! String
                        let timeZone = receivedValue["timeZone"] as? String ?? ""
                        
                        let request = Request(id: snap.key, driver: receivedValue["driver"] as! String, sender: receivedValue["sender"] as! String, from: CLLocationCoordinate2DMake(fromLat, fromLong), fromName: fromName, to: CLLocationCoordinate2DMake(toLat, toLong), toName: toName, time: receivedValue["time"] as! Int, timeZone: TimeZone.init(identifier: timeZone) ?? TimeZone.current, passengers: receivedValue["passengers"] as! Int, status: receivedValue["status"] as! Int, sent: receivedValue["sent"] as? Int)
                        
                        if let value = snap.value as? [String: Any] {
                            request.new = value["new"] as! Bool
                        }
                        request.deleted = receivedValue["deleted"] as! Bool
                        
                        let date = Date(timeIntervalSince1970: Double(request._time))
                        if date.timeIntervalSinceNow < 0 {
                            self.receivedRequests["previous"]?[snap.key] = request
                            if !(self.receivedRequestIDs["previous"]?.contains(snap.key))! {
                                self.receivedRequestIDs["previous"]?.append(snap.key)
                            }
                        } else {
                            self.receivedRequests["upcoming"]?[snap.key] = request
                            if !(self.receivedRequestIDs["upcoming"]?.contains(snap.key))! {
                                self.receivedRequestIDs["upcoming"]?.insert(snap.key, at: 0)
//                                self.receivedRequestIDs["upcoming"]?.append(snap.key)
                            }
                        }
                        
                        var section = 0
                        var time = 0
                        for id in self.sentRequestIDs["upcoming"]! {
                            if self.sentRequests["upcoming"]![id]!.sent > time {
                                time = self.sentRequests["upcoming"]![id]!.sent
                                section = 0
                            }
                        }
                        
                        for id in self.receivedRequestIDs["upcoming"]! {
                            if self.receivedRequests["upcoming"]![id]!.sent > time {
                                time = self.receivedRequests["upcoming"]![id]!.sent
                                section = 1
                            }
                        }
                        
                        if self.changeSection {
                            self.segmentedControl.selectedSegmentIndex = section
                            self.switchSections(self)
                            
                            self.changeSection = false
                        }
                        
                        self.receivedRequestsTable.reloadData()
                        self.receivedRequestsTable.numberOfRows(inSection: 0)
                    }
                })
            }
        })
        
        self.RideDB.child("Users").child(Auth.auth().currentUser!.uid).child("requests").child("sent").observe(.childRemoved, with: { (snapshot) in
            let key = snapshot.key
//                self.sentRequestIDs.remove(at: self.sentRequestIDs.index(of: key)!)
            self.sentRequests.removeValue(forKey: key)
            self.sentRequestsTable.reloadData()
        })
        
        self.RideDB.child("Users").child(Auth.auth().currentUser!.uid).child("requests").child("received").observe(.childRemoved, with: { (snapshot) in
            let key = snapshot.key
//                self.receivedRequestIDs.remove(at: self.receivedRequestIDs.index(of: key)!)
            self.receivedRequests.removeValue(forKey: key)
            self.receivedRequestsTable.reloadData()
        })
    }
}

extension RequestsViewController: UserManagerClient {
    func setUserManager(_ userManager: UserManagerProtocol) {
            self.userManager = userManager
    }
}
