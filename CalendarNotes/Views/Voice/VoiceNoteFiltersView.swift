//
//  VoiceNoteFiltersView.swift
//  CalendarNotes
//
//  Created by Cursor AI on 17/11/25.
//

import SwiftUI

struct VoiceNoteFiltersView: View {
	@Binding var dateRange: ClosedRange<Date>?
	@Binding var linkedEntity: VoiceNoteSearchFilter.LinkedEntity?
	@Binding var favoritesOnly: Bool
	@Binding var includeArchived: Bool
	@Binding var collection: String?
	@Binding var tags: [String]
	
	@Environment(\.dismiss) var dismiss
	@State private var startDate = Date()
	@State private var endDate = Date()
	@State private var hasDateRange = false
	
	var body: some View {
		NavigationView {
			Form {
				Section("Date Range") {
					Toggle("Filter by Date", isOn: $hasDateRange)
					if hasDateRange {
						DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
						DatePicker("End Date", selection: $endDate, displayedComponents: .date)
					}
				}
				
				Section("Linked Entity") {
					Picker("Linked To", selection: $linkedEntity) {
						Text("Any").tag(nil as VoiceNoteSearchFilter.LinkedEntity?)
						// Note: Actual entity selection would require fetching entities
						// For now, this is a placeholder - actual implementation would need entity picker
					}
				}
				
				Section("Options") {
					Toggle("Favorites Only", isOn: $favoritesOnly)
					Toggle("Include Archived", isOn: $includeArchived)
				}
				
				Section("Collection") {
					TextField("Collection Name", text: Binding(
						get: { collection ?? "" },
						set: { collection = $0.isEmpty ? nil : $0 }
					))
				}
			}
			.navigationTitle("Filters")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") {
						dismiss()
					}
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Apply") {
						if hasDateRange {
							dateRange = startDate...endDate
						} else {
							dateRange = nil
						}
						dismiss()
					}
				}
			}
		}
	}
}

