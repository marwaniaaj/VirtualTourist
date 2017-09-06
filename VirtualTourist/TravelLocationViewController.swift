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
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.stack.backgroundContext, sectionNameKeyPath: nil, cacheName: nil)
        //fetchedResultsController.delegate = self as? NSFetchedResultsControllerDelegate
        
        return fetchedResultsController
    }()
    
    //MARK: Outlets
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var deletePinsLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(managedObjectContextDidSave), name: NSNotification.Name.NSManagedObjectContextDidSave, object: stack.backgroundContext)
        
        self.navigationItem.rightBarButtonItem = editButtonItem
        
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

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        if editing {
            editButtonItem.tintColor = .red
            UIView.animate(withDuration: 0.3, animations: {
                self.deletePinsLabel.frame.origin.y -= self.deletePinsLabel.frame.size.height
            })
        } else  {
            editButtonItem.tintColor = self.view.tintColor
            UIView.animate(withDuration: 0.3, animations: {
                self.deletePinsLabel.frame.origin.y += self.deletePinsLabel.frame.size.height
            })
        }
    }
    
    func managedObjectContextDidSave(notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        if let inserts = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject>, inserts.count > 0 {
            print("--- INSERTS ---")
        }
        
        stack.context.perform { 
            self.stack.save()
        }
        //stack.context.mergeChanges(fromContextDidSave: notification)
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
        
        if gesture.state == .ended && !isEditing {
            let touchPoint  = gesture.location(in: mapView)
            let newCoordinates = mapView.convert(touchPoint, toCoordinateFrom: mapView)
            let annotation = MKPointAnnotation()
            annotation.coordinate = newCoordinates
            mapView.addAnnotation(annotation)
            
            savePin(annotation.coordinate)
            
            downloadFlickrImages(annotation.coordinate)
        }
    }
    
    func savePin(_ coordinates: CLLocationCoordinate2D) {
        
        stack.performBackgroundBatchOperation({ (bgContext) in
            self.droppedPin = Pin(latitude: coordinates.latitude, longitude: coordinates.longitude, pageNumber: 1, context: bgContext)
            DispatchQueue.main.async {
                self.stack.save()
            }
        })
    }
    
    func downloadFlickrImages(_ coordinates: CLLocationCoordinate2D) {
        
        Flickr.sharedInstance().downloadFlag = true
        
        Flickr.sharedInstance().downloadFlickrImages(coordinates.latitude, coordinates.longitude, Flickr.sharedInstance().imagesPageNumber) { (photosResult, error) in
            
            if let photos = photosResult {
                DispatchQueue.main.async {
                    self.savePhotos(coordinates, photos)
                    self.downloadedPhotoCount = photos.count
                }
            }
        }
    }
    
    func savePhotos(_ coordinate: CLLocationCoordinate2D, _ photos: [[String: AnyObject]]) {
        
        stack.performBackgroundBatchOperation { (bgContext) in
            
            for item in photos {
                let imageUrl = URL(string: item[Flickr.Response.Keys.MediumURL] as! String)
                if let imageData = try? Data(contentsOf: imageUrl!) {
                    
                    let photo = Photo(imageData: imageData as NSData, context: bgContext)
                    photo.pin = bgContext.object(with: (self.droppedPin?.objectID)!) as? Pin
                    self.stack.backgroundSave()
                }
            }
            Flickr.sharedInstance().downloadFlag = false
        }
    }
    
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "showPhotoAlbum" {
            let photosCollectionView = segue.destination as! PhotoAlbumViewController
            
            // Set tapped pin
            photosCollectionView.tappedPin = self.tappedPin
            //photosCollectionView.photos = self.pinPhotos
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
            
            fetchTappedPin(pin: pin, completion: { (result) in
                
                if let resultPin = result {
                    
                    if self.isEditing {
                        mapView.removeAnnotation(pin)
                        self.stack.context.delete(resultPin)
                        DispatchQueue.main.async {
                            self.stack.save()
                        }
                    } else {
                        mapView.deselectAnnotation(pin, animated: false)
                        self.performSegue(withIdentifier: "showPhotoAlbum", sender: self)
                    }
                }
            })
        }
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        UserDefaults.standard.set(mapView.region.center.latitude, forKey: MapCenterLatitudeValueKey)
        UserDefaults.standard.set(mapView.region.center.longitude, forKey: MapCenterLongitudeValueKey)
        UserDefaults.standard.set(mapView.region.span.latitudeDelta, forKey: MapSpanLatitudeValueKey)
        UserDefaults.standard.set(mapView.region.span.longitudeDelta, forKey: MapSpanLongitudeValueKey)
    }
    
    func fetchTappedPin(pin: MKAnnotation, completion: @escaping ((Pin?) -> Void)) {
        
        let pinFetchRequest = NSFetchRequest<Pin>(entityName: "Pin")
        pinFetchRequest.predicate = NSPredicate(format: "latitude = %lf AND longitude = %lf", pin.coordinate.latitude, pin.coordinate.longitude)
        
        if let result = try? stack.context.fetch(pinFetchRequest) {
            tappedPin = result.first
            completion(tappedPin)
        } else {
            completion(nil)
        }
    }
}




