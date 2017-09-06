//
//  CoreDataStack.swift
//  VirtualTourist
//
//  Created by Marwa Abou Niaaj on 5/25/17.
//  Copyright © 2017 Marwa Abou Niaaj. All rights reserved.
//

import CoreData

// MARK: - CoreDataStack

struct CoreDataStack {
    
    //MARK: Properties
    
    private let model: NSManagedObjectModel
    internal let coordinator: NSPersistentStoreCoordinator
    private let modelUrl: URL
    internal let dbUrl: URL
    internal let persistingContext: NSManagedObjectContext
    internal let backgroundContext: NSManagedObjectContext
    let context: NSManagedObjectContext
    
    //MARK: Initializers
    
    init?(modelName: String) {
        
        // Assumes the model is in the main bundle
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "momd") else {
            print("Unable to find \(modelName) in the main bundle")
            return nil
        }
        self.modelUrl = modelURL
        
        // Try to create the model from the URL
        guard let model = NSManagedObjectModel(contentsOf: modelURL) else {
            print("unable to create a model from \(modelURL)")
            return nil
        }
        self.model = model
        
        // Create the store coordinator
        coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        
        // Create a persistingContext (private queue) and a child one (main queue)
        // create a context and add connect it to the coordinator
        persistingContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        persistingContext.persistentStoreCoordinator = coordinator
        
        // Create a main context child of persisting context
        context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        //context.persistentStoreCoordinator = coordinator
        context.parent = persistingContext
        
        // Create a background context child of main context
        backgroundContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        backgroundContext.parent = context
        
        // Add a SQLite store located in the documents folder
        let fm = FileManager.default
        
        guard let docUrl = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Unable to reach the documents folder")
            return nil
        }
        self.dbUrl = docUrl.appendingPathComponent("photosByLocation.sqlite")
        
        // Options for migration
        let options = [NSInferMappingModelAutomaticallyOption: true, NSMigratePersistentStoresAutomaticallyOption: true]
        
        do {
            try addStoreCoordinator(NSSQLiteStoreType, configuration: nil, storeURL: dbUrl, options: options as [NSObject : AnyObject]?)
        } catch {
            print("unable to add store at \(dbUrl)")
        }
    }
    
    // MARK: Utils
    
    func addStoreCoordinator(_ storeType: String, configuration: String?, storeURL: URL, options : [NSObject:AnyObject]?) throws {
        try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: dbUrl, options: nil)
    }
}

// MARK: - CoreDataStack (Removing Data)

internal extension CoreDataStack {
    
    func dropAllData() throws {
        // delete all the objects in the db. This won't delete the files, it will
        // just leave empty tables.
        try coordinator.destroyPersistentStore(at: dbUrl, ofType:NSSQLiteStoreType , options: nil)
        try addStoreCoordinator(NSSQLiteStoreType, configuration: nil, storeURL: dbUrl, options: nil)
        print("All data dropped ... ")
    }
    
}

// MARK: - CoreDataStack (Save Data)

extension CoreDataStack {
    
    typealias Batch = (_ workerContext: NSManagedObjectContext) -> ()
    
    func performBackgroundBatchOperation(_ batch: @escaping Batch) {
        
        self.backgroundContext.perform {
            
            batch(self.backgroundContext)
            
            // Save it to the parent context, so the normal saving can work
            self.backgroundSave()
        }
    }
    
    func  backgroundSave() {
        do {
            try self.backgroundContext.save()
            //print("background context save ......")
        }
        catch {
            print("Unable to Save Changes of Background Context")
            print("\(error), \(error.localizedDescription)")
        }
    }
 
    func save() {
        // We call this synchronously, but it's a very fast
        // operation (it doesn't hit the disk). We need to know
        // when it ends so we can call the next save (on the persisting
        // context). This last one might take some time and is done
        // in a background queue
        context.perform() {

            if self.context.hasChanges {
                do {
                    try self.context.save()
                    //print("main context save ......")
                } catch {
                    fatalError("Error while saving main context: \(error)")
                }
                
                // now we save in the background
                self.persistingContext.perform() {
                    do {
                        try self.persistingContext.save()
                    } catch {
                        fatalError("Error while saving persisting context: \(error)")
                    }
                }
            }
        }
    }
}



