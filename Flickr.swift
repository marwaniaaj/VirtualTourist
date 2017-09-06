//
//  Flickr.swift
//  VirtualTourist
//
//  Created by Marwa Abou Niaaj on 5/22/17.
//  Copyright © 2017 Marwa Abou Niaaj. All rights reserved.
//

import Foundation

class Flickr {
    
    // Shared session
    var session = URLSession.shared
    
    var imagesPageNumber = 1
    
    // MARK: Shared Instance
    class func sharedInstance() -> Flickr {
        struct Singleton {
            static var sharedInstance = Flickr()
        }
        return Singleton.sharedInstance
    }
    
    
    // MARK: Helper for Creating a URL from Parameters
    private func flickrURLFromParameters(_ parameters: [String: AnyObject]) -> URL {
        
        var components = URLComponents()
        components.scheme = Flickr.API.Scheme
        components.host = Flickr.API.Host
        components.path = Flickr.API.Path
        components.queryItems = [URLQueryItem]()
        
        for (key, value) in parameters {
            let queryItem = URLQueryItem(name: key, value: "\(value)")
            components.queryItems!.append(queryItem)
        }
        //print(components.url!)
        return components.url!
    }
    
    private func boundingBoxString(_ latitude: Double?, _ longitude: Double?) -> String {
        
        if let latitude = latitude, let longitude = longitude {
            
            let minLongitude = max(longitude - Flickr.Search.BBoxHalfWidth, Flickr.Search.LonRange.0)
            let maxLongitude = min(longitude + Flickr.Search.BBoxHalfWidth, Flickr.Search.LonRange.1)
            
            let minLatitude = max(latitude - Flickr.Search.BBoxHalfHeight, Flickr.Search.LatRange.0)
            let maxLatitude = min(latitude + Flickr.Search.BBoxHalfHeight, Flickr.Search.LatRange.1)
            
            return "\(minLongitude),\(minLatitude),\(maxLongitude),\(maxLatitude)"
        } else {
            return "0,0,0,0"
        }
        
    }
    
    func downloadFlickrImages(_ latitude: Double, _ longitude: Double, _ pageNumber: Int, completionHandler: @escaping (_ result: [[String:AnyObject]]?, _ error: NSError?) -> Void) {
        
        /* 1. Set the parameters */
        let methodParameter = [
            Flickr.Parameter.Keys.APIKey : Flickr.Parameter.Values.APIKey,
            Flickr.Parameter.Keys.Method : Flickr.Parameter.Values.SearchMethod,
            Flickr.Parameter.Keys.Format : Flickr.Parameter.Values.ResponseFormat,
            Flickr.Parameter.Keys.Extras : Flickr.Parameter.Values.MediumURL,
            Flickr.Parameter.Keys.SafeSearch : Flickr.Parameter.Values.UseSafeSearch,
            Flickr.Parameter.Keys.NoJSONCallback : Flickr.Parameter.Values.DisableJSONCallback,
            Flickr.Parameter.Keys.Page : pageNumber,
            Flickr.Parameter.Keys.PerPage : Flickr.Parameter.Values.PageLimit,
            Flickr.Parameter.Keys.BoundingBox : boundingBoxString(latitude, longitude)
        ] as [String : AnyObject]
        
        /* 2/3. Build the URL, Configure the request */
        let request = URLRequest(url: flickrURLFromParameters(methodParameter as [String : AnyObject]))
        
        /* 4. Make the request */
        let task = session.dataTask(with: request) { (data, response, error) in
            
            /* GUARD: Was there an error? */
            guard (error == nil) else {
                completionHandler(nil, NSError(domain: "downloadFlickrImages", code: (error! as NSError).code, userInfo: [NSLocalizedDescriptionKey: error!]))
                return
            }
            
            /* GUARD: Did we get a successful 2XX response? */
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
                completionHandler(nil, NSError(domain: "downloadFlickrImages", code: ((response as? HTTPURLResponse)?.statusCode)!, userInfo: [NSLocalizedDescriptionKey: "Your request returned a status code other than 2xx!"]))
                return
            }
            
            /* GUARD: Was there any data returned? */
            guard (data == data) else {
                completionHandler(nil, NSError(domain: "downloadFlickrImages", code: 1, userInfo: [NSLocalizedDescriptionKey: error!]))
                return
            }
            
            /* 5. Parse the data */
            let parsedResult : [String: AnyObject]!
            do {
                parsedResult = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? [String: AnyObject]
            } catch {
                completionHandler(nil, NSError(domain: "downloadFlickrImages", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not parse the data as JSON: '\(data!)'"]))
                return
            }
            
            /* GUARD: Did Flickr return an error (stat != ok)? */
            guard let stat = parsedResult[Flickr.Response.Keys.Status] as? String, stat == Flickr.Response.Values.OKStatus else {
                completionHandler(nil, NSError(domain: "downloadFlickrImages", code: 1, userInfo: [NSLocalizedDescriptionKey: "Flickr API returned an error. See error code and message in \(parsedResult)"]))
                return
            }
            
            /* GUARD: Are the "photos" and "photo" keys in our result? */
            guard let photosDictionary = parsedResult[Flickr.Response.Keys.Photos] as? [String:AnyObject], let photoArray = photosDictionary[Flickr.Response.Keys.Photo] as? [[String:AnyObject]] else {
                completionHandler(nil, NSError(domain: "downloadFlickrImages", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot find keys '\(Flickr.Response.Keys.Photos)' and '\(Flickr.Response.Keys.Photo)' in \(parsedResult)"]))
                return
            }
            
            /* 6. Use the data */
            if photoArray.count == 0 {
                completionHandler(nil, NSError(domain: "downloadFlickrImages", code: 1, userInfo: [NSLocalizedDescriptionKey: "No photos found."]))
            } else {
                completionHandler(photoArray, nil)
            }
        }
        
        /* 7. Start the request */
        task.resume()
    }
    
    // given raw JSON, return a usable Foundation object
    private func convertData(_ data: Data, completionHandlerForConvertData: (_ result: AnyObject?, _ error: NSError?) -> Void) {
        
        var parsedResult: AnyObject! = nil
        do {
            parsedResult = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as AnyObject
        } catch {
            let userInfo = [NSLocalizedDescriptionKey : "Could not parse the data as JSON: '\(data)'"]
            completionHandlerForConvertData(nil, NSError(domain: "convertData", code: 1, userInfo: userInfo))
        }
        //print(parsedResult)
        completionHandlerForConvertData(parsedResult, nil)
    }

}





