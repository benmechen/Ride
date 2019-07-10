//
//  RequestFromViewController.swift
//  Ride
//
//  Created by Ben Mechen on 31/12/2018.
//  Copyright © 2018 Fuse Apps. All rights reserved.
//

import UIKit
import Crashlytics
import Firebase
import MapKit

class RequestFromViewController: UIViewController {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var select: UIButton!
    
    var userManager: UserManagerProtocol!
    lazy var RideDB = Database.database().reference()
    var user: User? = nil
    let locationManager = CLLocationManager()
    var searchController: UISearchController? = nil
    var matchingItems:[MKMapItem] = []
    var selectedPin: MKPlacemark? = nil
    var locationSearchTable: LocationSearchTable? = nil
    var region: MKCoordinateRegion? = nil
    var destination: MKPlacemark? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if region != nil {
            mapView.region = region!
        }
        
        select.layer.shadowOffset = CGSize(width: 0.0, height: 1.0)
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()
        
        locationSearchTable = storyboard!.instantiateViewController(withIdentifier: "LocationSearchTable") as? LocationSearchTable
        locationSearchTable!.mapView = mapView
        locationSearchTable!.handleMapSearchDelegate = self
        locationSearchTable!.userCoordinates = mapView.userLocation.coordinate
        searchController = UISearchController(searchResultsController: locationSearchTable)
        searchController?.searchResultsUpdater = locationSearchTable
        
        searchController!.searchResultsUpdater = locationSearchTable
        searchController!.obscuresBackgroundDuringPresentation = false
        searchController!.searchBar.placeholder = "Where do you want to be picked up?"
        searchController!.hidesNavigationBarDuringPresentation = false
        searchController!.dimsBackgroundDuringPresentation = false
        navigationItem.searchController = searchController
        definesPresentationContext = true
    }
    
    
    // MARK: - Search controller
    
    override func viewWillAppear(_ animated: Bool) {
        if #available(iOS 11.0, *) {
            navigationItem.hidesSearchBarWhenScrolling = false
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if #available(iOS 11.0, *) {
            navigationItem.hidesSearchBarWhenScrolling = false
        }
    }
    
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        print("Preparing to segue: \(String(describing: segue.identifier))")
        
        if segue.identifier == "moveToRequest" {
            let requestSendViewController = segue.destination as! RequestSendViewController
            requestSendViewController.to = destination
            requestSendViewController.from = selectedPin
            requestSendViewController.user = user
            requestSendViewController.userManager = userManager
            // Set back button
            let backButton = UIBarButtonItem()
            backButton.title = "Back"
            navigationItem.backBarButtonItem = backButton
        }
    }
    
    
    // MARK: - Actions
    @IBAction func selectDestination(_ sender: Any) {
        
    }
    
}

extension RequestFromViewController : CLLocationManagerDelegate {
    private func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse {
            locationManager.requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            let span = MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
            let region = MKCoordinateRegion(center: location.coordinate, span: span)
            mapView.setRegion(region, animated: true)
            locationSearchTable?.userCoordinates = mapView.userLocation.coordinate
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("error:: (error)")
    }
}

extension RequestFromViewController: HandleMapSearch {
    func dropPinZoom(placemark: MKPlacemark) {
        select.isHidden = false
        
        selectedPin = placemark
        mapView.removeAnnotations(mapView.annotations)
        let annotation = MKPointAnnotation()
        annotation.coordinate = placemark.coordinate
        annotation.title = placemark.name
        if let city = placemark.locality,
            let state = placemark.administrativeArea {
            annotation.subtitle = city + " " + state
        }
        
        mapView.addAnnotation(annotation)
        let span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        let region = MKCoordinateRegion(center: placemark.coordinate, span: span)
        mapView.setRegion(region, animated: true)
    }
}
