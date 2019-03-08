//
//  ReceivedRequestsPageViewController.swift
//  Ride
//
//  Created by Ben Mechen on 25/01/2019.
//  Copyright © 2019 Fuse Apps. All rights reserved.
//

import UIKit
import Crashlytics

protocol ReceivedRequestsPageViewControllerDelegate: class {
    func receivedRequestsPageViewController(receivedRequestsPageViewController: ReceivedRequestsPageViewController, didUpdatePageCount count: Int)
    
    func receivedRequestsPageViewController(receivedRequestsPageViewController: ReceivedRequestsPageViewController, didUpdatePageIndex index: Int)
}

class ReceivedRequestsPageViewController: UIPageViewController {
    
    weak var pageControlDelegate: ReceivedRequestsPageViewControllerDelegate?
    
    var request: Request? = nil
    var userName: String? = nil
    var member: Member!
    
    fileprivate lazy var pages: [UIViewController] = {
        return [
            self.getViewController(withIdentifier: "ReceivedRequestController"),
            self.getViewController(withIdentifier: "ReceivedMessagesController")
        ]
    }()
    
    fileprivate func getViewController(withIdentifier identifier: String) -> UIViewController {
        if identifier == "ReceivedMessagesController" {
            let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: identifier) as! RequestsChatViewController
            
            viewController.request = self.request
            viewController.userName = self.userName
            
            return viewController
        }
        
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: identifier)
        
        return viewController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.white
        
        self.dataSource = self
        self.delegate = self
        
        self.pageControlDelegate?.receivedRequestsPageViewController(receivedRequestsPageViewController: self, didUpdatePageCount: pages.count)
        
        if let firstVC = pages.first {
            setViewControllers([firstVC], direction: .forward, animated: true, completion: nil)
        }
        
        let pageControl: UIPageControl = UIPageControl.appearance()
        pageControl.currentPageIndicatorTintColor = rideClickableRed
        pageControl.pageIndicatorTintColor = UIColor.init(red: 0, green: 0, blue: 0, alpha: 0.2)
    }
    
//    override func viewWillAppear(_ animated: Bool) {
//        super.viewWillAppear(animated)
//        
//        self.becomeFirstResponder()
//    }
}

extension ReceivedRequestsPageViewController: UIPageViewControllerDataSource {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        
        guard let viewControllerIndex = pages.index(of: viewController) else { return nil }
        
        let previousIndex = viewControllerIndex - 1
        
        guard previousIndex >= 0 else { return nil }
        
        guard pages.count > previousIndex else { return nil }
        
        return pages[previousIndex]
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController?
    {
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
    
//    func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
//
//        pendingViewControllers.first?.becomeFirstResponder()
//    }
}

extension ReceivedRequestsPageViewController: UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if let firstViewController = viewControllers?.first, let index = pages.index(of: firstViewController) {
            pageControlDelegate?.receivedRequestsPageViewController(receivedRequestsPageViewController: self, didUpdatePageIndex: index)
        }
        
//        pageViewController.viewControllers?.last?.becomeFirstResponder()
    }
}
