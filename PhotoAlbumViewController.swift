//
//  PhotoAlbumViewController.swift
//  VirtualTourist
//
//  Created by Marwa Abou Niaaj on 5/22/17.
//  Copyright © 2017 Marwa Abou Niaaj. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class PhotoAlbumViewController: UIViewController {

    
    //MARK: Outlets
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var noPhotosLabel: UILabel!
    @IBOutlet weak var photoAlbumCollectionView: UICollectionView!
    @IBOutlet weak var photoAlbumFlowLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var newCollectionButton: UIButton!
    
    //MARK: Properties
    
    var tappedPin: Pin?
    var photos = [Photo]()
    var downloadedPhotosCount: Int?
    
    var selectedIndexes = [IndexPath]()
    var deletedIndexes = [IndexPath]()
    var reloadingPhotos = false
    
//    var context: NSManagedObjectContext {
//        return CoreDataStack.sharedInstance.context
//    }
    
    var stack = (UIApplication.shared.delegate as! AppDelegate).stack
    
    lazy var frcPhoto : NSFetchedResultsController<Photo> = {
        
        //Initialize fetch request
        let fetchRquest = NSFetchRequest<Photo>(entityName: "Photo")
        
        //Add sort description & predicate
        fetchRquest.sortDescriptors = []
        fetchRquest.returnsDistinctResults = true
        fetchRquest.predicate = NSPredicate(format: "pin = %@", self.tappedPin!)
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRquest, managedObjectContext: self.stack.context, sectionNameKeyPath: nil, cacheName: nil)
        
        //Configure feyched result controller
        fetchedResultsController.delegate = self
        
        return fetchedResultsController
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        do {
            try frcPhoto.performFetch()
            photos = frcPhoto.fetchedObjects!
        }
        catch {
            print("Could not perform fetch")
        }
        
        photoAlbumCollectionView.delegate = self
        photoAlbumCollectionView.dataSource = self
        photoAlbumCollectionView.isPrefetchingEnabled = false
        
        adjustFlowLayout(to: photoAlbumCollectionView.frame.size)
        disableMapUserInteraction()
        dropPin()
        updateView()
    }
    
    @IBAction func downloadNewPhotos(_ sender: Any) {
        
        downloadFlickrImages()

    }
    
    func adjustFlowLayout(to size: CGSize) {
        
        if let flowLayout = photoAlbumFlowLayout {
            let space: CGFloat = 3.5
            let dimension:CGFloat =
                size.width >= size.height ?
                    (size.width - (5 * space)) / 6.0 :
                    (size.width - (2 * space)) / 3.0
            
            flowLayout.minimumInteritemSpacing = space
            flowLayout.minimumLineSpacing = space
            flowLayout.itemSize = CGSize(width: dimension, height: dimension)
        }
    }
    
    func updateView() {
        let hasPhotos = downloadedPhotosCount! > 0 || photos.count > 0
        photoAlbumCollectionView.isHidden = !hasPhotos
        noPhotosLabel.isHidden = hasPhotos
        newCollectionButton.isEnabled = hasPhotos
        
    }
    
    func dropPin() {
        
        if let pin = tappedPin {
            
            let coordinates = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinates
            
            mapView.addAnnotation(annotation)
            let span = MKCoordinateSpanMake(0.2, 0.2)
            let region = MKCoordinateRegionMake(coordinates, span)
            mapView.setRegion(region, animated: true)
        }
    }
    
    func disableMapUserInteraction() {
        mapView.isZoomEnabled = false
        mapView.isScrollEnabled = false
        mapView.isUserInteractionEnabled = false
    }
    
    func downloadFlickrImages() {
        
        tappedPin?.pageNumber += 1
        
        Flickr.sharedInstance().downloadFlickrImages((tappedPin?.latitude)!, (tappedPin?.longitude)!, Int((tappedPin?.pageNumber)!)) { (photosResult, error) in
            
            if let photosBatch = photosResult {
                
                self.downloadedPhotosCount = photosBatch.count
                
                self.stack.performBackgroundBatchOperation({ (bgContext) in
                    
                    do {
                        let result = try? self.stack.context.fetch(self.frcPhoto.fetchRequest)
                        for photo in result! {
                            self.stack.context.delete(photo)
                        }
                        self.stack.save()
                    }
                    
                    DispatchQueue.main.async {
                        
                        self.photoAlbumCollectionView.reloadData()
                    }
                    
                    for item in photosBatch {
                        
                        let imageUrl = URL(string: item[Flickr.Response.Keys.MediumURL] as! String)
                        if let imageData = try? Data(contentsOf: imageUrl!) {
                            let photo = Photo(imageData: imageData as NSData, context: bgContext)
                            photo.pin = self.tappedPin
                            self.photos.append(photo)
                            self.stack.save()
                        }
                    }
                })
            } else {
                // TODO: No photos found
            }
        }
    }
}

extension PhotoAlbumViewController : UICollectionViewDelegate, UICollectionViewDataSource {
    
    // MARK: - UICollectionView
    func configureCell(_ cell: PhotoAlbumCell, atIndexPath indexPath: IndexPath) {
        
        // If the cell is "selected", its color panel is grayed out
        if let _ = selectedIndexes.index(of: indexPath) {
            cell.photoImageView.alpha = 0.2
            cell.photoActivityIndicator.isHidden = true
        } else {
            cell.photoImageView.alpha = 1.0
        }
    }
    
    func updateButton() {
        if selectedIndexes.count > 0 {
            newCollectionButton.titleLabel?.text = "Remove Selected Photos"
        } else {
            newCollectionButton.titleLabel?.text = "New Collection"
        }
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return frcPhoto.sections?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return downloadedPhotosCount ?? photos.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PhotoAlbumCell.reuseIdentifier, for: indexPath) as! PhotoAlbumCell
        
        if !reloadingPhotos {
            
            if let photoObjects = frcPhoto.fetchedObjects, photoObjects.count > 0,
                indexPath.item < photoObjects.count {
                
                //let photo = fetchedResultsController.object(at: indexPath)
                
                cell.photoImageView.isHidden = false
                
                if let image = photoObjects[indexPath.item].imageData {
                    print("cellForItemAt: \(indexPath.item)")
                    cell.photoImageView.image = UIImage(data: image as Data)
                }
            } else {
                cell.photoImageView.isHidden = true
                cell.photoActivityIndicator.isHidden = false
                cell.photoActivityIndicator.startAnimating()
            }
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        let cell = collectionView.cellForItem(at: indexPath) as! PhotoAlbumCell
     
        if let index = selectedIndexes.index(of: indexPath) {
            selectedIndexes.remove(at: index)
        } else {
            selectedIndexes.append(indexPath)
        }
        configureCell(cell, atIndexPath: indexPath)
        updateButton()
    }
    
    func getImageFrom(url urlString: String) -> UIImage {
        
        var image: UIImage!
        
        let imageUrl = URL(string: urlString)
        if let imageData = try? Data(contentsOf: imageUrl!) {
            image = UIImage(data: imageData)!
        }
        return image
    }
    
    func getImageFrom(imageData: NSData) -> UIImage {
        return UIImage(data: imageData as Data)!
    }
}

//MARK: - Fetch Result Controller Delegate

extension PhotoAlbumViewController : NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        deletedIndexes = [IndexPath]()
        selectedIndexes = [IndexPath]()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        switch type {
        case .insert:
            reloadingPhotos = false
            print("Insert: \(String(describing: newIndexPath?.item))")
            photoAlbumCollectionView.reloadItems(at: [newIndexPath!])
            photoAlbumCollectionView.reloadData()
            break
        case .delete:
            reloadingPhotos = true
            print("Delete: \(String(describing: indexPath?.item))")
            deletedIndexes.append(indexPath!)
            break
        default:
            break
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        
        photoAlbumCollectionView.performBatchUpdates({
            
            for index in self.deletedIndexes {
                
                let cell = self.photoAlbumCollectionView.dequeueReusableCell(withReuseIdentifier: PhotoAlbumCell.reuseIdentifier, for: index) as! PhotoAlbumCell
                
                cell.photoImageView.isHidden = true
                cell.photoActivityIndicator.isHidden = false
                cell.photoActivityIndicator.startAnimating()
                self.photoAlbumCollectionView.reloadItems(at: [index])
            }
            
        }) { (success) in
            //print("Updated !!")
        }
    }
}



