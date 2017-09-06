//
//  Photo.swift
//  VirtualTourist
//
//  Created by Marwa Abou Niaaj on 5/25/17.
//  Copyright © 2017 Marwa Abou Niaaj. All rights reserved.
//

import Foundation
import CoreData

@objc(Photo)
public class Photo: NSManagedObject {

    convenience init(imageData: NSData, context: NSManagedObjectContext) {
        
        let ent = NSEntityDescription.entity(forEntityName: "Photo", in: context)
        self.init(entity: ent!, insertInto: context)
        self.imageData = imageData
    }
}
