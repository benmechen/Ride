//
//  UIImage+JPEGQuality.swift
//  Ride
//
//  Created by Ben Mechen on 10/09/2018.
//  Copyright © 2018 Fuse Apps. All rights reserved.
//

import Foundation
import UIKit

extension UIImage {
    enum JPEGQuality: CGFloat {
        case lowest  = 0
        case low     = 0.25
        case medium  = 0.5
        case high    = 0.75
        case highest = 1
    }
    
    /// Returns the data for the specified image in JPEG format.
    /// If the image object’s underlying image data has been purged, calling this function forces that data to be reloaded into memory.
    /// - returns: A data object containing the JPEG data, or nil if there was a problem generating the data. This function may return nil if the image has no data or if the underlying CGImageRef contains data in an unsupported bitmap format.
    func jpeg(_ quality: JPEGQuality) -> Data? {
//        return UIImageJPEGRepresentation(self, quality.rawValue)
        return jpegData(compressionQuality: quality.rawValue)
    }
    
    private func cropToBounds(image: UIImage, width: Double, height: Double) -> UIImage {
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
    
    func resize(width: CGFloat) -> UIImage {
        var newImage = self.cropToBounds(image: self, width: Double(self.size.width), height: Double(self.size.height))
        let scale = width / self.size.width
        let newHeight = self.size.height * scale
        
        if self.size.height <= self.size.width {
            newImage = self.cropToBounds(image: self, width: Double(self.size.width), height: Double(self.size.height))
        }
        
        UIGraphicsBeginImageContext(CGSize(width: width, height: newHeight))
        newImage.draw(in: CGRect(x: 0, y: 0, width: width, height: newHeight))
        newImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
}
