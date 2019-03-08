//
//  ReceivedRequestsPageViewController.swift
//  Ride
//
//  Created by Ben Mechen on 25/01/2019.
//  Copyright © 2019 Fuse Apps. All rights reserved.
//

import UIKit

class ReceivedRequestsPageViewController: UIPageViewController {
    
    var request: Request? = nil
    var userName: String? = nil
    
    fileprivate lazy var pages: [UIViewController] = {
        return [
            self.getViewController(withIdentifier: "ReceivedRequestController"),
            self.getViewController(withIdentifier: "ReceivedMessagesController")
        ]
    }()
    
    fileprivate func getViewController(withIdentifier identifier: String) -> UIViewController
    {
        if identifier == "ReceivedMessagesController" {
            let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: identifier) as! RequestsChatViewController
            
            viewController.request = self.request
            viewController.userName = self.userName
            
            return viewController
        }
        
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: identifier)
        
        return viewController
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.white
        
        self.dataSource = self
        self.delegate = self
        
        if let firstVC = pages.first {
            setViewControllers([firstVC], direction: .forward, animated: true, completion: nil)
        }
    }
}

extension ReceivedRequestsPageViewController: UIPageViewControllerDataSource {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        
        guard let viewControllerIndex = pages.index(of: viewController) else { return nil }
        
        let previousIndex = viewControllerIndex - 1
        
        guard previousIndex >= 0          else { return nil }
        
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
}

extension ReceivedRequestsPageViewController: UIPageViewControllerDelegate { }

