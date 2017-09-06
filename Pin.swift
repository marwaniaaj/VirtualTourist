//
//  Pin.swift
//  VirtualTourist
//
//  Created by Marwa Abou Niaaj on 5/25/17.
//  Copyright © 2017 Marwa Abou Niaaj. All rights reserved.
//

import Foundation
import CoreData

@objc(Pin)
public class Pin: NSManagedObject {

    convenience init(latitude: Double, longitude: Double, pageNumber: Int16?, context: NSManagedObjectContext) {
        
        let ent = NSEntityDescription.entity(forEntityName: "Pin", in: context)
        self.init(entity: ent!, insertInto: context)
        self.latitude = latitude
        self.longitude = longitude
        self.pageNumber = pageNumber != nil ? pageNumber! : 1
    }
}
