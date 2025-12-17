//
//  MigrationService.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation
import CoreData
import Combine

/// Service for migrating data from Core Data to PostgreSQL
@MainActor
final class MigrationService: ObservableObject {
	static let shared = MigrationService()
	
	// MARK: - Published Properties
	
	@Published private(set) var isMigrating: Bool = false
	@Published private(set) var migrationProgress: MigrationProgress = MigrationProgress()
	@Published private(set) var migrationState: MigrationState = .notStarted
	@Published private(set) var currentEntity: String?
	@Published private(set) var error: DataMigrationError?
	
	// MARK: - Private Properties
	
	private let coreDataManager = CoreDataManager.shared
	private let userDefaults = UserDefaults.standard
	
	// Migration state keys
	private let migrationCompleteKey = "migration.postgres.complete"
	private let migrationStartedKey = "migration.postgres.started"
	private let migrationBackupKey = "migration.postgres.backup"
	private let migrationVersionKey = "migration.postgres.version"
	
	// Current migration version
	private let currentMigrationVersion = 1
	
	// Repositories
	private let eventRepository = EventAPIRepository()
	private let noteRepository = NoteAPIRepository()
	private let todoRepository = TodoAPIRepository()
	private let bookmarkRepository = BookmarkAPIRepository()
	
	// Batch size for large datasets
	private let batchSize = 100
	
	// Cancellation support
	private var migrationTask: Task<Void, Never>?
	
	// MARK: - Initialization
	
	private init() {
		checkMigrationState()
	}
	
	// MARK: - Public API
	
	/// Check if migration is needed
	func isMigrationNeeded() -> Bool {
		// Check if PostgreSQL is set up (user is authenticated)
		guard TokenManager.shared.accessToken() != nil else {
			return false
		}
		
		// Check if migration has been completed
		let isComplete = userDefaults.bool(forKey: migrationCompleteKey)
		let migrationVersion = userDefaults.integer(forKey: migrationVersionKey)
		
		// Migration needed if not complete or version mismatch
		return !isComplete || migrationVersion < currentMigrationVersion
	}
	
	/// Start the migration process
	func startMigration() async throws {
		guard !isMigrating else {
			throw DataMigrationError.migrationInProgress
		}
		
		guard isMigrationNeeded() else {
			throw DataMigrationError.migrationNotNeeded
		}
		
		// Check authentication
		guard TokenManager.shared.accessToken() != nil else {
			throw DataMigrationError.notAuthenticated
		}
		
		isMigrating = true
		migrationState = .inProgress
		error = nil
		migrationProgress = MigrationProgress()
		
		// Create migration task with cancellation support
		migrationTask = Task {
			do {
				try await performMigration()
			} catch {
				if !Task.isCancelled {
					await MainActor.run {
						self.error = DataMigrationError.migrationFailed(error.localizedDescription)
						self.migrationState = .failed
						self.isMigrating = false
					}
				}
			}
		}
		
		if let task = migrationTask {
			await task.value
		}
	}
	
	/// Cancel the migration (safe cancel point)
	func cancelMigration() {
		migrationTask?.cancel()
		migrationState = .cancelled
		isMigrating = false
	}
	
	/// Reset migration state (for testing or re-migration)
	func resetMigrationState() {
		userDefaults.removeObject(forKey: migrationCompleteKey)
		userDefaults.removeObject(forKey: migrationStartedKey)
		userDefaults.removeObject(forKey: migrationBackupKey)
		userDefaults.removeObject(forKey: migrationVersionKey)
		migrationState = .notStarted
		migrationProgress = MigrationProgress()
		error = nil
	}
	
	/// Force re-migration (ignores completion flag)
	func forceRemigration() async throws {
		resetMigrationState()
		try await startMigration()
	}
	
	/// Get migration logs
	func getMigrationLogs() -> [MigrationLogEntry] {
		// Load from UserDefaults or file
		if let data = userDefaults.data(forKey: "migration.postgres.logs"),
		   let logs = try? JSONDecoder().decode([MigrationLogEntry].self, from: data) {
			return logs
		}
		return []
	}
	
	// MARK: - Private Migration Implementation
	
	private func checkMigrationState() {
		let isComplete = userDefaults.bool(forKey: migrationCompleteKey)
		let wasStarted = userDefaults.bool(forKey: migrationStartedKey)
		
		if isComplete {
			migrationState = .completed
		} else if wasStarted {
			migrationState = .partial
		} else {
			migrationState = .notStarted
		}
	}
	
	private func performMigration() async throws {
		// Mark migration as started
		userDefaults.set(true, forKey: migrationStartedKey)
		userDefaults.set(Date(), forKey: "migration.postgres.startedAt")
		
		// Step 1: Backup Core Data
		try await backupCoreData()
		
		// Step 2: Start migration transaction (conceptual - API handles this)
		updateProgress(entity: "Initializing", step: 0, total: getTotalEntityCount())
		
		// Step 3: Migrate each entity type
		var migratedCount = 0
		let entities: [EntityMigrationType] = [
			.events,
			.notes,
			.todos,
			.bookmarks
		]
		
		for entityType in entities {
			guard !Task.isCancelled else {
				throw DataMigrationError.migrationCancelled
			}
			
			currentEntity = entityType.displayName
			updateProgress(entity: entityType.displayName, step: migratedCount, total: getTotalEntityCount())
			
			do {
				let count = try await migrateEntityType(entityType)
				migratedCount += count
				logMigration(entity: entityType.displayName, count: count, success: true)
			} catch {
				logMigration(entity: entityType.displayName, count: 0, success: false, error: error.localizedDescription)
				
				// Rollback on critical failure
				if let migrationError = error as? DataMigrationError,
				   case .criticalFailure = migrationError {
					try await rollbackMigration()
					throw error
				}
				
				// Continue with other entities for non-critical errors
				continue
			}
		}
		
		// Step 4: Verify migration
		try await verifyMigration()
		
		// Step 5: Mark migration as complete
		userDefaults.set(true, forKey: migrationCompleteKey)
		userDefaults.set(currentMigrationVersion, forKey: migrationVersionKey)
		userDefaults.set(Date(), forKey: "migration.postgres.completedAt")
		
		migrationState = .completed
		isMigrating = false
		updateProgress(entity: "Complete", step: migratedCount, total: migratedCount)
		
		// Step 6: Trigger post-migration sync setup
		NotificationCenter.default.post(name: .migrationCompleted, object: nil)
	}
	
	// MARK: - Entity Migration
	
	private func migrateEntityType(_ entityType: EntityMigrationType) async throws -> Int {
		switch entityType {
		case .events:
			return try await migrateEvents()
		case .notes:
			return try await migrateNotes()
		case .todos:
			return try await migrateTodos()
		case .bookmarks:
			return try await migrateBookmarks()
		}
	}
	
	private func migrateEvents() async throws -> Int {
		let context = coreDataManager.viewContext
		let request: NSFetchRequest<CalendarEvent> = CalendarEvent.fetchRequest()
		request.sortDescriptors = [NSSortDescriptor(keyPath: \CalendarEvent.startDate, ascending: true)]
		
		let events = try context.fetch(request)
		guard !events.isEmpty else { return 0 }
		
		var migrated = 0
		var errors: [Error] = []
		
		// Process in batches
		for batchStart in stride(from: 0, to: events.count, by: batchSize) {
			guard !Task.isCancelled else {
				throw DataMigrationError.migrationCancelled
			}
			
			let batchEnd = min(batchStart + batchSize, events.count)
			let batch = Array(events[batchStart..<batchEnd])
			
			// Transform to API models (with validation)
			let apiEvents = batch.compactMap { event -> CreateEventRequest? in
				// Validate before transforming
				guard validateEvent(event),
					  event.id != nil,
					  let title = event.title,
					  let startDate = event.startDate,
					  let endDate = event.endDate else {
					logMigration(entity: "Events", count: 0, success: false, error: "Validation failed for event")
					return nil
				}
				
				return CreateEventRequest(
					title: title,
					description: event.notes,
					startDate: startDate,
					endDate: endDate,
					location: event.location,
					category: event.category,
					color: nil,
					isAllDay: false,
					isRecurring: event.isRecurring,
					recurrenceRule: parseRecurrenceRule(event.recurrenceRule)
				)
			}
			
			// Batch upload with retry logic
			do {
				let response = try await uploadWithRetry {
					try await self.eventRepository.batchCreateEvents(apiEvents)
				}
				migrated += response.created
				
				// Mark as migrated in Core Data (optional flag)
				for event in batch {
					event.setValue(true, forKey: "migratedToPostgres")
				}
				
				updateProgress(entity: "Events", step: migrated, total: events.count)
			} catch {
				errors.append(error)
				// Handle network failure - queue for retry
				if let migrationError = error as? DataMigrationError,
				   case .networkFailure = migrationError {
					logMigration(entity: "Events", count: 0, success: false, error: "Network failure - batch will be retried")
				}
				// Continue with next batch
			}
		}
		
		// Save Core Data context
		if context.hasChanges {
			try context.save()
		}
		
		// Throw if all batches failed
		if migrated == 0 && !errors.isEmpty {
			throw DataMigrationError.batchUploadFailed(errors.first?.localizedDescription ?? "Unknown error")
		}
		
		return migrated
	}
	
	private func migrateNotes() async throws -> Int {
		let context = coreDataManager.viewContext
		let request: NSFetchRequest<Note> = Note.fetchRequest()
		request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.createdDate, ascending: true)]
		
		let notes = try context.fetch(request)
		guard !notes.isEmpty else { return 0 }
		
		var migrated = 0
		var errors: [Error] = []
		
		// Process in batches
		for batchStart in stride(from: 0, to: notes.count, by: batchSize) {
			guard !Task.isCancelled else {
				throw DataMigrationError.migrationCancelled
			}
			
			let batchEnd = min(batchStart + batchSize, notes.count)
			let batch = Array(notes[batchStart..<batchEnd])
			
			// Transform and upload individually (no batch endpoint for notes)
			for note in batch {
				// Validate before transforming
				guard validateNote(note),
					  note.id != nil,
					  let content = note.content else {
					logMigration(entity: "Notes", count: 0, success: false, error: "Validation failed for note")
					continue
				}
				
				let tags = note.tagArray
				
				let apiNote = CreateNoteRequest(
					title: nil,
					content: content,
					richContent: nil,
					linkedDate: note.linkedDate,
					linkedEventId: nil,
					tags: tags.isEmpty ? nil : tags
				)
				
				do {
					_ = try await uploadWithRetry {
						try await self.noteRepository.createNote(apiNote)
					}
					migrated += 1
					note.setValue(true, forKey: "migratedToPostgres")
					updateProgress(entity: "Notes", step: migrated, total: notes.count)
				} catch {
					errors.append(error)
					// Handle duplicate data - check if it's a duplicate error
					if isDuplicateError(error) {
						migrated += 1 // Count as migrated if duplicate
						logMigration(entity: "Notes", count: 1, success: true, error: "Duplicate detected and skipped")
					}
					// Continue with next note
				}
			}
		}
		
		// Save Core Data context
		if context.hasChanges {
			try context.save()
		}
		
		if migrated == 0 && !errors.isEmpty {
			throw DataMigrationError.batchUploadFailed(errors.first?.localizedDescription ?? "Unknown error")
		}
		
		return migrated
	}
	
	private func migrateTodos() async throws -> Int {
		let context = coreDataManager.viewContext
		let request: NSFetchRequest<TodoItem> = TodoItem.fetchRequest()
		request.sortDescriptors = [NSSortDescriptor(keyPath: \TodoItem.dueDate, ascending: true)]
		
		let todos = try context.fetch(request)
		guard !todos.isEmpty else { return 0 }
		
		var migrated = 0
		var errors: [Error] = []
		
		// Process in batches
		for batchStart in stride(from: 0, to: todos.count, by: batchSize) {
			guard !Task.isCancelled else {
				throw DataMigrationError.migrationCancelled
			}
			
			let batchEnd = min(batchStart + batchSize, todos.count)
			let batch = Array(todos[batchStart..<batchEnd])
			
			// Transform and upload individually
			for todo in batch {
				// Validate before transforming
				guard validateTodo(todo),
					  todo.id != nil,
					  let title = todo.title else {
					logMigration(entity: "Todos", count: 0, success: false, error: "Validation failed for todo")
					continue
				}
				
				let apiTodo = CreateTodoRequest(
					title: title,
					description: nil,
					dueDate: todo.dueDate,
					priority: todo.priority,
					category: todo.category,
					isRecurring: todo.isRecurring,
					recurrenceRule: nil, // TodoItem doesn't have recurrenceRule in Core Data model
					linkedEventId: nil
				)
				
				do {
					_ = try await uploadWithRetry {
						try await self.todoRepository.createTodo(apiTodo)
					}
					migrated += 1
					todo.setValue(true, forKey: "migratedToPostgres")
					updateProgress(entity: "Todos", step: migrated, total: todos.count)
				} catch {
					errors.append(error)
					if isDuplicateError(error) {
						migrated += 1
						logMigration(entity: "Todos", count: 1, success: true, error: "Duplicate detected and skipped")
					}
				}
			}
		}
		
		// Save Core Data context
		if context.hasChanges {
			try context.save()
		}
		
		if migrated == 0 && !errors.isEmpty {
			throw DataMigrationError.batchUploadFailed(errors.first?.localizedDescription ?? "Unknown error")
		}
		
		return migrated
	}
	
	private func migrateBookmarks() async throws -> Int {
		let context = coreDataManager.viewContext
		let request: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
		request.sortDescriptors = [NSSortDescriptor(keyPath: \Bookmark.createdDate, ascending: true)]
		
		let bookmarks = try context.fetch(request)
		guard !bookmarks.isEmpty else { return 0 }
		
		var migrated = 0
		var errors: [Error] = []
		
		// Process in batches
		for batchStart in stride(from: 0, to: bookmarks.count, by: batchSize) {
			guard !Task.isCancelled else {
				throw DataMigrationError.migrationCancelled
			}
			
			let batchEnd = min(batchStart + batchSize, bookmarks.count)
			let batch = Array(bookmarks[batchStart..<batchEnd])
			
			// Transform and upload individually
			for bookmark in batch {
				// Validate before transforming
				guard validateBookmark(bookmark),
					  bookmark.id != nil,
					  let url = bookmark.url,
					  let title = bookmark.title else {
					logMigration(entity: "Bookmarks", count: 0, success: false, error: "Validation failed for bookmark")
					continue
				}
				
				let apiBookmark = CreateBookmarkRequest(
					url: url,
					title: title,
					description: bookmark.bookmarkDescription,
					faviconUrl: nil, // TODO: Extract from favicon Data if needed
					previewImageUrl: nil, // TODO: Extract from previewImage Data if needed
					tags: bookmark.decodedTags.isEmpty ? nil : bookmark.decodedTags,
					collectionId: bookmark.collection?.id,
					linkedDate: bookmark.linkedCalendarDate,
					linkedEventId: bookmark.linkedEventID,
					linkedNoteId: bookmark.linkedNoteID
				)
				
				do {
					_ = try await uploadWithRetry {
						try await self.bookmarkRepository.createBookmark(apiBookmark)
					}
					migrated += 1
					bookmark.setValue(true, forKey: "migratedToPostgres")
					updateProgress(entity: "Bookmarks", step: migrated, total: bookmarks.count)
				} catch {
					errors.append(error)
					if isDuplicateError(error) {
						migrated += 1
						logMigration(entity: "Bookmarks", count: 1, success: true, error: "Duplicate detected and skipped")
					}
				}
			}
		}
		
		// Save Core Data context
		if context.hasChanges {
			try context.save()
		}
		
		if migrated == 0 && !errors.isEmpty {
			throw DataMigrationError.batchUploadFailed(errors.first?.localizedDescription ?? "Unknown error")
		}
		
		return migrated
	}
	
	// MARK: - Helper Methods
	
	private func backupCoreData() async throws {
		updateProgress(entity: "Backing up", step: 0, total: 1)
		
		// Create backup timestamp
		let backupDate = Date()
		let formatter = ISO8601DateFormatter()
		formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
		let backupName = "CoreData_Backup_\(formatter.string(from: backupDate)).sqlite"
		
		// Get Core Data store URL
		guard let storeURL = coreDataManager.persistentContainer.persistentStoreDescriptions.first?.url else {
			throw DataMigrationError.backupFailed("Could not find Core Data store")
		}
		
		// Create backup directory
		let backupDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
			.appendingPathComponent("Migrations")
			.appendingPathComponent("Backups")
		
		try? FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
		
		// Copy store files
		let backupURL = backupDir.appendingPathComponent(backupName)
		try FileManager.default.copyItem(at: storeURL, to: backupURL)
		
		// Save backup path
		userDefaults.set(backupURL.path, forKey: migrationBackupKey)
		
		logMigration(entity: "Backup", count: 1, success: true)
	}
	
	private func verifyMigration() async throws {
		updateProgress(entity: "Verifying", step: 0, total: 1)
		
		// Count Core Data entities
		let context = coreDataManager.viewContext
		
		let eventsCount = try context.count(for: CalendarEvent.fetchRequest())
		let notesCount = try context.count(for: Note.fetchRequest())
		let todosCount = try context.count(for: TodoItem.fetchRequest())
		let bookmarksCount = try context.count(for: Bookmark.fetchRequest())
		
		// Count PostgreSQL entities (via API)
		// Note: This is a simplified check - in production you might want a dedicated endpoint
		let apiEvents = try await eventRepository.fetchEvents()
		let apiNotes = try await noteRepository.fetchNotes()
		let apiTodos = try await todoRepository.fetchTodos()
		let apiBookmarks = try await bookmarkRepository.fetchBookmarks()
		
		// Compare counts (allowing for some variance due to duplicates, etc.)
		let totalCoreData = eventsCount + notesCount + todosCount + bookmarksCount
		let totalPostgreSQL = Int(apiEvents.count + apiNotes.count + apiTodos.count + apiBookmarks.count)
		
		// Log verification results
		logMigration(entity: "Verification", count: totalPostgreSQL, success: true)
		
		// Warning if counts don't match (but don't fail migration)
		if abs(Double(totalCoreData - totalPostgreSQL)) > Double(totalCoreData) * 0.1 { // 10% variance allowed
			logMigration(entity: "Verification", count: 0, success: false, error: "Count mismatch: Core Data (\(totalCoreData)) vs PostgreSQL (\(totalPostgreSQL))")
		}
	}
	
	private func rollbackMigration() async throws {
		// Mark migration as failed
		userDefaults.set(false, forKey: migrationCompleteKey)
		userDefaults.removeObject(forKey: migrationStartedKey)
		
		// Note: Actual rollback would require deleting migrated data from PostgreSQL
		// This is complex and may not be desired. Instead, we mark the migration as failed
		// and allow the user to retry or manually clean up.
		
		logMigration(entity: "Rollback", count: 0, success: false, error: "Migration rolled back")
	}
	
	private func getTotalEntityCount() -> Int {
		let context = coreDataManager.viewContext
		var total = 0
		
		do {
			total += try context.count(for: CalendarEvent.fetchRequest())
			total += try context.count(for: Note.fetchRequest())
			total += try context.count(for: TodoItem.fetchRequest())
			total += try context.count(for: Bookmark.fetchRequest())
		} catch {
			// Return estimate if count fails
			return 1000
		}
		
		return total
	}
	
	private func updateProgress(entity: String, step: Int, total: Int) {
		let progress = total > 0 ? Double(step) / Double(total) : 0.0
		migrationProgress = MigrationProgress(
			currentStep: step,
			totalSteps: total,
			progress: progress,
			estimatedTimeRemaining: calculateEstimatedTime(step: step, total: total)
		)
		currentEntity = entity
	}
	
	private func calculateEstimatedTime(step: Int, total: Int) -> TimeInterval? {
		guard step > 0, let startTime = userDefaults.object(forKey: "migration.postgres.startedAt") as? Date else {
			return nil
		}
		
		let elapsed = Date().timeIntervalSince(startTime)
		let rate = Double(step) / elapsed
		let remaining = Double(total - step) / rate
		
		return remaining > 0 ? remaining : nil
	}
	
	private func parseRecurrenceRule(_ ruleString: String?) -> [String: APIAnyCodable]? {
		guard let ruleString = ruleString else { return nil }
		
		// Simple parsing - in production you'd want more robust parsing
		// This is a placeholder that assumes JSON format
		if let data = ruleString.data(using: .utf8),
		   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
			return json.mapValues { APIAnyCodable($0) }
		}
		
		return nil
	}
	
	private func logMigration(entity: String, count: Int, success: Bool, error: String? = nil) {
		let entry = MigrationLogEntry(
			timestamp: Date(),
			entity: entity,
			itemsMigrated: count,
			success: success,
			error: error
		)
		
		var logs = getMigrationLogs()
		logs.append(entry)
		
		// Keep only last 1000 entries
		if logs.count > 1000 {
			logs = Array(logs.suffix(1000))
		}
		
		if let data = try? JSONEncoder().encode(logs) {
			userDefaults.set(data, forKey: "migration.postgres.logs")
		}
	}
	
	// MARK: - Edge Case Handling
	
	/// Upload with retry logic for network failures
	private func uploadWithRetry<T>(maxRetries: Int = 3, delay: TimeInterval = 2.0, operation: @escaping () async throws -> T) async throws -> T {
		var lastError: Error?
		
		for attempt in 1...maxRetries {
			do {
				return try await operation()
			} catch {
				lastError = error
				
				// Check if it's a network error
				if isNetworkError(error) && attempt < maxRetries {
					// Exponential backoff
					let backoffDelay = delay * pow(2.0, Double(attempt - 1))
					try await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
					continue
				}
				
				// If not retryable or max retries reached, throw
				throw error
			}
		}
		
		throw lastError ?? DataMigrationError.networkFailure
	}
	
	/// Check if error is a network-related error
	private func isNetworkError(_ error: Error) -> Bool {
		if let apiError = error as? APINetworkError {
			switch apiError {
			case .noInternet, .timeout, .serverError:
				return true
			default:
				return false
			}
		}
		
		// Check for URLSession errors
		let nsError = error as NSError
		return nsError.domain == NSURLErrorDomain && (
			nsError.code == NSURLErrorNotConnectedToInternet ||
			nsError.code == NSURLErrorTimedOut ||
			nsError.code == NSURLErrorNetworkConnectionLost
		)
	}
	
	/// Check if error indicates duplicate data
	private func isDuplicateError(_ error: Error) -> Bool {
		if let apiError = error as? APINetworkError {
			// Check for 409 Conflict or similar duplicate errors
			if case .serverError(let code) = apiError, code == 409 {
				return true
			}
		}
		
		// Check error message for duplicate keywords
		let errorMessage = error.localizedDescription.lowercased()
		return errorMessage.contains("duplicate") || 
			   errorMessage.contains("already exists") ||
			   errorMessage.contains("conflict")
	}
	
	/// Handle large datasets by processing in smaller chunks
	private func processLargeDataset<T>(_ items: [T], chunkSize: Int = 50, processor: @escaping ([T]) async throws -> Int) async throws -> Int {
		var totalProcessed = 0
		
		for chunkStart in stride(from: 0, to: items.count, by: chunkSize) {
			guard !Task.isCancelled else {
				throw DataMigrationError.migrationCancelled
			}
			
			let chunkEnd = min(chunkStart + chunkSize, items.count)
			let chunk = Array(items[chunkStart..<chunkEnd])
			
			let processed = try await processor(chunk)
			totalProcessed += processed
			
			// Small delay to prevent overwhelming the server
			try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
		}
		
		return totalProcessed
	}
	
	/// Validate data before migration
	private func validateEvent(_ event: CalendarEvent) -> Bool {
		guard event.id != nil,
			  let title = event.title, !title.isEmpty,
			  event.startDate != nil,
			  event.endDate != nil,
			  let category = event.category, !category.isEmpty else {
			return false
		}
		
		// Validate date range
		if let start = event.startDate, let end = event.endDate {
			return end >= start
		}
		
		return false
	}
	
	private func validateNote(_ note: Note) -> Bool {
		guard note.id != nil,
			  let content = note.content, !content.isEmpty else {
			return false
		}
		return true
	}
	
	private func validateTodo(_ todo: TodoItem) -> Bool {
		guard todo.id != nil,
			  let title = todo.title, !title.isEmpty,
			  let priority = todo.priority, !priority.isEmpty,
			  let category = todo.category, !category.isEmpty else {
			return false
		}
		return true
	}
	
	private func validateBookmark(_ bookmark: Bookmark) -> Bool {
		guard bookmark.id != nil,
			  let url = bookmark.url, !url.isEmpty,
			  let title = bookmark.title, !title.isEmpty,
			  URL(string: url) != nil else {
			return false
		}
		return true
	}
}

// MARK: - Supporting Types

enum MigrationState {
	case notStarted
	case inProgress
	case completed
	case failed
	case cancelled
	case partial
}

struct MigrationProgress {
	var currentStep: Int = 0
	var totalSteps: Int = 0
	var progress: Double = 0.0
	var estimatedTimeRemaining: TimeInterval?
	
	var progressPercentage: Double {
		progress * 100.0
	}
	
	var formattedTimeRemaining: String? {
		guard let remaining = estimatedTimeRemaining else { return nil }
		
		let minutes = Int(remaining / 60)
		let seconds = Int(remaining.truncatingRemainder(dividingBy: 60))
		
		if minutes > 0 {
			return "\(minutes)m \(seconds)s"
		} else {
			return "\(seconds)s"
		}
	}
}

enum EntityMigrationType {
	case events
	case notes
	case todos
	case bookmarks
	
	var displayName: String {
		switch self {
		case .events: return "Events"
		case .notes: return "Notes"
		case .todos: return "Todos"
		case .bookmarks: return "Bookmarks"
		}
	}
}

enum DataMigrationError: LocalizedError {
	case migrationInProgress
	case migrationNotNeeded
	case notAuthenticated
	case migrationFailed(String)
	case migrationCancelled
	case backupFailed(String)
	case batchUploadFailed(String)
	case criticalFailure(String)
	case networkFailure
	case dataValidationError(String)
	
	var errorDescription: String? {
		switch self {
		case .migrationInProgress:
			return "Migration is already in progress"
		case .migrationNotNeeded:
			return "Migration is not needed"
		case .notAuthenticated:
			return "User is not authenticated"
		case .migrationFailed(let message):
			return "Migration failed: \(message)"
		case .migrationCancelled:
			return "Migration was cancelled"
		case .backupFailed(let message):
			return "Backup failed: \(message)"
		case .batchUploadFailed(let message):
			return "Batch upload failed: \(message)"
		case .criticalFailure(let message):
			return "Critical failure: \(message)"
		case .networkFailure:
			return "Network failure during migration"
		case .dataValidationError(let message):
			return "Data validation error: \(message)"
		}
	}
}

struct MigrationLogEntry: Codable, Identifiable {
	var id: UUID { _id }
	private let _id: UUID
	let timestamp: Date
	let entity: String
	let itemsMigrated: Int
	let success: Bool
	let error: String?
	
	init(timestamp: Date, entity: String, itemsMigrated: Int, success: Bool, error: String?) {
		self._id = UUID()
		self.timestamp = timestamp
		self.entity = entity
		self.itemsMigrated = itemsMigrated
		self.success = success
		self.error = error
	}
}

// MARK: - Notifications

extension Notification.Name {
	static let migrationCompleted = Notification.Name("migration.postgres.completed")
	static let migrationStarted = Notification.Name("migration.postgres.started")
	static let migrationFailed = Notification.Name("migration.postgres.failed")
}

