//
//  MapCallout.swift
//  Ride
//
//  Created by Ben Mechen on 24/10/2018.
//  Copyright © 2018 Fuse Apps. All rights reserved.
//

import UIKit
import Crashlytics
import MapKit
import Kingfisher
import os.log

protocol UserMapCalloutViewDelegate: class { // 1
    func detailsRequestedForPerson(user: User)
}

class MapCallout: UIView {

    @IBOutlet weak var backgroundContentButton: UIButton!
    @IBOutlet weak var profileImage: UIImageView!
    @IBOutlet weak var userName: UILabel!
    @IBOutlet weak var userCar: UILabel!
    @IBOutlet weak var requestRide: UIButton!
    
    var user: User!
    weak var calloutDelegate: UserMapCalloutViewDelegate?
    var groupDelegate: GroupTableViewCellDelegate!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        profileImage.layer.borderWidth = 1
        profileImage.layer.borderColor = UIColor.red.cgColor
        profileImage.layer.masksToBounds = false
        profileImage.layer.cornerRadius = profileImage.frame.height / 2
        profileImage.clipsToBounds = true
        
        backgroundContentButton.applyArrowDialogAppearanceWithOrientation(arrowOrientation: .down)
    }
    
    @IBAction func click(_ sender: Any) {
        print(" > Name:", self.groupDelegate)
        self.groupDelegate.callSegueFromCell(data: user)
    }
    
    
    func constructWithUser(user: User) {
        self.user = user
        
        profileImage.kf.setImage(
            with: user.photo,
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
        
        userName.text = user.name
        if user.car._carType != "Other" {
            userCar.text = user.car._carSeats + " seat " + user.car._carType
        } else {
            userCar.text = user.car._carSeats + " seat car"
        }
    }
    
    // MARK: - Hit test. We need to override this to detect hits in our custom callout.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Check if it hit our annotation detail view components.
        
        // details button
        if let result = requestRide.hitTest(convert(point, to: requestRide), with: event) {
            return result
        }
        
        // fallback to our background content view
        return backgroundContentButton.hitTest(convert(point, to: backgroundContentButton), with: event)
    }
}

class MapAnnotation: NSObject, MKAnnotation {
    var user: User
    var coordinate: CLLocationCoordinate2D
    
    init? (user: User) {
        guard user.location["latitude"] != nil && user.location["longitude"] != nil else {
            return nil
        }
        
        self.user = user
        coordinate = CLLocationCoordinate2DMake(self.user.location["latitude"]!, self.user.location["longitude"]!)
        super.init()
    }
    
    var title: String? {
        return user.name
    }
    
    var subtitle: String? {
        if user.car._carType != "Other" {
            return user.car._carSeats + " seat " + user.car._carType
        }
        return user.car._carSeats + " seat car"
    }
}

class MapAnnotationView: MKAnnotationView {
    // data
    var user: User!
    var delegate: GroupTableViewCellDelegate!
    
    weak var customCalloutView: MapCallout?
    override var annotation: MKAnnotation? {
        willSet { customCalloutView?.removeFromSuperview() }
    }
    
    // MARK: - life cycle
    
    init(annotation: MKAnnotation?, reuseIdentifier: String?, delegate: GroupTableViewCellDelegate?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        self.canShowCallout = false // 1
        self.delegate = delegate
//        self.image = kPersonMapPinImage
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.canShowCallout = false // 1
//        self.image = kPersonMapPinImage
    }
    
    // MARK: - callout showing and hiding
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        if selected {
            self.customCalloutView?.removeFromSuperview()
            
            if let newCustomCalloutView = loadUserDetailMapView() {
                newCustomCalloutView.frame.origin.x -= newCustomCalloutView.frame.width / 2.0 - (self.frame.width / 2.0)
                newCustomCalloutView.frame.origin.y -= newCustomCalloutView.frame.height
                
                self.addSubview(newCustomCalloutView)
                self.customCalloutView = newCustomCalloutView
                self.customCalloutView?.groupDelegate = self.delegate
                
                if animated {
                    self.customCalloutView!.alpha = 0.0
                    UIView.animate(withDuration: 1.0, animations: {
                        self.customCalloutView!.alpha = 1.0
                    })
                }
            }
        } else {
            if customCalloutView != nil {
                if animated {
                    UIView.animate(withDuration: 1.0, animations: {
                        self.customCalloutView!.alpha = 0.0
                    }, completion: { (success) in
                        self.customCalloutView!.removeFromSuperview()
                    })
                } else { self.customCalloutView!.removeFromSuperview() }
            }
        }
    }
    
    
    func loadUserDetailMapView() -> MapCallout? {
        if let views = Bundle.main.loadNibNamed("MapCallout", owner: self, options: nil) as? [MapCallout], views.count > 0 {
            let userDetailMapView = views.first!
            if let userAnnotation = annotation as? MapAnnotation {
                let user = userAnnotation.user
                userDetailMapView.constructWithUser(user: user)
            }
            return userDetailMapView
        }
        return nil
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.customCalloutView?.removeFromSuperview()
    }
    
    // MARK: - Detecting and reaction to taps on custom callout.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // if super passed hit test, return the result
        if let parentHitView = super.hitTest(point, with: event) { return parentHitView }
        else { // test in our custom callout.
            if customCalloutView != nil {
                return customCalloutView!.hitTest(convert(point, to: customCalloutView!), with: event)
            } else {
                return nil
            }
        }
    }
}
