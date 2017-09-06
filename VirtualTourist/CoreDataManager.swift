//
//  CoreDataManager.swift
//  VirtualTourist
//
//  Created by Marwa Abou Niaaj on 6/5/17.
//  Copyright © 2017 Marwa Abou Niaaj. All rights reserved.
//

import Foundation
import CoreData

public class CoreDataManager {
    
    private let modelName: String
    
    init(modelName: String) {
        self.modelName = modelName
    }
    
    // MARK: - Shared Instance
    
    /**
     *  This class variable provides an easy way to get access
     *  to a shared instance of the CoreDataManager class.
     */
    class func sharedInstance() -> CoreDataManager {
        struct Static {
            static let instance = CoreDataManager(modelName: "Model")
        }
        return Static.instance
    }
    
    private lazy var objectModel: NSManagedObjectModel? = {
       
        //Fetch model URL
        guard let modelUrl = Bundle.main.url(forResource: self.modelName, withExtension: "momd") else {
            return nil
        }
        
        // Initialize Managed Object Model
        let objectModel = NSManagedObjectModel(contentsOf: modelUrl)
        
        return objectModel
        
    }()
    
    private lazy var persistentCooredinator: NSPersistentStoreCoordinator? = {
       
        guard let objectModel = self.objectModel else {
            return nil
        }
        
        let persistentCooredinator = NSPersistentStoreCoordinator(managedObjectModel: objectModel)
        
        do {
            let options = [ NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true]
            
            try persistentCooredinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: self.persistentStoreURL, options: options)
            
        } catch {
            let addPersistentStoreError = error as NSError
            
            print("Unable to Add Persistent Store")
            print("\(addPersistentStoreError.localizedDescription)")
        }
        
        return persistentCooredinator
    }()
    
    private var persistentStoreURL: URL {
        
        let storeName = "\(modelName).sqlite"
        let fileManager = FileManager.default
        
        let documentsDirectoryURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        
        return (documentsDirectoryURL?.appendingPathComponent(storeName))!
    }
    
    private lazy var privateContext: NSManagedObjectContext = {
        
        // Initialize Managed Object Context
        let privateContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        
        // Configure Private Managed Object Context
        privateContext.persistentStoreCoordinator = self.persistentCooredinator
        
        return privateContext
    }()
    
    public private(set) lazy var mainContext: NSManagedObjectContext = {
        
        // Initialize Managed Object Context
        let mainContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        
        // Configure Main Managed Object Context
        mainContext.parent = self.privateContext
        
        return mainContext
    }()
    
    public lazy var backgroundContext: NSManagedObjectContext = {
        
        // Initialize Managed Object Context
        let backgroundContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        
        // Configure Child Managed Object Context
        backgroundContext.parent = self.mainContext
        
        return backgroundContext
    }()
    
    //MARK: - CoreData Saving Process
    
    public func saveChanges() {
        
        self.mainContext.performAndWait {
            do {
                if self.mainContext.hasChanges{
                    try self.mainContext.save()
                }
            } catch {
                print("Unable to Save Changes of Main Context")
                print("\(error), \(error.localizedDescription)")
            }
            
            self.privateContext.perform {
                do {
                    try self.privateContext.save()
                } catch {
                    print("Unable to Save Changes of Private Context")
                    print("\(error), \(error.localizedDescription)")
                }
            }
            
        }
        
        
    }
    
    //MARK: - Batch Processing in the Background
    
    typealias Batch = (_ workerContext: NSManagedObjectContext) -> ()
    
    func performBackgroundBatchOperation(_ batch: @escaping Batch) {
        
        self.backgroundContext.perform {
            
            batch(self.backgroundContext)
            
            // Save it to the parent context, so the normal saving can work
            do {
                try self.backgroundContext.save()
            }
            catch {
                print("Unable to Save Changes of Background Context")
                print("\(error), \(error.localizedDescription)")
            }
        }
    }
    
    func dropAllData() throws {
        // delete all the objects in the db. This won't delete the files, it will
        // just leave empty tables.
        try persistentCooredinator?.destroyPersistentStore(at: persistentStoreURL, ofType: NSSQLiteStoreType, options: nil)
        
        let options = [ NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true]
        
        try persistentCooredinator?.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: persistentStoreURL, options: options)
    }
}
