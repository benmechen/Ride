//
//  LegalViewController.swift
//  Ride
//
//  Created by Ben Mechen on 03/03/2019.
//  Copyright © 2019 Fuse Apps. All rights reserved.
//

import UIKit
import WebKit

class LegalViewController: UIViewController, WKNavigationDelegate {

    @IBOutlet weak var webView: WKWebView!
    
    var url = URL(string: "https://fuse-ride.firebaseapp.com/terms/tcs.html")
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        webView.navigationDelegate = self
        
        let request = URLRequest(url: url!)
        webView.load(request)
    }

    // MARK: - Web View
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let host = navigationAction.request.url?.host {
            if host == "fuse-ride.firebaseapp.com" || host == "stripe.com" {
                decisionHandler(.allow)
                return
            }
        }
        
        decisionHandler(.cancel)
    }

    // MARK: - Navigation
    @IBAction func close(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}
