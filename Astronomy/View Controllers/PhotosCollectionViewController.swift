//
//  PhotosCollectionViewController.swift
//  Astronomy
//
//  Created by Andrew R Madsen on 9/5/18.
//  Copyright © 2018 Lambda School. All rights reserved.
//

import UIKit

class PhotosCollectionViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        client.fetchMarsRover(named: "curiosity") { (rover, error) in
            if let error = error {
                NSLog("Error fetching info for curiosity: \(error)")
                return
            }
            
            self.roverInfo = rover
        }
    }
    
    // UICollectionViewDataSource/Delegate
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photoReferences.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageCell", for: indexPath) as? ImageCollectionViewCell ?? ImageCollectionViewCell()
        
        loadImage(forCell: cell, forItemAt: indexPath)
        
        return cell
    }
    
    // Make collection view cells fill as much available width as possible
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let flowLayout = collectionViewLayout as! UICollectionViewFlowLayout
        var totalUsableWidth = collectionView.frame.width
        let inset = self.collectionView(collectionView, layout: collectionViewLayout, insetForSectionAt: indexPath.section)
        totalUsableWidth -= inset.left + inset.right
        
        let minWidth: CGFloat = 150.0
        let numberOfItemsInOneRow = Int(totalUsableWidth / minWidth)
        totalUsableWidth -= CGFloat(numberOfItemsInOneRow - 1) * flowLayout.minimumInteritemSpacing
        let width = totalUsableWidth / CGFloat(numberOfItemsInOneRow)
        return CGSize(width: width, height: width)
    }
    
    // Add margins to the left and right side
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 10.0, bottom: 0, right: 10.0)
    }
    
    // MARK: - Private
    
    private func loadImage(forCell cell: ImageCollectionViewCell, forItemAt indexPath: IndexPath) {
        
        photoFetchQueue.name = "com.ilqarilyasov.astronomyApp.FetchPhotoQueue"
        let marsPhoto = photoReferences[indexPath.item]
        let fetchPhoto = FetchPhotoOperation(marsPhotoReference: marsPhoto)
        
        let op1 = BlockOperation {
            fetchPhoto.start()
        }
        
        guard let data = fetchPhoto.imageData else { return }
        
        let op2 = BlockOperation {
            self.cache.cache(value: data, forKey: marsPhoto.id)
        }
        
        fetchOperations[marsPhoto.id] = op1
        
        DispatchQueue.main.async {
            if self.collectionView.indexPath(for: cell) == indexPath {
                cell.imageView.image = UIImage(data: data)
            }
        }
        op2.addDependency(op1)
        photoFetchQueue.addOperation(op1)
        photoFetchQueue.addOperation(op2)
        photoFetchQueue.waitUntilAllOperationsAreFinished()
        
//        let photoURL = marsPhoto.imageURL.usingHTTPS!
        
//        if let data = cache.value(forKey: marsPhoto.id) {
//            DispatchQueue.main.async {
//                cell.imageView.image = UIImage(data: data)
//            }
//        } else {
//            URLSession.shared.dataTask(with: photoURL) { (data, _, error) in
//                if error != nil {
//                    NSLog("Error performing data task")
//                    return
//                }
//
//                guard let data = data else {
//                    NSLog("No data reurned")
//                    return
//                }
//
//                self.cache.cache(value: data, forKey: indexPath.item)
//                let image = UIImage(data: data)!
//
//                DispatchQueue.main.async {
//                    if self.collectionView.indexPath(for: cell) == indexPath {
//                        cell.imageView.image = image
//                    }
//                }
//            }.resume()
//        }
    }
    
    // Properties
    
    private let client = MarsRoverClient()
    
    private var roverInfo: MarsRover? {
        didSet {
            solDescription = roverInfo?.solDescriptions[20]
        }
    }
    private var solDescription: SolDescription? {
        didSet {
            if let rover = roverInfo,
                let sol = solDescription?.sol {
                client.fetchPhotos(from: rover, onSol: sol) { (photoRefs, error) in
                    if let e = error { NSLog("Error fetching photos for \(rover.name) on sol \(sol): \(e)"); return }
                    self.photoReferences = photoRefs ?? []
                }
            }
        }
    }
    private var photoReferences = [MarsPhotoReference]() {
        didSet {
            DispatchQueue.main.async { self.collectionView?.reloadData() }
        }
    }
    
    let cache = Cache<Int, Data>()
    private var photoFetchQueue = OperationQueue()
    var fetchOperations: [Int: BlockOperation] = [:]
    
    @IBOutlet var collectionView: UICollectionView!
}
