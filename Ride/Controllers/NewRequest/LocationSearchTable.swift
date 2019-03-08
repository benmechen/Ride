//
//  LocationSearchTable.swift
//  Ride
//
//  Created by Ben Mechen on 30/12/2018.
//  Copyright © 2018 Fuse Apps. All rights reserved.
//


import UIKit
import Crashlytics
import MapKit

class LocationSearchTable : UITableViewController, UISearchResultsUpdating {
    var matchingItems:[MKMapItem] = []
    var mapView: MKMapView? = nil
    var handleMapSearchDelegate: HandleMapSearch? = nil
    var userCoordinates: CLLocationCoordinate2D? = nil
    
    func updateSearchResults(for searchController: UISearchController) {
        guard let mapView = mapView, let searchBarText = searchController.searchBar.text else {
            return
        }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchBarText
        request.region = mapView.region
        let search = MKLocalSearch(request: request)
        
        search.start { (response, _) in
            guard let response = response else {
                return
            }
            self.matchingItems = response.mapItems
            self.tableView.reloadData()
        }
    }
    
    func parseAddress(selectedItem:MKPlacemark) -> String {
        let firstSpace = (selectedItem.subThoroughfare != nil && selectedItem.thoroughfare != nil) ? " " : ""
        let comma = (selectedItem.subThoroughfare != nil || selectedItem.thoroughfare != nil) && (selectedItem.subAdministrativeArea != nil || selectedItem.administrativeArea != nil) ? ", " : ""
        let secondSpace = (selectedItem.subAdministrativeArea != nil && selectedItem.administrativeArea != nil) ? " " : ""
        let addressLine = String(
            format:"%@%@%@%@%@%@%@",
            // street number
            selectedItem.subThoroughfare ?? "",
            firstSpace,
            // street name
            selectedItem.thoroughfare ?? "",
            comma,
            // city
            selectedItem.locality ?? "",
            secondSpace,
            // state
            selectedItem.administrativeArea ?? ""
        )
        return addressLine
    }
    
    // MARK: - Table stuff
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return matchingItems.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") as! RequestTableViewCell
        
        guard indexPath.row < matchingItems.count else {
            return cell
        }
        
        guard let latitude = userCoordinates?.latitude, let longitude = userCoordinates?.longitude else {
            return cell
        }
        
        let selectedItem = matchingItems[indexPath.row].placemark
        cell.location?.text = selectedItem.name
        
        // Calculate distance
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let destination = CLLocation(latitude: selectedItem.coordinate.latitude, longitude: selectedItem.coordinate.longitude)
        let distance = location.distance(from: destination)
        let distForm = MKDistanceFormatter()
        cell.distance?.text = distForm.string(fromDistance: distance)
        
        cell.address?.text = parseAddress(selectedItem: selectedItem)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.row < matchingItems.count else {
            return
        }
        
        let selectedItem = matchingItems[indexPath.row].placemark
        handleMapSearchDelegate?.dropPinZoom(placemark: selectedItem)
        dismiss(animated: true, completion: nil)
    }

}
