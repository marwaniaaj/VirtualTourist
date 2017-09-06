//
//  PhotoProperties.swift
//  VirtualTourist
//
//  Created by Marwa Abou Niaaj on 5/25/17.
//  Copyright © 2017 Marwa Abou Niaaj. All rights reserved.
//

import Foundation
import CoreData


extension Photo {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Photo> {
        return NSFetchRequest<Photo>(entityName: "Photo")
    }

    @NSManaged public var imageData: NSData?
    @NSManaged public var pin: Pin?

}
