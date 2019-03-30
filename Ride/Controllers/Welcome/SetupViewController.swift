//
//  SetupViewController.swift
//  Ride
//
//  Created by Ben Mechen on 08/09/2018.
//  Copyright © 2018 Fuse Apps. All rights reserved.
//

import UIKit
import os.log
import Stripe
import Firebase
import Crashlytics
import AVFoundation
import Alamofire
import UserNotifications

class SetupViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate, UITextFieldDelegate, AVCapturePhotoCaptureDelegate {

    @IBOutlet weak var page1Yes: UIButton!
    @IBOutlet weak var page1No: UIButton!
    @IBOutlet weak var carTypeTextField: UITextField!
    @IBOutlet weak var numberPlateTextField: UITextField!
    @IBOutlet weak var mpgTextField: UITextField!
    @IBOutlet weak var noOfSeatsTextField: UITextField!
    @IBOutlet weak var addCardButton: UIButton!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var dobTextField: UITextField!
    @IBOutlet weak var addressL1TextField: UITextField!
    @IBOutlet weak var addressL2TextField: UITextField!
    @IBOutlet weak var cityTextField: UITextField!
    @IBOutlet weak var countyTextField: UITextField!
    @IBOutlet weak var postcodeTextField: UITextField!
    @IBOutlet weak var sortCodeTextField: UITextField!
    @IBOutlet weak var accountNumberTextField: UITextField!
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var cameraShutter: UIButton!
    
    var welcomeTableViewController: WelcomeTableViewController? = nil
    
    var skip: Bool = false
    var selectedType: String?
    var carTypes = ["Hatchback", "Estate", "SUV", "Saloon", "Coupe", "MPV", "Convertible", "Pick Up", "Other"]
    var car: Dictionary<String, String> = [:]
    var userInfo: [String: String] = [:]
    var dob: Date = Date()
    
    var captureSession: AVCaptureSession? = nil
    var stillImageOutput: AVCapturePhotoOutput? = nil
    var videoPreviewLayer: AVCaptureVideoPreviewLayer? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.view.backgroundColor = rideRed
        self.navigationController?.navigationBar.tintColor = UIColor.white
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
        self.navigationController?.navigationBar.isTranslucent = true
        
        if skip {
            self.performSegue(withIdentifier: "show2", sender: self)
        }
        
        if page1No != nil {
            page1No.layer.borderWidth = 1
            page1No.layer.borderColor = UIColor.white.cgColor
        }
        
        if mpgTextField != nil {
            mpgTextField.layer.borderWidth = 1
            mpgTextField.layer.borderColor = UIColor.white.cgColor
            
            let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(SettingsTableViewController.dismissKeyboard))
            
            view.addGestureRecognizer(tap)
        }
        
        if noOfSeatsTextField != nil {
            noOfSeatsTextField.layer.borderWidth = 1
            noOfSeatsTextField.layer.borderColor = UIColor.white.cgColor
            
            let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(SettingsTableViewController.dismissKeyboard))
            
            view.addGestureRecognizer(tap)
        }
        
        if carTypeTextField != nil {
//          WelcomeController()
            carTypeTextField.layer.borderWidth = 1
            carTypeTextField.layer.borderColor = UIColor.white.cgColor
            
            createPickerView()
            createToolbar(textfield: carTypeTextField)
        }
        
        if numberPlateTextField != nil {
            numberPlateTextField.layer.borderWidth = 1
            numberPlateTextField.layer.borderColor = UIColor.white.cgColor
            
            let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(SettingsTableViewController.dismissKeyboard))
            view.addGestureRecognizer(tap)
        }
        
        // Page 6
        if dobTextField != nil {
            dobTextField.layer.borderWidth = 1
            dobTextField.layer.borderColor = UIColor.white.cgColor
            
            let datePicker = UIDatePicker()
            datePicker.locale = Locale(identifier: "GB")
            datePicker.datePickerMode = UIDatePicker.Mode.date
            datePicker.maximumDate = Calendar.current.date(byAdding: .year, value: -16, to: Date())
            datePicker.addTarget(self, action: #selector(SetupViewController.datePickerValueChanged(sender:)), for: UIControl.Event.valueChanged)
            dobTextField.inputView = datePicker
            createToolbar(textfield: dobTextField)
            
            scrollView.contentSize = CGSize(width: scrollView.frame.width, height: self.view.frame.height)
            
            addressL1TextField.layer.borderWidth = 1
            addressL1TextField.layer.borderColor = UIColor.white.cgColor
            
            addressL2TextField.layer.borderWidth = 1
            addressL2TextField.layer.borderColor = UIColor.white.cgColor
            
            cityTextField.layer.borderWidth = 1
            cityTextField.layer.borderColor = UIColor.white.cgColor
            
            countyTextField.layer.borderWidth = 1
            countyTextField.layer.borderColor = UIColor.white.cgColor
            
            postcodeTextField.layer.borderWidth = 1
            postcodeTextField.layer.borderColor = UIColor.white.cgColor
            
            let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(SettingsTableViewController.dismissKeyboard))
            view.addGestureRecognizer(tap)
        }
        
        if sortCodeTextField != nil {
            sortCodeTextField.layer.borderWidth = 1
            sortCodeTextField.layer.borderColor = UIColor.white.cgColor
            
            sortCodeTextField.delegate = self
            accountNumberTextField.delegate = self
//            sortCodeTextField.addTarget(self, action: #selector(didChangeText(textField:)), for: .editingChanged)
            
            accountNumberTextField.layer.borderWidth = 1
            accountNumberTextField.layer.borderColor = UIColor.white.cgColor
            
            let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(SettingsTableViewController.dismissKeyboard))
            view.addGestureRecognizer(tap)
        }
        
        if cameraView != nil {
            self.imageView.layer.masksToBounds = true
            self.imageView.layer.cornerRadius = 10.0
            
            self.cameraView.layer.masksToBounds = true
            self.cameraView.layer.cornerRadius = 10.0
            
            captureSession = AVCaptureSession()
            captureSession!.sessionPreset = .medium
            
            guard let backCamera = AVCaptureDevice.default(for: AVMediaType.video) else {
                    print("Unable to access back camera!")
                    return
            }
            
            do {
                let input = try AVCaptureDeviceInput(device: backCamera)
                
                stillImageOutput = AVCapturePhotoOutput()
                
                if captureSession!.canAddInput(input) && captureSession!.canAddOutput(stillImageOutput!) {
                    captureSession!.addInput(input)
                    captureSession!.addOutput(stillImageOutput!)
                    setupLivePreview()
                }
            }
            catch let error  {
                print("Error Unable to initialize back camera:  \(error.localizedDescription)")
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if self.captureSession != nil {
            self.captureSession!.stopRunning()
        }
    }
    
    // MARK - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        print("Preparing to segue: \(String(describing: segue.identifier))")
        
        switch(segue.identifier ?? "") {
        case "showStripeAgreement":
            let navVC = segue.destination as? UINavigationController
            let legalViewController = navVC?.viewControllers.first as! LegalViewController
            legalViewController.url = URL(string: "https://stripe.com/gb/connect-account/legal")
            os_log("Showing settings", log: OSLog.default, type: .debug)
        default:
            if noOfSeatsTextField == nil && page1No == nil {
                let destinationVC = segue.destination as! SetupViewController
                destinationVC.car = self.car
            }
            
            if segue.identifier == "show7" {
                let destinationVC = segue.destination as! SetupViewController
                destinationVC.userInfo = self.userInfo
            }
            
            if segue.identifier == "show8" {
                let destinationVC = segue.destination as! SetupViewController
                destinationVC.userInfo = self.userInfo
            }
        }
    }
    
    
    // MARK: - Picker View
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return carTypes.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return carTypes[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedType = carTypes[row]
        
        carTypeTextField.text = selectedType
        car["type"] = selectedType
    }
    
    func createPickerView() {
        let pickerView = UIPickerView()
        pickerView.delegate = self
        
        carTypeTextField.inputView = pickerView
    }
    
    func createToolbar(textfield: UITextField) {
        let toolBar = UIToolbar()
        toolBar.sizeToFit()
        
        let flexibleButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil)
        var doneButton: UIBarButtonItem
        doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(SetupViewController.dismissKeyboard))
        toolBar.setItems([flexibleButton, doneButton], animated: false)
        toolBar.isUserInteractionEnabled = true
        
        textfield.inputAccessoryView = toolBar
    }
    
    @objc func datePickerValueChanged(sender: UIDatePicker) {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        dobTextField.text = formatter.string(from: sender.date)
        self.dob = sender.date
    }
    
    // MARK: - Actions
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @IBAction func page1NoPressed(_ sender: Any) {
        RideDB?.child("Users").child((currentUser?.uid)!).child("car").child("mpg").setValue("nil")
        RideDB?.child("Users").child((currentUser?.uid)!).child("car").child("seats").setValue("nil")
        RideDB?.child("Users").child((currentUser?.uid)!).child("car").child("registration").setValue("nil")
        self.dismiss(animated: true) {
            self.welcomeTableViewController?.walkthrough()
        }
    }
    
    @IBAction func page2Next(_ sender: Any) {
        if carTypeTextField.text != "" {
            performSegue(withIdentifier: "show3", sender: nil)
        }
    }
    
    @IBAction func page3Next(_ sender: Any) {
        if numberPlateTextField.text != "" {
            car["registration"] = numberPlateTextField.text
            performSegue(withIdentifier: "show4", sender: nil)
        }
    }
    
    @IBAction func page4Next(_ sender: Any) {
        if mpgTextField.text != "" {
            car["mpg"] = mpgTextField.text
            performSegue(withIdentifier: "show5", sender: nil)
        }
    }
    
    @IBAction func page5Next(_ sender: Any) {
        if noOfSeatsTextField.text != "" {
            car["seats"] = noOfSeatsTextField.text
            
            if RideDB != nil {
                RideDB?.child("Users").child((currentUser?.uid)!).child("car").setValue(car)
                
                performSegue(withIdentifier: "show6", sender: nil)
            }
        }
    }
    
    func getWiFiAddress() -> String? {
        var address : String?
        
        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }
        
        // For each interface ...
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            
            // Check for IPv4 or IPv6 interface:
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                
                // Check interface name:
                let name = String(cString: interface.ifa_name)
                if  name == "en0" {
                    
                    // Convert interface address to a human readable string:
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        freeifaddrs(ifaddr)
        
        return address
    }
    
    @IBAction func page6Next(_ sender: Any) {
        if dobTextField.text != "" && addressL1TextField.text != "" && cityTextField.text != "" && countyTextField.text != "" && postcodeTextField.text != "" {
            var name = mainUser?._userName.split(separator: " ").map({ (substring) in
                return String(substring)
            })
            let first = name?.first
            name!.remove(at: 0)
            let last = name!.joined(separator: " ")
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd"
            let day = dateFormatter.string(from: self.dob)
            dateFormatter.dateFormat = "MM"
            let month = dateFormatter.string(from: self.dob)
            dateFormatter.dateFormat = "yyyy"
            let year = dateFormatter.string(from: self.dob)
            
            self.userInfo = [
                "first_name": first! as String,
                "last_name": last as String,
                "dob_day": day,
                "dob_month": month,
                "dob_year": year,
                "address_line1": self.addressL1TextField.text! as String,
                "address_line2": self.addressL2TextField.text! as String,
                "address_city": self.cityTextField.text! as String,
                "address_state": self.countyTextField.text! as String,
                "address_postcode": self.postcodeTextField.text! as String,
                "ip": getWiFiAddress() ?? "0.0.0.0"
            ]
            
            performSegue(withIdentifier: "show7", sender: nil)
        }
    }
    
    @IBAction func insertDashes(_ sender: Any) {
        let text = self.sortCodeTextField.text!.replacingOccurrences(of: "-", with: "")
        if text.count > 1 && text.count % 2 == 0 && text.count < 6 {
            sortCodeTextField.text = sortCodeTextField.text! + "-"
        }
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard textField.text != nil else { return true }
        
        let count = textField.text!.count + string.count - range.length
        return count <= 8
    }
    
    @IBAction func page7Next(_ sender: Any) {
        if self.userInfo.count != 0 && sortCodeTextField.text != "" && accountNumberTextField.text != "" {
            if self.sortCodeTextField.text?.count != 8 || self.accountNumberTextField.text?.count != 8 {
                let alert = UIAlertController(title: "Check your details", message: "Please check your sort code or account number is correct", preferredStyle: .alert)
                
                self.present(alert, animated: true)
            } else {
                self.userInfo["sort_code"] = self.sortCodeTextField.text
                self.userInfo["account_number"] = self.accountNumberTextField.text
                
                performSegue(withIdentifier: "show8", sender: nil)
            }
        }
    }
    
    func setupLivePreview() {
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
        
        videoPreviewLayer!.videoGravity = .resizeAspectFill
        videoPreviewLayer?.connection?.videoOrientation = .portrait
        self.cameraView.layer.addSublayer(videoPreviewLayer!)
        
        //Step12
        
        DispatchQueue.global(qos: .userInitiated).async { //[weak self] in
            self.captureSession!.startRunning()
            
            DispatchQueue.main.async {
                self.videoPreviewLayer!.frame = self.cameraView.bounds
            }
        }
    }
    
    @IBAction func takePhoto(_ sender: Any) {
        if cameraShutter.currentTitle == "Take Photo" {
            let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            stillImageOutput!.capturePhoto(with: settings, delegate: self)
            cameraShutter.setTitle("Take New Photo", for: .normal)
        } else {
            imageView.isHidden = true
            cameraShutter.setTitle("Take Photo", for: .normal)
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation()
            else { return }
        
        let image = UIImage(data: imageData)
        imageView.image = cropToBounds(image: image!, width: Double(imageView.frame.width), height: Double(imageView.frame.height))
        imageView.contentMode = UIView.ContentMode.scaleAspectFill
        imageView.isHidden = false
    }
    
    func cropToBounds(image: UIImage, width: Double, height: Double) -> UIImage {
        let cgimage = image.cgImage!
        let contextImage: UIImage = UIImage(cgImage: cgimage)
        let contextSize: CGSize = contextImage.size
        var posX: CGFloat = 0.0
        var posY: CGFloat = 0.0
        var cgwidth: CGFloat = CGFloat(width)
        var cgheight: CGFloat = CGFloat(height)
        
        // See what size is longer and create the center off of that
        if contextSize.width > contextSize.height {
            posX = ((contextSize.width - contextSize.height) / 2)
            posY = 0
            cgwidth = contextSize.height
            cgheight = contextSize.height
        } else {
            posX = 0
            posY = ((contextSize.height - contextSize.width) / 2)
            cgwidth = contextSize.width
            cgheight = contextSize.width
        }
        
        let rect: CGRect = CGRect(x: posX, y: posY, width: cgwidth, height: cgheight)
        
        // Create bitmap image from context using the rect
        let imageRef: CGImage = cgimage.cropping(to: rect)!
        
        // Create a new image based on the imageRef and rotate back to the original orientation
        let image: UIImage = UIImage(cgImage: imageRef, scale: image.scale, orientation: image.imageOrientation)
        
        return image
    }
    
    @IBAction func page8Done(_ sender: Any) {
        guard self.imageView.image != nil else {
            return
        }
        
        self.showSpinner(onView: self.view)
        
        RideDB?.child("stripe_customers").child(mainUser!._userID).child("account").setValue(["id": currentUser?.uid, "email": currentUser?.email])
        
        RideDB?.child("stripe_customers").child(mainUser!._userID).child("account_id").observe(.value, with: {snapshot in
            if let value = snapshot.value as? String {
                self.upload(image: self.imageView.image!, customerID: value)
            }
        })
    }
    
    func upload(image: UIImage, customerID: String) {
        guard let imageData = image.jpegData(compressionQuality: 0.5) else {
            print("Could not get JPEG representation of UIImage")
            return
        }
        
        let parameters = ["purpose": "identity_document"]
        
        Alamofire.upload(multipartFormData: { multipartFormData in
            multipartFormData.append(imageData, withName: "file",fileName: "file.jpg", mimeType: "image/jpg")
            for (key, value) in parameters {
                multipartFormData.append(value.data(using: String.Encoding.utf8)!, withName: key)
            }
        }, to:"https://uploads.stripe.com/v1/files", headers: ["Authorization": "Bearer \(secretKey)", "Stripe-Account": customerID]) { (result) in
            switch result {
            case .success(let upload, _, _):
                upload.responseJSON { response in
                    if let json = response.result.value as? [String: Any] {
                        self.userInfo["identity_document"] = (json["id"] as! String)
                        self.userInfo["id"] = mainUser!._userID
                        RideDB?.child("stripe_customers").child(mainUser!._userID).child("account").setValue(self.userInfo)
                        
                        let alert = UIAlertController(title: "Success", message: "Your license has been uploaded and will be verified. While verification is taking place, you are free to use Ride normally. Enjoy!", preferredStyle: .alert)
                        
                        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { (action: UIAlertAction) in
                            self.dismiss(animated: true, completion: nil)
                        }))
                        
                        self.removeSpinner()
                        self.present(alert, animated: true)
                    }
                }
                
            case .failure(let encodingError):
                os_log("Error: @", log: OSLog.default, type: .error, encodingError.localizedDescription)
                
                let alert = UIAlertController(title: "Error", message: "An error has occured. Please try again.", preferredStyle: .alert)
                
                alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { (action: UIAlertAction) in
                    self.removeSpinner()
                }))
                
                self.present(alert, animated: true)
            }
        }
    }
    
    func generateBoundaryString() -> String {
        return "Boundary-\(NSUUID().uuidString)"
    }
    
    private func moveToNextController() {
        var identifier: String = self.restorationIdentifier!
        identifier = String(identifier.last!)
        let nextIdentifier: String = "setupPage" + String(Int(identifier)! + 1)
        let mainStoryBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let loginViewController: UIViewController = mainStoryBoard.instantiateViewController(withIdentifier: nextIdentifier)
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let currentViewController = appDelegate.window?.rootViewController
        appDelegate.window?.rootViewController = loginViewController
        currentViewController?.present(loginViewController, animated: true, completion: nil)
    }
 
    func registerForPushNotifications() {
        UNUserNotificationCenter.current() // 1
            .requestAuthorization(options: [.alert, .sound, .badge]) { // 2
                granted, error in
                print("Permission granted: \(granted)") // 3
        }
    }
}

extension SetupViewController: STPAddCardViewControllerDelegate {
    
    func addCardViewControllerDidCancel(_ addCardViewController: STPAddCardViewController) {
        navigationController?.popViewController(animated: true)
    }
    
    func addCardViewController(_ addCardViewController: STPAddCardViewController, didCreateToken token: STPToken, completion: @escaping STPErrorBlock) {
       
        let cardRef = RideDB?.child("stripe_customers").child(mainUser!._userID).child("sources").childByAutoId()
        
        cardRef?.child("token").setValue(token.tokenId) { (error, ref) -> Void in
            if let error = error {
                completion(error)
            } else {
                
                RideDB?.child("stripe_customers").child(mainUser!._userID).child("sources").child(cardRef!.key!).observe(.value, with: { (snapshot) in
                    if snapshot.hasChild("error") {
                        if let value = snapshot.value as? [String: String] {
                            let alert = UIAlertController(title: "Error", message: value["error"], preferredStyle: .alert)

                            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { (action: UIAlertAction) in
                                self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
                                self.navigationController?.navigationBar.shadowImage = UIImage()
                                self.navigationController?.navigationBar.isTranslucent = true
                                self.navigationController?.view.backgroundColor = .clear
                                self.navigationController?.popViewController(animated: true)
                            }))

                            self.present(alert, animated: true)
                        }
                    } else if snapshot.hasChild("id") {
                        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
                        self.navigationController?.navigationBar.shadowImage = UIImage()
                        self.navigationController?.navigationBar.isTranslucent = true
                        self.navigationController?.view.backgroundColor = .clear
                        
//                        print(snapshot.value as! [String: String])
                        
                        if let value = snapshot.value as? [String: Any] {
                            self.addCardButton.setTitle("**** **** **** " + (value["last4"] as! String), for: .normal)
                            self.addCardButton.titleLabel?.font = UIFont(name: (self.addCardButton.titleLabel?.font.fontName)!, size: 16)
                            self.addCardButton.isEnabled = false
                        }
                        
                        self.navigationController?.popViewController(animated: true)
                    }
                })
                
                
            }
        }
    }
}
