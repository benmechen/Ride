//
//  AppDelegate.swift
//  Ride
//
//  Created by Ben Mechen on 08/07/2018.
//  Copyright © 2018 Fuse Apps. All rights reserved.
//

import UIKit
import MapKit
import Firebase
import Crashlytics
import FacebookCore
import Stripe
import UserNotifications


var fbAccessToken: AccessToken? = AccessToken(authenticationToken: "EAAE9cjLdKLMBAD2eGDzdgKa8Am7lL1026f7mOUzObhm296MaFUf4LNeZAqW7qeZCb0wqtcdYg5NhzR2cK3snISqzWaghQw3v7hFQNWX7xY0K2NrkD7eTXZBlWMlIvsN6RpkBYEp4v0VzIk3iODHu7IEpPTVq5cZCeQm0B90vjPiZAAmvsEivNNKE4oxxOf25pBFOefeZC5f8TgUAbZCVHhfzZBzlDW3sA85D08RZBAAczntXoS6DrNPd7")
var mainUser: User?
var currentFBUser: UserProfile?
var RideDB: DatabaseReference?
var RideStorage: Storage?
var currentUser: FirebaseAuth.User?
var rideRed: UIColor = UIColor(red:0.67, green:0.00, blue:0.10, alpha:1.00)
var rideClickableRed: UIColor = UIColor(red:1.00, green:0.17, blue:0.33, alpha:1.0)
var updateLastSeen = true
var vSpinner : UIView?
var publishKey = ""
var secretKey = ""
//var dataManager: DataManager = DataManager()

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, CLLocationManagerDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    
    var window: UIWindow?
    let locationManager = CLLocationManager()
    var selectedIndex: Int = 0

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        //To change Navigation Bar Background Color
        UINavigationBar.appearance().barTintColor = rideRed
        //To change Back button title & icon color
        UINavigationBar.appearance().tintColor = UIColor.white
        //To change Navigation Bar Title Color
        UINavigationBar.appearance().titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        
        // Override point for customization after application launch.
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        SDKApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)
        RideDB = Database.database().reference()
        RideStorage = Storage.storage()
        
        currentUser = Auth.auth().currentUser
        
        if currentUser?.uid == nil {
            //Not already logged in
            moveToLoginController()
        } else {
            //Already logged in
            getMainUser(welcome: true)
        }
        
        RideDB?.child("stripe_keys").observeSingleEvent(of: .value, with: { (snapshot) in
            if let value = snapshot.value as? [String: String] {
                guard let _publishKey = value["publish"], let _secretKey = value["secret"] else {
                    fatalError("Unable to fetch Stripe API keys")
                }
                
                publishKey = _publishKey
                secretKey = _secretKey
                
                STPPaymentConfiguration.shared().publishableKey = publishKey
                STPPaymentConfiguration.shared().appleMerchantIdentifier = "merchant.com.ride"
                STPTheme.default().accentColor = rideClickableRed
            }
        })
        
        if #available(iOS 10.0, *) {
            // For iOS 10 display notification (sent via APNS)
            UNUserNotificationCenter.current().delegate = self
            
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
                options: authOptions,
                completionHandler: {_, _ in })
        } else {
            let settings: UIUserNotificationSettings =
                UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            application.registerUserNotificationSettings(settings)
        }
        
        application.registerForRemoteNotifications()
        
        let notificationOption = launchOptions?[.remoteNotification]
        
        if (notificationOption as? [String: AnyObject]) != nil {
            self.selectedIndex = 1
        }
        
        return true
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if currentUser != nil {
            guard let location: CLLocationCoordinate2D = manager.location?.coordinate else { return }
        
            let locationDict = ["latitude": location.latitude,
                                "longitude": location.longitude] as [String : Any]
            
            updateLastSeen = true
            RideDB?.child("Users").child((currentUser?.uid)!).child("location").setValue(locationDict)
        }
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        let handled = SDKApplicationDelegate.shared.application(app, open: url, options: options)
        
        return handled
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        
        if (mainUser != nil) {
            if !((mainUser?._userAvailable.isEmpty)!) {
                if (mainUser?._userAvailable.values.contains(true))! {
                    if CLLocationManager.locationServicesEnabled() {
//                        self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
                        self.locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
                        self.locationManager.startMonitoringSignificantLocationChanges()
                    } else {
                        self.locationManager.stopUpdatingLocation()
                    }
                } else {
                    self.locationManager.stopUpdatingLocation()
                }
                
                if updateLastSeen {
                    updateLastSeen = false
                }
            }
        } else {
            if currentUser != nil {
                RideDB?.child("Users").observeSingleEvent(of: .value, with: { (snapshot) in
                    if !snapshot.hasChild((currentUser?.uid)!){
                        RideDB?.child("Users").child((currentUser?.uid)!).setValue(["name": currentUser?.displayName as Any, "photo": currentUser?.photoURL?.absoluteString as Any, "car": ["type": "", "mpg": "", "seats": ""]])
                        
                        mainUser = User(id: (currentUser?.uid)!, name: (currentUser?.displayName)!, photo: (currentUser?.photoURL?.absoluteString)!, car: ["type": "", "mpg": "", "seats": ""], available: [:], location: [:], timestamp: 0.0)
                    }
                })
            }
        }
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        if (mainUser != nil) {
            if !((mainUser?._userAvailable.isEmpty)!) {
                if (mainUser?._userAvailable.values.contains(true))! {
                    if CLLocationManager.locationServicesEnabled() {
                        self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
                        self.locationManager.stopMonitoringSignificantLocationChanges()
                        self.locationManager.startUpdatingLocation()
                    }
                    
                    if updateLastSeen {
                        updateLastSeen = false
                    }
                }
            }
        } else {
            guard currentUser != nil else {
                return
            }
            
            RideDB?.child("Users").observeSingleEvent(of: .value, with: { (snapshot) in
                if !snapshot.hasChild((currentUser?.uid)!) {
                    RideDB?.child("Users").child((currentUser?.uid)!).setValue(["name": currentUser?.displayName as Any, "photo": currentUser?.photoURL?.absoluteString as Any, "car": ["type": "", "mpg": "", "seats": "", "registration": ""]])
                    
                    mainUser = User(id: (currentUser?.uid)!, name: (currentUser?.displayName)!, photo: (currentUser?.photoURL?.absoluteString)!, car: ["type": "", "mpg": "", "seats": "", "registration": ""], available: [:], location: [:], timestamp: 0.0)
                }
            })
        }
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        
        UIApplication.shared.applicationIconBadgeNumber = 0
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    func messaging(_ messaging: Messaging, didReceive remoteMessage: MessagingRemoteMessage) {
        if let aps = remoteMessage.appData["aps"] as? [String: AnyObject], let alert = aps["alert"] as? [String: Any] {
            guard let title = alert["title"] as? String, let body = alert["body"] as? String else {
                return
            }
            let alert = UIAlertController(title: title, message: body, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: nil))
            self.window?.rootViewController?.present(alert, animated: true, completion: nil)
        }
    }
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String) {
        print("Firebase registration token: \(fcmToken)")
        
        let dataDict: [String: String] = ["token": fcmToken]
        NotificationCenter.default.post(name: Notification.Name("FCMToken"), object: nil, userInfo: dataDict)

        if currentUser?.uid != nil {
            RideDB?.child("Users").child(currentUser!.uid).child("token").setValue(fcmToken)
        }
    }
    
    func application( _ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard let aps = userInfo["aps"] as? [String: AnyObject] else {
            completionHandler(.failed)
            return
        }
        
        if let alert = aps["alert"] as? [String: Any] {
            guard let title = alert["title"] as? String, let body = alert["body"] as? String else {
                return
            }
            let alert = UIAlertController(title: title, message: body, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: nil))
            self.window?.rootViewController?.present(alert, animated: true, completion: nil)
        }
        
        if let tabViewController = window?.rootViewController?.children.first as? TabViewController {
            if Int(tabViewController.tabBar.items?[1].badgeValue ?? "0") == 0 {
                if aps["badge"] != nil && aps["badge"] as! Int != 0 {
                    tabViewController.tabBar.items?[1].badgeValue = "1"
                }
            } else {
                tabViewController.tabBar.items?[1].badgeValue = String((Int(tabViewController.tabBar.items?[1].badgeValue ?? "0") ?? 0) + 1)
            }
            
            tabViewController.tabBar.items?[1].badgeColor = rideClickableRed
            completionHandler(.newData)
        }
        
        self.selectedIndex = 1
        
        if aps["badge"] != nil {
            application.applicationIconBadgeNumber += aps["badge"] as! Int
        }
    }
    
    public func updateUserLocation() {
        if !((mainUser?._userAvailable.isEmpty)!) {
            if (mainUser?._userAvailable.values.contains(true))! {
                self.locationManager.requestAlwaysAuthorization()
                self.locationManager.requestWhenInUseAuthorization()
                if CLLocationManager.locationServicesEnabled() {
                    self.locationManager.delegate = self
                    self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
                    
                    self.locationManager.pausesLocationUpdatesAutomatically = true
                    self.locationManager.activityType = .automotiveNavigation
                    self.locationManager.allowsBackgroundLocationUpdates = true
                    
                    self.locationManager.startUpdatingLocation()
                } else {
                    self.locationManager.stopUpdatingLocation()
                }
            } else {
                self.locationManager.stopUpdatingLocation()
            }
            
            if updateLastSeen {
                updateLastSeen = false
            }
        }
    }
    
    public func stopUpdatingLocation() {
        
        self.locationManager.stopUpdatingLocation()
        
        let keys = (mainUser?._userAvailable as! NSDictionary).allKeys(for: true)
        
        for key in keys {
            RideDB?.child("Users").child((currentUser?.uid)!).child("available").child(key as! String).setValue(false)
            RideDB?.child("Groups").child("GroupMeta").child(key as! String).child("available").child((currentUser?.uid)!).setValue(false)
        }
    }
}

func getMainUser(welcome: Bool) {
    var _welcome = welcome
    RideDB?.child("Users").child((currentUser?.uid)!).observe(.value, with: { (snapshot) in
        if snapshot.value != nil && !(snapshot.value is NSNull) {
            if var user = snapshot.value as? [String: Any] {
                if user["name"] != nil && user["photo"] != nil {
                    if user["car"] == nil {
                        user["car"] = ["type": "", "mpg": "", "seats": "", "registration": ""]
                    }
                    if user["available"] == nil {
                        user["available"] = [:]
                    }
                    if user["location"] == nil {
                        user["location"] = [:]
                    }
                    if user["timestamp"] == nil {
                        user["timestamp"] = 0.0
                    }
                    
                    if currentUser?.uid != nil {
                        mainUser = User(id: (currentUser?.uid)!, name: user["name"] as! String, photo: user["photo"] as! String, car: user["car"] as! [String: String], available: user["available"] as! [String : Bool], location: user["location"] as! [String : CLLocationDegrees], timestamp: user["timestamp"] as! TimeInterval)
                        let appDelegate = UIApplication.shared.delegate as! AppDelegate
                        
                        InstanceID.instanceID().instanceID { (result, error) in
                            if let error = error {
                                print("Error fetching remote instance ID: \(error)")
                            } else if let result = result {
                                if currentUser?.uid != nil {
                                    RideDB?.child("Users").child(currentUser!.uid).child("token").setValue(result.token)
                                }
                            }
                        }

                        
                        var available = false
                        for key in (user["available"] as! [String: Bool]).keys {
                            if (user["available"] as! [String: Bool])[key]! {
                                available = true
                            }
                        }
                        
                        if available {
                            appDelegate.updateUserLocation()
                        } else {
                            appDelegate.locationManager.stopUpdatingLocation()
                        }
                    }
                } else {
                    moveToLoginController()
                }
            }
        }
        
        if _welcome {
            _welcome = false
            moveToWelcomeController()
        }
    })
}

func moveToSetupController(skip: Bool = false) {
    let mainStoryBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
    var welcomeViewController: UIViewController
    if skip {
        welcomeViewController = mainStoryBoard.instantiateViewController(withIdentifier: "setupPage2")
    } else {
        welcomeViewController = mainStoryBoard.instantiateViewController(withIdentifier: "setupPage1")
    }
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    let currentViewController = appDelegate.window?.rootViewController
    appDelegate.window?.rootViewController = welcomeViewController
    currentViewController?.present(welcomeViewController, animated: true, completion: nil)
}

func moveToWelcomeController() {
    let mainStoryBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
    let welcomeViewController: UIViewController = mainStoryBoard.instantiateViewController(withIdentifier: "welcomeTVC-NC")
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    let currentViewController = appDelegate.window?.rootViewController
//    appDelegate.updateUserLocation()
    appDelegate.window?.rootViewController = welcomeViewController
    if let tabViewController = appDelegate.window?.rootViewController?.children.first as? TabViewController {
        tabViewController.selectedIndex = appDelegate.selectedIndex
    }
    currentViewController?.present(welcomeViewController, animated: true, completion: nil)
}

func moveToLoginController() {
    let mainStoryBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
    let loginViewController: UIViewController = mainStoryBoard.instantiateViewController(withIdentifier: "loginVC")
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    let currentViewController = appDelegate.window?.rootViewController
    appDelegate.window?.rootViewController = loginViewController
    currentViewController?.present(loginViewController, animated: true, completion: nil)
}

func getDataFromUrl(url: URL, completion: @escaping (Data?, URLResponse?, Error?) -> ()) {
    URLSession.shared.dataTask(with: url) { data, response, error in
        completion(data, response, error)
        }.resume()
}
