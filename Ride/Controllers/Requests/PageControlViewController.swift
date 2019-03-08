//
//  PageControlViewController.swift
//  Ride
//
//  Created by Ben Mechen on 26/01/2019.
//  Copyright © 2019 Fuse Apps. All rights reserved.
//

import UIKit

class PageControlViewController: UIViewController {

    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var pageControl: UIPageControl!
    
    var request: Request? = nil
    var userName: String? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
        self.navigationController?.navigationBar.isTranslucent = true
        self.navigationController?.view.backgroundColor = .clear
        
        self.view.backgroundColor = UIColor(red:0.70, green:0.01, blue:0.11, alpha:1.0)
        
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
        if let receivedRequestsPageViewController = segue.destination as? ReceivedRequestsPageViewController {
            receivedRequestsPageViewController.pageControlDelegate = self
            receivedRequestsPageViewController.request = self.request!
            receivedRequestsPageViewController.userName = self.userName
        }
        
        if let sentRequestsPageViewController = segue.destination as? SentRequestsPageViewController {
            sentRequestsPageViewController.pageControlDelegate = self
            sentRequestsPageViewController.request = self.request
            sentRequestsPageViewController.userName = self.userName
        }
    }
}

extension PageControlViewController: ReceivedRequestsPageViewControllerDelegate, SentRequestsPageViewControllerDelegate {
    func receivedRequestsPageViewController(receivedRequestsPageViewController: ReceivedRequestsPageViewController, didUpdatePageCount count: Int) {
        pageControl.numberOfPages = count
    }
    
    func receivedRequestsPageViewController(receivedRequestsPageViewController: ReceivedRequestsPageViewController, didUpdatePageIndex index: Int) {
        pageControl.currentPage = index
    }
    
    func sentRequestsPageViewController(sentRequestsPageViewController: SentRequestsPageViewController, didUpdatePageCount count: Int) {
        pageControl.numberOfPages = count
    }
    
    func sentRequestsPageViewController(sentRequestsPageViewController: SentRequestsPageViewController, didUpdatePageIndex index: Int) {
        pageControl.currentPage = index
    }
}
