//
//  SentRequestsPageViewController.swift
//  Ride
//
//  Created by Ben Mechen on 25/01/2019.
//  Copyright © 2019 Fuse Apps. All rights reserved.
//

import UIKit
import Crashlytics


protocol SentRequestsPageViewControllerDelegate: class {
    func sentRequestsPageViewController(sentRequestsPageViewController: SentRequestsPageViewController, didUpdatePageCount count: Int)
    
    func sentRequestsPageViewController(sentRequestsPageViewController: SentRequestsPageViewController, didUpdatePageIndex index: Int)
}

class SentRequestsPageViewController: UIPageViewController {
    
    weak var pageControlDelegate: SentRequestsPageViewControllerDelegate?
    
    var request: Request? = nil
    var userName: String? = nil
    
    fileprivate lazy var pages: [UIViewController] = {
        return [
            self.getViewController(withIdentifier: "SentRequestController_Page"),
            self.getViewController(withIdentifier: "SentMessagesController")
        ]
    }()
    
    fileprivate func getViewController(withIdentifier identifier: String) -> UIViewController {
        if identifier == "SentMessagesController" {
            let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: identifier) as! RequestsChatViewController
            
            viewController.request = self.request
            viewController.userName = self.userName
            
            return viewController
        }
        if identifier == "SentRequestController_Page" {
            var newIdentifier = "SentRequestController_Page1"
            
            if self.request!.deleted {
                newIdentifier = "SentRequestController_Page2"
            } else if self.request?.status == 1 {
                newIdentifier = "SentRequestController_Page3"
            } else if self.request?.status == 2 || self.request?.status == 3 || self.request?.status == 4 {
                newIdentifier = "SentRequestController_Page4"
            }
            
            let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: newIdentifier) as! SentRequestViewController
            
            viewController.request = self.request
            viewController.userName = self.userName
            
            return viewController
        }
        
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: identifier)
        
        return viewController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        self.view.backgroundColor = UIColor.white
        self.view.backgroundColor = UIColor(red:0.70, green:0.01, blue:0.11, alpha:1.0)
        
        self.dataSource = self
        self.delegate = self
        
        self.pageControlDelegate?.sentRequestsPageViewController(sentRequestsPageViewController: self, didUpdatePageCount: pages.count)
        
        if let firstVC = pages.first {
            setViewControllers([firstVC], direction: .forward, animated: true, completion: nil)
        }
        
        let pageControl: UIPageControl = UIPageControl.appearance()
        pageControl.currentPageIndicatorTintColor = rideClickableRed
        pageControl.pageIndicatorTintColor = UIColor.init(red: 0, green: 0, blue: 0, alpha: 0.2)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        print("Setting nav to default")
        self.navigationController?.navigationBar.setBackgroundImage(nil, for: .default)
        self.navigationController?.navigationBar.shadowImage = nil
        self.navigationController?.navigationBar.isTranslucent = true
        self.navigationController?.view.backgroundColor = rideRed
    }
}

extension SentRequestsPageViewController: UIPageViewControllerDataSource {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        
        guard let viewControllerIndex = pages.index(of: viewController) else { return nil }
        
        let previousIndex = viewControllerIndex - 1
        
        guard previousIndex >= 0          else { return nil }
        
        guard pages.count > previousIndex else { return nil }
        
        return pages[previousIndex]
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let viewControllerIndex = pages.index(of: viewController) else { return nil }
        
        let nextIndex = viewControllerIndex + 1
        
        guard nextIndex < pages.count else { return nil }
        
        guard pages.count > nextIndex else { return nil }
        
        return pages[nextIndex]
    }
    
//    func presentationCount(for pageViewController: UIPageViewController) -> Int {
//        return pages.count
//    }
//    
//    func presentationIndex(for pageViewController: UIPageViewController) -> Int {
//        return 0
//    }
}

extension SentRequestsPageViewController: UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if let firstViewController = viewControllers?.first, let index = pages.index(of: firstViewController) {
            pageControlDelegate?.sentRequestsPageViewController(sentRequestsPageViewController: self, didUpdatePageIndex: index)
            if firstViewController is RequestsChatViewController {
                print("Setting nav to default")
                self.navigationController?.navigationBar.setBackgroundImage(nil, for: .default)
                self.navigationController?.navigationBar.shadowImage = nil
                self.navigationController?.navigationBar.isTranslucent = true
                self.navigationController?.view.backgroundColor = rideRed
            } else {
                print("Setting nav to clear")
                self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
                self.navigationController?.navigationBar.shadowImage = UIImage()
                self.navigationController?.navigationBar.isTranslucent = true
                self.navigationController?.view.backgroundColor = .clear
            }
        }
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        if let firstViewController = viewControllers?.first, let _ = pages.index(of: firstViewController) {
            if firstViewController is RequestsChatViewController {
                print("Setting nav to clear")
                self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
                self.navigationController?.navigationBar.shadowImage = UIImage()
                self.navigationController?.navigationBar.isTranslucent = true
                self.navigationController?.view.backgroundColor = .clear
            } else {
                print("Setting nav to default")
                self.navigationController?.navigationBar.setBackgroundImage(nil, for: .default)
                self.navigationController?.navigationBar.shadowImage = nil
                self.navigationController?.navigationBar.isTranslucent = true
                self.navigationController?.view.backgroundColor = rideRed
            }
        }
    }
}

