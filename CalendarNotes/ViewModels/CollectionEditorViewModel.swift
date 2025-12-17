//
//  CollectionEditorViewModel.swift
//  CalendarNotes
//
//  ViewModel for editing and creating collections
//

import Foundation
import SwiftUI
import CoreData
import Combine

@MainActor
final class CollectionEditorViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var name: String = ""
    @Published var selectedIcon: String = "folder"
    @Published var selectedColor: String = "#999999"
    @Published var selectedParent: Collection? = nil
    @Published var sortOrder: SortOrder = .manual
    @Published var smartRules: SmartCollectionRules = SmartCollectionRules()
    @Published var nameValidationError: String? = nil
    @Published var theme: CollectionTheme = CollectionTheme()
    @Published var featuredConfiguration: CollectionFeaturedConfiguration = CollectionFeaturedConfiguration()
    @Published var presentationSettings: CollectionPresentationSettings = CollectionPresentationSettings()
    @Published var layoutMode: CollectionLayoutMode = .masonry
    @Published var headerImageData: Data? = nil
    @Published var coverImageData: Data? = nil
    @Published var isProject: Bool = false
    @Published var projectStatus: ProjectStatus = .planning
    @Published var projectSummary: String = ""
    @Published var projectStartDate: Date? = nil
    @Published var projectTargetDate: Date? = nil
    @Published var projectCompletionDate: Date? = nil
    @Published var projectProgress: Double = 0
    
    // MARK: - State
    @Published var isEditing: Bool = false
    @Published var availableCollections: [Collection] = []
    @Published var availableTags: [String] = []
    
    // MARK: - Private Properties
    private let context: NSManagedObjectContext
    private let coreDataManager = CoreDataManager.shared
    var editingCollection: Collection?
    
    // MARK: - Enums
    
    enum SortOrder: String, CaseIterable, Identifiable {
        case manual = "Manual"
        case dateAdded = "Date Added"
        case alphabetical = "Alphabetical"
        case mostVisited = "Most Visited"
        
        var id: String { rawValue }
    }
    
    struct SmartCollectionRules: Codable {
        var tagFilter: String? = nil
        var domainFilter: String? = nil
        var dateRangeStart: Date? = nil
        var dateRangeEnd: Date? = nil
        var favoriteStatus: Bool? = nil
        var isEnabled: Bool = false
    }
    
    // MARK: - Initialization
    
    init(context: NSManagedObjectContext, collection: Collection? = nil) {
        self.context = context
        self.editingCollection = collection
        
        if let collection = collection {
            loadCollection(collection)
            isEditing = true
        } else {
            resetToDefaults()
        }
        
        // Load available data asynchronously to avoid blocking initialization
        Task { @MainActor in
            loadAvailableData()
        }
    }
    
    // MARK: - Public Methods
    
    func loadCollection(_ collection: Collection) {
        name = collection.name ?? ""
        selectedIcon = collection.icon ?? "folder"
        selectedColor = collection.color ?? "#999999"
        selectedParent = collection.parent
        theme = collection.themeConfiguration
        featuredConfiguration = collection.featuredConfiguration
        presentationSettings = collection.presentationSettings
        layoutMode = collection.layoutMode
        headerImageData = collection.headerImage
        coverImageData = collection.coverImage
        isProject = collection.isProject
        projectStatus = collection.projectStatusValue
        projectSummary = collection.projectSummaryText
        projectStartDate = collection.projectStartDate
        projectTargetDate = collection.projectTargetDate
        projectCompletionDate = collection.projectCompletionDate
        projectProgress = collection.projectProgress
        
        // Load sort order from UserDefaults
        if let collectionId = collection.id?.uuidString {
            let sortOrderKey = "collection_sortOrder_\(collectionId)"
            if let sortOrderString = UserDefaults.standard.string(forKey: sortOrderKey),
               let order = SortOrder(rawValue: sortOrderString) {
                sortOrder = order
            }
            
            // Load smart rules from UserDefaults
            let rulesKey = "collection_smartRules_\(collectionId)"
            if let rulesData = UserDefaults.standard.data(forKey: rulesKey),
               let rules = try? JSONDecoder().decode(SmartCollectionRules.self, from: rulesData) {
                smartRules = rules
            }
        }
    }
    
    func validateName() -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            nameValidationError = "Collection name cannot be empty"
            return false
        }
        
        if trimmedName.count > 50 {
            nameValidationError = "Collection name must be 50 characters or less"
            return false
        }
        
        // Check for duplicate names (excluding current collection)
        let request: NSFetchRequest<Collection> = Collection.fetchRequest()
        request.predicate = NSPredicate(format: "name ==[cd] %@", trimmedName)
        
        if let collections = try? context.fetch(request),
           collections.first(where: { $0.id != editingCollection?.id }) != nil {
            nameValidationError = "A collection with this name already exists"
            return false
        }
        
        nameValidationError = nil
        return true
    }
    
    func save() throws {
        guard validateName() else {
            throw CollectionEditorError.validationFailed
        }
        
        let collection: Collection
        if let existing = editingCollection {
            collection = existing
        } else {
            collection = Collection(context: context)
            collection.id = UUID()
        }
        
        collection.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        collection.icon = selectedIcon
        collection.color = selectedColor
        collection.parent = selectedParent
        collection.themeConfiguration = theme
        collection.featuredConfiguration = featuredConfiguration
        collection.presentationSettings = presentationSettings
        collection.layoutMode = layoutMode
        collection.heroBookmarkID = featuredConfiguration.heroBookmarkID
        collection.headerImage = headerImageData
        collection.coverImage = coverImageData
        collection.isProject = isProject

        if isProject {
            let clampedProgress = max(0, min(projectProgress, 1))
            let trimmedSummary = projectSummary.trimmingCharacters(in: .whitespacesAndNewlines)

            collection.projectStatusValue = projectStatus
            collection.projectSummaryText = trimmedSummary
            collection.projectStartDate = projectStartDate
            collection.projectTargetDate = projectTargetDate
            if projectStatus == .completed || projectStatus == .archived {
                collection.projectCompletionDate = projectCompletionDate ?? Date()
            } else {
                collection.projectCompletionDate = nil
            }
            collection.projectProgress = clampedProgress
        } else {
            collection.projectStatusValue = .planning
            collection.projectSummaryText = ""
            collection.projectStartDate = nil
            collection.projectTargetDate = nil
            collection.projectCompletionDate = nil
            collection.setValue(nil, forKey: "projectProgressValue")
        }
        
        // Save sort order to UserDefaults
        if let collectionId = collection.id?.uuidString {
            let sortOrderKey = "collection_sortOrder_\(collectionId)"
            UserDefaults.standard.set(sortOrder.rawValue, forKey: sortOrderKey)
            
            // Save smart rules to UserDefaults
            let rulesKey = "collection_smartRules_\(collectionId)"
            if smartRules.isEnabled {
                if let data = try? JSONEncoder().encode(smartRules) {
                    UserDefaults.standard.set(data, forKey: rulesKey)
                }
            } else {
                UserDefaults.standard.removeObject(forKey: rulesKey)
            }
        }
        
        // Set sort order if needed
        if collection.sortOrder == 0 {
            let maxOrder = (try? context.fetch(Collection.fetchRequest()).map { $0.sortOrder }.max() ?? 0) ?? 0
            collection.sortOrder = maxOrder + 1
        }
        
        try coreDataManager.save()
    }
    
    func delete() throws {
        guard let collection = editingCollection else { return }
        
        // Move bookmarks to "All" (remove collection association)
        if let bookmarks = collection.bookmarks as? Set<Bookmark> {
            for bookmark in bookmarks {
                bookmark.collection = nil
                bookmark.collectionName = nil
            }
        }
        
        // Clean up UserDefaults data
        if let collectionId = collection.id?.uuidString {
            UserDefaults.standard.removeObject(forKey: "collection_sortOrder_\(collectionId)")
            UserDefaults.standard.removeObject(forKey: "collection_smartRules_\(collectionId)")
        }
        
        context.delete(collection)
        try coreDataManager.save()
    }
    
    func loadAvailableData() {
        // Load available collections (excluding self and descendants)
        let request: NSFetchRequest<Collection> = Collection.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        if let all = try? context.fetch(request) {
            // Filter out self and any descendants
            availableCollections = all.filter { collection in
                guard let editingId = editingCollection?.id else { return true }
                return collection.id != editingId && !isDescendant(of: editingId, in: collection)
            }
        }
        
        // Load available tags
        let tagRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        tagRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        if let tags = try? context.fetch(tagRequest) {
            availableTags = tags.compactMap { $0.name }
        }
    }
    
    func resetToDefaults() {
        name = ""
        selectedIcon = "folder"
        selectedColor = "#999999"
        selectedParent = nil
        sortOrder = .manual
        smartRules = SmartCollectionRules()
        nameValidationError = nil
        theme = CollectionTheme()
        featuredConfiguration = CollectionFeaturedConfiguration()
        presentationSettings = CollectionPresentationSettings()
        layoutMode = .masonry
        headerImageData = nil
        coverImageData = nil
        isProject = false
        projectStatus = .planning
        projectSummary = ""
        projectStartDate = nil
        projectTargetDate = nil
        projectCompletionDate = nil
        projectProgress = 0
    }
    
    // MARK: - Private Helpers
    
    private func isDescendant(of ancestorId: UUID, in collection: Collection) -> Bool {
        var current: Collection? = collection
        while let parent = current?.parent {
            if parent.id == ancestorId {
                return true
            }
            current = parent
        }
        return false
    }
    
    // MARK: - Preview Helper
    
    func previewCollection() -> CollectionPreview {
        return CollectionPreview(
            name: name.isEmpty ? "Collection Name" : name,
            icon: selectedIcon,
            color: selectedColor,
            bookmarkCount: 0 // Would need to calculate based on rules
        )
    }
}

struct CollectionPreview {
    let name: String
    let icon: String
    let color: String
    let bookmarkCount: Int
}

enum CollectionEditorError: LocalizedError {
    case validationFailed
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .validationFailed:
            return "Validation failed. Please check your input."
        case .saveFailed:
            return "Failed to save collection."
        }
    }
}


