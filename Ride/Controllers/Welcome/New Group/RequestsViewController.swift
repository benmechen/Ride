//
//  RequestsViewController.swift
//  Ride
//
//  Created by Ben Mechen on 04/01/2019.
//  Copyright © 2019 Fuse Apps. All rights reserved.
//

import UIKit
import Firebase
import MapKit
import os.log

class RequestsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var sentRequestsTable: UITableView!
    @IBOutlet weak var receivedRequestsTable: UITableView!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    
    var sentRequestIDs = [String]()
    var sentRequests: [String: Request] = [:]
    var receivedRequestIDs = [String]()
    var receivedRequests: [String: Request] = [:]
    var index: Int = -1
    var userName = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        //Hide NavBar bottom line
        self.navigationController?.navigationBar.setValue(true, forKey: "hidesShadow")
        
        //Set titles
        segmentedControl.setTitle("Sent", forSegmentAt: 0)
        segmentedControl.setTitle("Received", forSegmentAt: 1)
        
        //Get NavBar width
        let navigationBarWidth = Int(self.navigationController!.navigationBar.frame.width)
        //Create variable with width for Segmented Controller
        var segmentedControllerWidth = 0
        var segmentedControllerY = 0
        var xSC = 0
        
        if UIDevice().userInterfaceIdiom == .phone {
            print(UIScreen.main.nativeBounds.height)
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
//                segmentedControl.superview?.frame = CGRect(x: 0, y: 85, width: CGFloat(375), height: CGFloat(46))
            default:
                //Unknown
                xSC = 16
                segmentedControllerWidth = navigationBarWidth-32
            }
        }
        
        let y = segmentedControl.frame.origin.y + CGFloat(segmentedControllerY)
        
        //Set width
        segmentedControl.frame = CGRect(x: CGFloat(xSC), y: y, width: CGFloat(segmentedControllerWidth), height: segmentedControl.frame.size.height + 5)
        
//        getUserRequests()
        
        sentRequestsTable.delegate = self
        sentRequestsTable.dataSource = self
        receivedRequestsTable.delegate = self
        receivedRequestsTable.dataSource = self
        
        sentRequestsTable.isHidden = true
        receivedRequestsTable.isHidden = false
        
        segmentedControl.selectedSegmentIndex = 0
        switchSections(self)
            
    }
    
    override func viewWillAppear(_ animated: Bool) {
        sentRequests.removeAll()
        receivedRequests.removeAll()
        getUserRequests()
    }
    
    // MARK: - Table stuff
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == self.sentRequestsTable {
            return self.sentRequests.count
        }
        return self.receivedRequests.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = "RequestsTableCell"
        
        if tableView == self.sentRequestsTable {
            guard let cell = sentRequestsTable.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? RequestsTableViewCell else {
                fatalError("The dequeued cell is not an instance of RequestsTableViewCell")
            }
            
            sentRequestsTable.deselectRow(at: indexPath, animated: true)
            
            let request = sentRequests[sentRequestIDs[indexPath.row]]
            
            // Name & profile image
            RideDB!.child("Users").child((request?._driver)!).observeSingleEvent(of: .value) { (snapshot) in
                let value = snapshot.value as! [String : Any]
                
                cell.name.text = (value["name"] as! String)
                cell.profileImage.image(fromUrl: value["photo"] as! String)
            }
            
            // To
            let date = Date(timeIntervalSince1970: Double((request?._time)!))
            let dateFormatter = DateFormatter()
            dateFormatter.timeStyle = .short
            dateFormatter.dateStyle = .none
            cell.start.text = dateFormatter.string(from: date)
            
            // People
            cell.people.text = String(request?._passengers ?? 0)
            if request?._passengers == 1 {
                cell.people.text = cell.people.text! + " person"
            } else {
                cell.people.text = cell.people.text! + " people"
            }
            
            // Location calculation
            let directionsRequest = MKDirections.Request()
            let sourcePlacemark = MKPlacemark(coordinate: (request?._from)!)
            let destinationPlacemark = MKPlacemark(coordinate: (request?._to)!)
            let source = MKMapItem(placemark: sourcePlacemark)
            let destination = MKMapItem(placemark: destinationPlacemark)
            directionsRequest.destination = destination
            directionsRequest.source = source
            directionsRequest.transportType = .automobile
            directionsRequest.departureDate = date
            
            let directions = MKDirections(request: directionsRequest)
            directions.calculateETA { (etaResponse, error) in
                if let error = error {
                    os_log("Error calculating route", log: OSLog.default, type: .error)
                    self.dismiss(animated: true, completion: nil)
                    return
                } else {
                    cell.end.text = dateFormatter.string(from: (etaResponse?.expectedArrivalDate)!)
                }
            }
            
            cell.from.text = request?._fromName
            cell.to.text = request?._toName
            
            if request!.new {
//                cell.name.font = UIFont.boldSystemFont(ofSize: 18.0)
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
            
            let request = receivedRequests[receivedRequestIDs[indexPath.row]]
            
            // Name & profile image
            RideDB?.child("Users").child(request!._sender).observeSingleEvent(of: .value) { (snapshot) in
                let value = snapshot.value as! [String : Any]
                
                cell.name.text = (value["name"] as! String)
                cell.profileImage.image(fromUrl: value["photo"] as! String)
            }
            
            // To
            let date = Date(timeIntervalSince1970: Double(request!._time))
            let dateFormatter = DateFormatter()
            dateFormatter.timeStyle = .short
            dateFormatter.dateStyle = .none
            cell.start.text = dateFormatter.string(from: date)
            
            // People
            cell.people.text = String(request?._passengers ?? 0)
            if request?._passengers == 1 {
                cell.people.text = cell.people.text! + " person"
            } else {
                cell.people.text = cell.people.text! + " people"
            }
            
            // Location calculation
            let directionsRequest = MKDirections.Request()
            let sourcePlacemark = MKPlacemark(coordinate: request!._from)
            let destinationPlacemark = MKPlacemark(coordinate: request!._to)
            let source = MKMapItem(placemark: sourcePlacemark)
            let destination = MKMapItem(placemark: destinationPlacemark)
            directionsRequest.destination = destination
            directionsRequest.source = source
            directionsRequest.transportType = .automobile
            directionsRequest.departureDate = date
            
            let directions = MKDirections(request: directionsRequest)
            directions.calculateETA { (etaResponse, error) in
                if let error = error {
                    os_log("Error calculating route", log: OSLog.default, type: .error)
                    self.dismiss(animated: true, completion: nil)
                    return
                } else {
                    cell.end.text = dateFormatter.string(from: (etaResponse?.expectedArrivalDate)!)
                }
            }
            
            cell.from.text = request!._fromName
            cell.to.text = request!._toName
            
            if request!.new {
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
        self.index = indexPath.row
        let cell = tableView.cellForRow(at: indexPath) as! RequestsTableViewCell
        
        self.userName = cell.name.text ?? ""
        
        if tableView == self.sentRequestsTable {
            self.performSegue(withIdentifier: "moveToSentRequest", sender: self)
        } else {
            self.performSegue(withIdentifier: "moveToReceivedRequest", sender: self)
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt: IndexPath) -> [UITableViewRowAction]? {
        let delete = UITableViewRowAction(style: .destructive, title: "Delete") { action, index in
            if self.segmentedControl.selectedSegmentIndex == 0 {
                RideDB?.child("Requests").child(self.sentRequestIDs[editActionsForRowAt.row]).child("deleted").setValue(true)
                RideDB?.child("Users").child((self.sentRequests[self.sentRequestIDs[editActionsForRowAt.row]]?._sender)!).child("requests").child("sent").child(self.sentRequestIDs[editActionsForRowAt.row]).removeValue()
                self.sentRequests.removeValue(forKey: self.sentRequestIDs[editActionsForRowAt.row])
                self.sentRequestIDs.remove(at: editActionsForRowAt.row)
                self.sentRequestsTable.reloadData()
            } else if self.segmentedControl.selectedSegmentIndex == 1 {
                RideDB?.child("Requests").child(self.receivedRequestIDs[editActionsForRowAt.row]).child("deleted").setValue(true)
                RideDB?.child("Users").child((self.receivedRequests[self.receivedRequestIDs[editActionsForRowAt.row]]?._driver)!).child("requests").child("received").child(self.receivedRequestIDs[editActionsForRowAt.row]).removeValue()
                self.receivedRequests.removeValue(forKey: self.receivedRequestIDs[editActionsForRowAt.row])
                self.receivedRequestIDs.remove(at: editActionsForRowAt.row)
                self.receivedRequestsTable.reloadData()
            }
        }
        
        return [delete]
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        print("Preparing to segue: \(segue.identifier)")
        
        switch(segue.identifier ?? "") {
        case "moveToSentRequest":
            let sentRequestsPageViewController = segue.destination as! SentRequestsPageViewController
            sentRequestsPageViewController.request = sentRequests[sentRequestIDs[index]]
            sentRequestsPageViewController.userName = self.userName
        case "moveToReceivedRequest":
            let receivedRequestsPageViewController = segue.destination as! ReceivedRequestsPageViewController
            receivedRequestsPageViewController.request = receivedRequests[receivedRequestIDs[index]]
            receivedRequestsPageViewController.userName = self.userName
        default:
            fatalError("Unexpected Segue Identifier; \(String(describing: segue.identifier))")
        }
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
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
        }
    }
    
    // MARK: - Private functions
    
    private func getUserRequests() {
        if RideDB != nil {
            RideDB?.child("Users").child((mainUser?._userID)!).child("requests").observe(.value, with: { (snapshot) in
                if let value = snapshot.value as? NSDictionary {
                    // Fetch sent requests
                    if let sentRequestIDs = value["sent"] as? [String: Bool] {
                        for requestID in sentRequestIDs.keys {
                            if !self.sentRequestIDs.contains(requestID) {
                                self.sentRequestIDs.append(requestID)
                            }
                            RideDB?.child("Requests").child(requestID as! String).observeSingleEvent(of: .value, with: { (snapshot) in
                                if let sentValue = snapshot.value as? [String: Any] {
                                    let from = sentValue["from"] as! [String: Any]
                                    let fromLat: Double = from["latitude"] as! Double
                                    let fromLong: Double = from["longitude"] as! Double
                                    let fromName: String = from["name"] as! String
                                    
                                    let to = sentValue["to"] as! [String: Any]
                                    let toLat: Double = to["latitude"] as! Double
                                    let toLong: Double = to["longitude"] as! Double
                                    let toName: String = to["name"] as! String
                                    
                                    let request = Request(id: requestID, driver: sentValue["driver"] as! String, sender: sentValue["sender"] as! String, from: CLLocationCoordinate2DMake(fromLat, fromLong), fromName: fromName, to: CLLocationCoordinate2DMake(toLat, toLong), toName: toName, time: sentValue["time"] as! Int, passengers: sentValue["passengers"] as! Int)
                                    
                                    request.new = sentRequestIDs[requestID]!
                                    request.deleted = sentValue["deleted"] as! Bool
                                    
                                    self.sentRequests[requestID] = request
                                    self.sentRequestsTable.reloadData()
                                    self.sentRequestsTable.numberOfRows(inSection: 0)
                                }
                            })
                        }
                    }
                    
                    // Fetch received requests
                    if let receivedRequestIDs = value["received"] as? [String: Bool] {
                        for requestID in receivedRequestIDs.keys {
                            if !self.receivedRequestIDs.contains(requestID) {
                                self.receivedRequestIDs.append(requestID)
                            }
                            RideDB?.child("Requests").child(requestID as! String).observeSingleEvent(of: .value, with: { (snapshot) in
                                if let receivedValue = snapshot.value as? [String: Any] {
                                    let from = receivedValue["from"] as! [String: Any]
                                    let fromLat: Double = from["latitude"] as! Double
                                    let fromLong: Double = from["longitude"] as! Double
                                    let fromName: String = from["name"] as! String
                                    
                                    let to = receivedValue["to"] as! [String: Any]
                                    let toLat: Double = to["latitude"] as! Double
                                    let toLong: Double = to["longitude"] as! Double
                                    let toName: String = to["name"] as! String
                                    
                                    let request = Request(id: requestID, driver: receivedValue["driver"] as! String, sender: receivedValue["sender"] as! String, from: CLLocationCoordinate2DMake(fromLat, fromLong), fromName: fromName, to: CLLocationCoordinate2DMake(toLat, toLong), toName: toName, time: receivedValue["time"] as! Int, passengers: receivedValue["passengers"] as! Int)
                                    
                                    request.new = receivedRequestIDs[requestID]!
                                    request.deleted = receivedValue["deleted"] as! Bool
                                    
//                                    self.receivedRequests.append(request)
                                    self.receivedRequests[requestID] = request
                                    self.receivedRequestsTable.reloadData()
                                    self.receivedRequestsTable.numberOfRows(inSection: 0)
                                }
                            })
                        }
                    }
                }
            })
        }
    }
}
