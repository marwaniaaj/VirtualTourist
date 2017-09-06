//
//  PhotoAlbumCell.swift
//  VirtualTourist
//
//  Created by Marwa Abou Niaaj on 5/22/17.
//  Copyright © 2017 Marwa Abou Niaaj. All rights reserved.
//

import UIKit

class PhotoAlbumCell: UICollectionViewCell {
    
    static let reuseIdentifier = "photoCell"
    
    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var photoActivityIndicator: UIActivityIndicatorView!
}
