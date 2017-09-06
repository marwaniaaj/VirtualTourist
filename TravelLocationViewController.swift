//
//  TravelLocationViewController.swift
//  VirtualTourist
//
//  Created by Marwa Abou Niaaj on 5/22/17.
//  Copyright © 2017 Marwa Abou Niaaj. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class TravelLocationViewController: UIViewController {
    
    //MARK: Properties
    let MapCenterLatitudeValueKey = "MapCenterLatitude"
    let MapCenterLongitudeValueKey = "MapCenterLongitude"
    let MapSpanLatitudeValueKey = "MapSpanLatitude"
    let MapSpanLongitudeValueKey = "MapSpanLongitude"
    
    var pins: [Pin] = []
    var pinPhotos: [Photo] = []
    var downloadedPhotoCount = 0
    var tappedPin: Pin?
    var droppedPin: Pin?
    
    var pageNumber = 1
    
    var annotations: [MKPointAnnotation]?
    var coordinates: CLLocationCoordinate2D?
    
    
    var stack = (UIApplication.shared.delegate as! AppDelegate).stack
    
    lazy var fetchedResultsController : NSFetchedResultsController<Pin> = { () -> NSFetchedResultsController<Pin> in
        
        let fetchRequest = NSFetchRequest<Pin>(entityName: "Pin")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "latitude", ascending: true)]
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.stack.context, sectionNameKeyPath: nil, cacheName: nil)
        //fetchedResultsController.delegate = self as? NSFetchedResultsControllerDelegate
        
        return fetchedResultsController
    }()
    
    //MARK: Outlets
    @IBOutlet weak var mapView: MKMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(managedObjectContextDidSave), name: NSNotification.Name.NSManagedObjectContextDidSave, object: stack.backgroundContext)
        
        mapView.delegate = self
        setRegion()
        
        let dropPinGesture = UILongPressGestureRecognizer(target: self, action: #selector(AddAnnotation(gesture:)))
        dropPinGesture.minimumPressDuration = 0.7
        mapView.addGestureRecognizer(dropPinGesture)
        
        do {
            try fetchedResultsController.performFetch()
            pins = fetchedResultsController.fetchedObjects!
            
            if pins.count > 0 {
                addSavedPins(pins)
            }
        } catch {
            let fetchError = error as NSError
            print("Unable to Perform Fetch Request")
            print("\(fetchError), \(fetchError.localizedDescription)")
        }
    }
    
    func managedObjectContextDidSave(notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        if let inserts = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject>, inserts.count > 0 {
            print("--- INSERTS ---")
            //print((inserts as? Set<Photo>)?.imageData!)
            //print("---------------")
        }
    }
    
    func printDatabaseStatistics() {
        let pinCount = try? stack.context.count(for: NSFetchRequest(entityName: "Pin"))
        let photoCount = try? stack.context.count(for: NSFetchRequest(entityName: "Photo"))
        print("\(String(describing: pinCount)) Pins Found")
        print("\(String(describing: photoCount)) Photos Found")
    }
    
    func firstLunch() -> Bool {
        
        if UserDefaults.standard.bool(forKey: "HasLaunchedBefore") {
            //App has launched before
            return false
            
        } else {
            //This is the first launch ever!
            UserDefaults.standard.set(true, forKey: "HasLaunchedBefore")
            UserDefaults.standard.synchronize()
            return true
        }
    }
    
    func setRegion() {
        
        if firstLunch() {
            UserDefaults.standard.set(mapView.region.center.latitude, forKey: MapCenterLatitudeValueKey)
            UserDefaults.standard.set(mapView.region.center.longitude, forKey: MapCenterLongitudeValueKey)
            UserDefaults.standard.set(mapView.region.span.latitudeDelta, forKey: MapSpanLatitudeValueKey)
            UserDefaults.standard.set(mapView.region.span.longitudeDelta, forKey: MapSpanLongitudeValueKey)
            
        } else {
            
            let center = CLLocationCoordinate2D(latitude: UserDefaults.standard.value(forKey: MapCenterLatitudeValueKey) as! CLLocationDegrees, longitude: UserDefaults.standard.value(forKey: MapCenterLongitudeValueKey) as! CLLocationDegrees)
            
            let span = MKCoordinateSpanMake(UserDefaults.standard.value(forKey: MapSpanLatitudeValueKey) as! CLLocationDegrees, UserDefaults.standard.value(forKey: MapSpanLongitudeValueKey) as! CLLocationDegrees)
            
            let region = MKCoordinateRegion(center: center, span: span)
            
            mapView.setRegion(region, animated: true)
        }
        
    }
    
    func addSavedPins(_ pins: [Pin]) {
        
        for pin in pins {
            let coordinates = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinates
            mapView.addAnnotation(annotation)
        }
    }
    
    func AddAnnotation(gesture: UIGestureRecognizer) {
        
        if gesture.state == .ended {
            let touchPoint  = gesture.location(in: mapView)
            let newCoordinates = mapView.convert(touchPoint, toCoordinateFrom: mapView)
            let annotation = MKPointAnnotation()
            annotation.coordinate = newCoordinates
            mapView.addAnnotation(annotation)
            
            downloadFlickrImages(annotation.coordinate)
        }
    }
    
    func downloadFlickrImages(_ coordinates: CLLocationCoordinate2D) {
        
        Flickr.sharedInstance().downloadFlickrImages(coordinates.latitude, coordinates.longitude, Flickr.sharedInstance().imagesPageNumber) { (photosResult, error) in
            
            if let photos = photosResult {
                self.savePhotos(coordinates, photos)
                self.downloadedPhotoCount = photos.count
            }
        }
    }
    
    func savePhotos(_ coordinate: CLLocationCoordinate2D, _ photos: [[String: AnyObject]]) {
        
        stack.performBackgroundBatchOperation { (workerContext) in
            
            self.droppedPin = Pin(latitude: coordinate.latitude, longitude: coordinate.longitude, pageNumber: 1, context: workerContext)

            do {
                try workerContext.save()
            } catch {
                print("Pin is not saved ..... ")
            }
            
            for item in photos {
                
                let imageUrl = URL(string: item[Flickr.Response.Keys.MediumURL] as! String)
                if let imageData = try? Data(contentsOf: imageUrl!) {
                    let photo = Photo(imageData: imageData as NSData, context: workerContext)
                    photo.pin = self.droppedPin
                    self.pinPhotos.append(photo)
                    do {
                        try? workerContext.save()
                    }
                }
            }
        }
    }
    
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "showPhotoAlbum" {
            let photosCollectionView = segue.destination as! PhotoAlbumViewController
            
            // Set tapped pin
            photosCollectionView.tappedPin = self.tappedPin
            photosCollectionView.photos = self.pinPhotos
            photosCollectionView.downloadedPhotosCount = self.downloadedPhotoCount
            
            // Set back button
            let backItem = UIBarButtonItem()
            backItem.title = "Back"
            navigationItem.backBarButtonItem = backItem
        }
    }

}

extension TravelLocationViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        let reuseId = "photosPin"
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKPinAnnotationView
        
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.canShowCallout = false
            pinView!.animatesDrop = true
            
        }
        else {
            pinView!.annotation = annotation
        }
        return pinView
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        
        if let pin = view.annotation {
            
            let pinFetchRequest = NSFetchRequest<Pin>(entityName: "Pin")
            pinFetchRequest.predicate = NSPredicate(format: "latitude = %lf AND longitude = %lf", pin.coordinate.latitude, pin.coordinate.longitude)
            
            do {
                tappedPin = try stack.backgroundContext.fetch(pinFetchRequest).first
            } catch {
                print("Error fetching tapped pin")
            }
            
            mapView.deselectAnnotation(pin, animated: true)
            self.performSegue(withIdentifier: "showPhotoAlbum", sender: self)
        }
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        UserDefaults.standard.set(mapView.region.center.latitude, forKey: MapCenterLatitudeValueKey)
        UserDefaults.standard.set(mapView.region.center.longitude, forKey: MapCenterLongitudeValueKey)
        UserDefaults.standard.set(mapView.region.span.latitudeDelta, forKey: MapSpanLatitudeValueKey)
        UserDefaults.standard.set(mapView.region.span.longitudeDelta, forKey: MapSpanLongitudeValueKey)
    }
}




