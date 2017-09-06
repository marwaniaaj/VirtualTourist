//
//  FlickrConstants.swift
//  VirtualTourist
//
//  Created by Marwa Abou Niaaj on 5/22/17.
//  Copyright © 2017 Marwa Abou Niaaj. All rights reserved.
//

import Foundation

extension Flickr {
    
    // MARK: API
    struct API {
        static let Scheme = "https"
        static let Host = "api.flickr.com"
        static let Path = "/services/rest"
    }
    
    // MARK: Search
    struct Search {
        static let BBoxHalfWidth = 1.0
        static let BBoxHalfHeight = 1.0
        static let LatRange = (-90.0, 90.0)
        static let LonRange = (-180.0, 180.0)
    }
    
    struct Parameter {
        
        // MARK: Parameter Keys
        struct Keys {
            static let Method = "method"
            static let APIKey = "api_key"
            static let Extras = "extras"
            static let Format = "format"
            static let NoJSONCallback = "nojsoncallback"
            static let SafeSearch = "safe_search"
            static let Text = "text"
            static let BoundingBox = "bbox"
            static let Page = "page"
            static let PerPage = "per_page"
        }
        
        // MARK: Parameter Values
        struct Values {
            static let SearchMethod = "flickr.photos.search"
            static let APIKey = "47b88b8c618543e6058ab16bb3a15d3f"
            static let ResponseFormat = "json"
            static let DisableJSONCallback = "1" /* 1 means "yes" */
            static let GalleryPhotosMethod = "flickr.galleries.getPhotos"
            static let MediumURL = "url_m"
            static let UseSafeSearch = "1"
            static let PageLimit = "21"
        }
    }
    
    struct Response {
        
        // MARK: Response Keys
        struct Keys {
            static let Status = "stat"
            static let Photos = "photos"
            static let Photo = "photo"
            static let Title = "title"
            static let MediumURL = "url_m"
            static let Pages = "pages"
            static let Total = "total"
        }
        
        // MARK: Response Values
        struct Values {
            static let OKStatus = "ok"
        }
    }
    
    
}
