//
//  CloudKitPinnedTabManager.swift
//  EvoArc
//
//  Created on 2025-09-06.
//  Safe CloudKit implementation that won't crash Xcode
//

import Foundation
import SwiftUI
import Combine
import CoreData

class CloudKitPinnedTabManager: ObservableObject {
    static let shared = CloudKitPinnedTabManager()
    
    @Published var pinnedTabs: [PinnedTabEntity] = []
    @Published var isReady: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private let entityName = "PinnedTab"
    
    // Safe lazy initialization to prevent crashes
    private lazy var persistenceController: PersistenceController = {
        return PersistenceController.shared
    }()
    
    private init() {
        // Defer all initialization to avoid crashes
        DispatchQueue.main.async { [weak self] in
            self?.initialize()
        }
    }
    
    // MARK: - Public Methods
    
    func pinTab(url: URL, title: String) {
        guard isReady else {
            print("CloudKit manager not ready, skipping pin operation")
            return
        }
        
        // Check if already pinned
        if pinnedTabs.contains(where: { $0.urlString == url.absoluteString }) {
            print("Tab already pinned: \(url.absoluteString)")
            return
        }
        
        // Create in-memory entity first
        let entity = PinnedTabEntity(
            urlString: url.absoluteString,
            title: title.isEmpty ? "New Tab" : title,
            isPinned: true,
            createdAt: Date(),
            pinnedOrder: Int16(pinnedTabs.count)
        )
        
        // Add to local array immediately for responsive UI
        pinnedTabs.append(entity)
        
        // Persist to Core Data asynchronously
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.persistToCore(entity: entity)
        }
        
        print("✅ Pinned tab: \(title)")
    }
    
    func unpinTab(url: URL) {
        guard isReady else {
            print("CloudKit manager not ready, skipping unpin operation")
            return
        }
        
        // Remove from local array immediately
        pinnedTabs.removeAll { $0.urlString == url.absoluteString }
        
        // Remove from Core Data asynchronously
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.removeFromCore(urlString: url.absoluteString)
        }
        
        print("📌 Unpinned tab: \(url.absoluteString)")
    }
    
    func isTabPinned(url: URL) -> Bool {
        return pinnedTabs.contains(where: { $0.urlString == url.absoluteString })
    }
    
    func reorderPinnedTabs(_ entities: [PinnedTabEntity]) {
        guard isReady else { return }
        
        // Update local array
        pinnedTabs = entities
        
        // Update Core Data in background
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.updateOrderInCore(entities: entities)
        }
    }
    
    // MARK: - Private Methods
    
    private func initialize() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.initialize()
            }
            return
        }
        
        print("🚀 Initializing CloudKit PinnedTabManager...")
        
        // Set up Core Data observer
        setupCoreDataObserver()
        
        // Load existing data
        loadPinnedTabs()
        
        // Mark as ready
        isReady = true
        print("✅ CloudKit PinnedTabManager ready")
    }
    
    private func loadPinnedTabs() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let context = self.persistenceController.container.viewContext
                let request = NSFetchRequest<NSManagedObject>(entityName: self.entityName)
                request.sortDescriptors = [NSSortDescriptor(key: "pinnedOrder", ascending: true)]
                
                let results = try context.fetch(request)
                let entities = results.compactMap { self.entityFromManagedObject($0) }
                
                DispatchQueue.main.async {
                    self.pinnedTabs = entities
                    print("📂 Loaded \(entities.count) pinned tabs from CloudKit")
                }
                
            } catch {
                print("❌ Failed to load pinned tabs: \(error)")
                DispatchQueue.main.async {
                    self.pinnedTabs = []
                }
            }
        }
    }
    
    private func setupCoreDataObserver() {
        NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange)
            .compactMap { $0.object as? NSManagedObjectContext }
            .filter { [weak self] context in
                guard let self = self else { return false }
                return context == self.persistenceController.container.viewContext
            }
            .sink { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self?.loadPinnedTabs()
                }
            }
            .store(in: &cancellables)
    }
    
    private func persistToCore(entity: PinnedTabEntity) {
        do {
            let context = persistenceController.container.viewContext
            let managedObject = NSManagedObject(entity: NSEntityDescription.entity(forEntityName: entityName, in: context)!, insertInto: context)
            
            managedObject.setValue(entity.urlString, forKey: "urlString")
            managedObject.setValue(entity.title, forKey: "title")
            managedObject.setValue(entity.isPinned, forKey: "isPinned")
            managedObject.setValue(entity.createdAt, forKey: "createdAt")
            managedObject.setValue(entity.pinnedOrder, forKey: "pinnedOrder")
            
            try context.save()
            print("💾 Persisted pinned tab to CloudKit")
            
        } catch {
            print("❌ Failed to persist to Core Data: \(error)")
        }
    }
    
    private func removeFromCore(urlString: String) {
        do {
            let context = persistenceController.container.viewContext
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            request.predicate = NSPredicate(format: "urlString == %@", urlString)
            
            let results = try context.fetch(request)
            results.forEach { context.delete($0) }
            
            try context.save()
            print("🗑️ Removed pinned tab from CloudKit")
            
        } catch {
            print("❌ Failed to remove from Core Data: \(error)")
        }
    }
    
    private func updateOrderInCore(entities: [PinnedTabEntity]) {
        do {
            let context = persistenceController.container.viewContext
            
            for (index, entity) in entities.enumerated() {
                let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
                request.predicate = NSPredicate(format: "urlString == %@", entity.urlString)
                
                if let managedObject = try context.fetch(request).first {
                    managedObject.setValue(Int16(index), forKey: "pinnedOrder")
                }
            }
            
            try context.save()
            print("🔄 Updated pinned tab order in CloudKit")
            
        } catch {
            print("❌ Failed to update order in Core Data: \(error)")
        }
    }
    
    private func entityFromManagedObject(_ managedObject: NSManagedObject) -> PinnedTabEntity? {
        guard let urlString = managedObject.value(forKey: "urlString") as? String,
              let title = managedObject.value(forKey: "title") as? String,
              let isPinned = managedObject.value(forKey: "isPinned") as? Bool,
              let createdAt = managedObject.value(forKey: "createdAt") as? Date,
              let pinnedOrder = managedObject.value(forKey: "pinnedOrder") as? Int16 else {
            return nil
        }
        
        return PinnedTabEntity(
            urlString: urlString,
            title: title,
            isPinned: isPinned,
            createdAt: createdAt,
            pinnedOrder: pinnedOrder
        )
    }
}

// MARK: - Safe Entity Model

struct PinnedTabEntity: Identifiable, Equatable {
    let id = UUID()
    let urlString: String
    let title: String
    let isPinned: Bool
    let createdAt: Date
    let pinnedOrder: Int16
    
    var url: URL? {
        return URL(string: urlString)
    }
    
    static func == (lhs: PinnedTabEntity, rhs: PinnedTabEntity) -> Bool {
        return lhs.urlString == rhs.urlString
    }
}
