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


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, CLLocationManagerDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    
    var window: UIWindow?
    var userManager: UserManagerProtocol!
    let locationManager = CLLocationManager()
    var RideDB: DatabaseReference?
    var RideStorage: Storage?
    var selectedIndex: Int = 0
    var publishKey = ""
    var secretKey = ""
    var updateLastSeen = true

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        self.window = UIWindow(frame: UIScreen.main.bounds)
        
        
        //To change Navigation Bar Background Color
        UINavigationBar.appearance().barTintColor = UIColor(named: "Main")
        //To change Back button title & icon color
        UINavigationBar.appearance().tintColor = UIColor.white
        //To change Navigation Bar Title Color
        UINavigationBar.appearance().titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        
        // Override point for customization after application launch.
        FirebaseApp.configure()
        userManager = UserManager()
        Messaging.messaging().delegate = self
        SDKApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)
        RideDB = Database.database().reference()
        RideStorage = Storage.storage()
        
        
        
        // Check if user logged in
//        userManager?.getCurrentUser(completion: { (success, _) in
//            if success {
//                moveToWelcomeController()
//            } else {
//                moveToLoginController()
//            }
//        })
        
        RideDB?.child("stripe_keys").observeSingleEvent(of: .value, with: { (snapshot) in
            if let value = snapshot.value as? [String: String] {
                guard let _publishKey = value["publish"], let _secretKey = value["secret"] else {
                    fatalError("Unable to fetch Stripe API keys")
                }
                
                self.publishKey = _publishKey
                self.secretKey = _secretKey
                
                STPPaymentConfiguration.shared().publishableKey = self.publishKey
                STPPaymentConfiguration.shared().appleMerchantIdentifier = "merchant.com.ride"
                STPTheme.default().accentColor = UIColor(named: "Accent")
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
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        if Auth.auth().currentUser != nil {
            if let initialViewController = storyboard.instantiateViewController(withIdentifier: "welcomeTVC-NC") as? UINavigationController {
                if let tabViewController = initialViewController.children.first as? TabViewController {
                    tabViewController.userManager = self.userManager
                    tabViewController.selectedIndex = self.selectedIndex
                    
                    for child in tabViewController.viewControllers ?? [] {
                        if let top = child as? UserManagerClient {
                            top.setUserManager(tabViewController.userManager)
                        }
                    }
                    self.window?.rootViewController = initialViewController
                }
            }
        } else {
            if let initialViewController = storyboard.instantiateViewController(withIdentifier: "loginVC") as? FBLoginViewController {
                initialViewController.userManager = userManager
                self.window?.rootViewController = initialViewController
            }
        }
        
        self.window?.makeKeyAndVisible()
        
        return true
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if Auth.auth().currentUser != nil {
            guard let location: CLLocationCoordinate2D = manager.location?.coordinate else { return }
        
            let locationDict = ["latitude": location.latitude,
                                "longitude": location.longitude] as [String : Any]
            
            updateLastSeen = true
            RideDB?.child("Users").child((Auth.auth().currentUser?.uid)!).child("location").setValue(locationDict)
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
        
        userManager?.getCurrentUser(completion: { (success, user) in
            guard success && user != nil else {
                return
            }
            
            if !(user!.available.isEmpty) {
                if user!.available.values.contains(true) {
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
                
                if self.updateLastSeen {
                    self.updateLastSeen = false
                }
            }
        })
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        userManager?.getCurrentUser(completion: { (success, user) in
            guard success && user != nil else {
                return
            }
            
            if !(user!.available.isEmpty) {
                if user!.available.values.contains(true) {
                    if CLLocationManager.locationServicesEnabled() {
                        self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
                        self.locationManager.stopMonitoringSignificantLocationChanges()
                        self.locationManager.startUpdatingLocation()
                    }
                    
                    if self.updateLastSeen {
                        self.updateLastSeen = false
                    }
                }
            }
        })
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

        if Auth.auth().currentUser?.uid != nil {
            RideDB?.child("Users").child(Auth.auth().currentUser!.uid).child("token").setValue(fcmToken)
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
            
            tabViewController.tabBar.items?[1].badgeColor = UIColor(named: "Accent")
            completionHandler(.newData)
        }
        
        self.selectedIndex = 1
        
        if aps["badge"] != nil {
            application.applicationIconBadgeNumber += aps["badge"] as! Int
        }
    }
    
    public func updateUserLocation() {
        userManager?.getCurrentUser(completion: { (success, user) in
            guard success && user != nil else {
                return
            }
            
            if !(user!.available.isEmpty) {
                if user!.available.values.contains(true) {
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
                
                if self.updateLastSeen {
                    self.updateLastSeen = false
                }
            }
        })
    }
    
    public func stopUpdatingLocation() {
        self.locationManager.stopUpdatingLocation()
        
        userManager?.getCurrentUser(completion: { (success, user) in
            guard success && user != nil else {
                return
            }
            
            guard let keys = (user!.available as NSDictionary?)?.allKeys(for: true) else {
                return
            }
            
            for key in keys {
                self.RideDB?.child("Users").child((Auth.auth().currentUser?.uid)!).child("available").child(key as! String).setValue(false)
                self.RideDB?.child("Groups").child("GroupMeta").child(key as! String).child("available").child((Auth.auth().currentUser?.uid)!).setValue(false)
            }
        })
    }
    
    func getSecretKey(completion: @escaping (String)->()) {
        guard self.secretKey != "" else {
            RideDB?.child("stripe_keys").observeSingleEvent(of: .value, with: { (snapshot) in
                if let value = snapshot.value as? [String: String] {
                    guard let _secretKey = value["secret"] else {
                        fatalError("Unable to fetch Stripe API keys")
                    }
                    completion(_secretKey)
                }
            })
            return
        }
        
        completion(self.secretKey)
    }
}

//func getMainUser(welcome: Bool) {
//    var _welcome = welcome
//    RideDB?.child("Users").child((Auth.auth().currentUser?.uid)!).observe(.value, with: { (snapshot) in
//        if snapshot.value != nil && !(snapshot.value is NSNull) {
//            if var user = snapshot.value as? [String: Any] {
//                if user["name"] != nil && user["photo"] != nil {
//                    if user["car"] == nil {
//                        user["car"] = ["type": "", "mpg": "", "seats": "", "registration": ""]
//                    }
//                    if user["available"] == nil {
//                        user["available"] = [:]
//                    }
//                    if user["location"] == nil {
//                        user["location"] = [:]
//                    }
//                    if user["timestamp"] == nil {
//                        user["timestamp"] = 0.0
//                    }
//
//                    if Auth.auth().currentUser?.uid != nil {
//                        mainUser = User(id: (Auth.auth().currentUser?.uid)!, name: user["name"] as! String, photo: user["photo"] as! String, car: user["car"] as! [String: String], available: user["available"] as! [String : Bool], location: user["location"] as! [String : CLLocationDegrees])
//                        let appDelegate = UIApplication.shared.delegate as! AppDelegate
//
//                        InstanceID.instanceID().instanceID { (result, error) in
//                            if let error = error {
//                                print("Error fetching remote instance ID: \(error)")
//                            } else if let result = result {
//                                if Auth.auth().currentUser?.uid != nil {
//                                    RideDB?.child("Users").child(Auth.auth().currentUser!.uid).child("token").setValue(result.token)
//                                }
//                            }
//                        }
//
//
//                        var available = false
//                        for key in (user["available"] as! [String: Bool]).keys {
//                            if (user["available"] as! [String: Bool])[key]! {
//                                available = true
//                            }
//                        }
//
//                        if available {
//                            appDelegate.updateUserLocation()
//                        } else {
//                            appDelegate.locationManager.stopUpdatingLocation()
//                        }
//                    }
//                } else {
//                    moveToLoginController()
//                }
//            }
//        }
//
//        if _welcome {
//            _welcome = false
//            moveToWelcomeController()
//        }
//    })
//}

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
        tabViewController.userManager = appDelegate.userManager
        tabViewController.selectedIndex = appDelegate.selectedIndex
        
        for child in tabViewController.viewControllers ?? [] {
            if let top = child as? UserManagerClient {
                top.setUserManager(tabViewController.userManager)
            }
        }
    }
    currentViewController?.present(welcomeViewController, animated: true, completion: nil)
}

func moveToLoginController() {
    let mainStoryBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
    if let loginViewController = mainStoryBoard.instantiateViewController(withIdentifier: "loginVC") as? FBLoginViewController {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let currentViewController = appDelegate.window?.rootViewController
        loginViewController.userManager = appDelegate.userManager
        appDelegate.window?.rootViewController = loginViewController
        currentViewController?.present(loginViewController, animated: true, completion: nil)
    }
}

func getDataFromUrl(url: URL, completion: @escaping (Data?, URLResponse?, Error?) -> ()) {
    URLSession.shared.dataTask(with: url) { data, response, error in
        completion(data, response, error)
        }.resume()
}
