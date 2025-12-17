//
//  VoiceNotesListView.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import SwiftUI
import AVFoundation

struct VoiceNotesListView: View {
	@State private var search: String = ""
	@State private var filterWithTranscription: Bool = false
	@State private var sort: Sort = .dateDesc
	@State private var notes: [VoiceNote] = []
	@State private var playingId: UUID?
	@State private var dateRange: ClosedRange<Date>?
	@State private var selectedLinkedEntity: VoiceNoteSearchFilter.LinkedEntity?
	@State private var favoritesOnly: Bool = false
	@State private var includeArchived: Bool = true
	@State private var selectedCollection: String?
	@State private var selectedTags: [String] = []
	@State private var showingFilters = false
	
	enum Sort: String, CaseIterable, Identifiable {
		case dateDesc = "Date (newest)"
		case dateAsc = "Date (oldest)"
		case duration = "Duration"
		case name = "Name"
		var id: String { rawValue }
	}
	
	var filtered: [VoiceNote] {
		do {
			var filter = VoiceNoteSearchFilter()
			filter.query = search
			filter.dateRange = dateRange
			filter.linkedEntity = selectedLinkedEntity
			filter.favoritesOnly = favoritesOnly
			filter.includeArchived = includeArchived
			filter.collectionName = selectedCollection
			filter.tags = selectedTags
			
			let results: [VoiceNote]
			if filterWithTranscription {
				// Filter by transcription in post-processing since repository doesn't support this directly
				let allResults = try VoiceNoteRepository.shared.fetchVoiceNotes(filter: filter)
				results = allResults.filter { ($0.transcription ?? "").isEmpty == false }
			} else {
				results = try VoiceNoteRepository.shared.fetchVoiceNotes(filter: filter)
			}
			switch sort {
			case .dateDesc: return results.sorted { $0.createdAt > $1.createdAt }
			case .dateAsc: return results.sorted { $0.createdAt < $1.createdAt }
			case .duration: return results.sorted { $0.duration > $1.duration }
			case .name: return results.sorted { $0.audioFileURL.lastPathComponent < $1.audioFileURL.lastPathComponent }
			}
		} catch {
			print("Filter error: \(error)")
			return []
		}
	}
	
	var body: some View {
		NavigationStack {
			List {
				ForEach(filtered) { note in
					NavigationLink {
						VoiceNoteDetailView(note: note)
					} label: {
						VoiceNoteRow(note: note, isPlaying: note.id == playingId)
							.contextMenu {
								Button("Play") {
									playingId = note.id
								}
								if let transcription = note.transcription {
									Button("Copy Transcription") {
										#if os(iOS)
										UIPasteboard.general.string = transcription
										#else
										NSPasteboard.general.clearContents()
										NSPasteboard.general.setString(transcription, forType: .string)
										#endif
									}
								}
							}
					}
					.swipeActions(edge: .trailing, allowsFullSwipe: false) {
						Button {
							// Transcribe action to be wired
						} label: {
							Label("Transcribe", systemImage: "waveform")
						}
						.tint(.purple)
						
						Button(role: .destructive) {
							try? FileManager.default.removeItem(at: note.audioFileURL)
							notes.removeAll { $0.id == note.id }
						} label: {
							Label("Delete", systemImage: "trash")
						}
					}
					.swipeActions(edge: .leading, allowsFullSwipe: false) {
						Button {
							// Share
							#if os(iOS)
							let av = UIActivityViewController(activityItems: [note.audioFileURL], applicationActivities: nil)
							UIApplication.shared.keyWindowPresentedController?.present(av, animated: true)
							#endif
						} label: {
							Label("Share", systemImage: "square.and.arrow.up")
						}
						.tint(.blue)
					}
				}
			}
			.searchable(text: $search, prompt: "Search transcriptions...")
			.toolbar {
				#if os(iOS)
				let placement: ToolbarItemPlacement = .navigationBarTrailing
				#else
				let placement: ToolbarItemPlacement = .automatic
				#endif
				ToolbarItem(placement: placement) {
					Menu {
						Toggle("With transcription", isOn: $filterWithTranscription)
						Picker("Sort", selection: $sort) {
							ForEach(Sort.allCases) { s in
								Text(s.rawValue).tag(s)
							}
						}
						Divider()
						Button("Filters") {
							showingFilters = true
						}
					} label: {
						Image(systemName: "line.3.horizontal.decrease.circle")
					}
				}
			}
			.sheet(isPresented: $showingFilters) {
				VoiceNoteFiltersView(
					dateRange: $dateRange,
					linkedEntity: $selectedLinkedEntity,
					favoritesOnly: $favoritesOnly,
					includeArchived: $includeArchived,
					collection: $selectedCollection,
					tags: $selectedTags
				)
			}
			.navigationTitle("Voice Notes")
			.onAppear {
				loadNotes()
			}
			.onChange(of: search) { _, _ in
				// Auto-refresh on search change
			}
		}
	}
	
	private func loadNotes() {
		do {
			notes = try VoiceNoteRepository.shared.fetchVoiceNotes()
		} catch {
			print("Failed to load voice notes: \(error)")
		}
	}
}

private struct VoiceNoteRow: View {
	let note: VoiceNote
	let isPlaying: Bool
	var body: some View {
		HStack(spacing: 12) {
			WaveformShape(samples: demoSamples(for: note), lineWidth: 2)
				.fill(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
				.frame(width: 64, height: 32)
				.opacity(0.8)
			VStack(alignment: .leading, spacing: 4) {
				Text(note.audioFileURL.lastPathComponent)
					.lineLimit(1)
				if let txt = note.transcription, !txt.isEmpty {
					Text(txt)
						.lineLimit(2)
						.font(.caption)
						.foregroundColor(.secondary)
				}
			}
			Spacer()
			VStack(alignment: .trailing, spacing: 4) {
				Text(formatDuration(note.duration))
					.font(.caption)
					.padding(.horizontal, 6)
					.padding(.vertical, 2)
					.background(Color.cnSecondaryBackground)
					.clipShape(Capsule())
				Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
					.font(.caption2)
					.foregroundColor(.secondary)
			}
		}
	}
	private func formatDuration(_ t: TimeInterval) -> String {
		let s = Int(t)
		return String(format: "%d:%02d", s/60, s%60)
	}
	private func demoSamples(for _: VoiceNote) -> [CGFloat] {
		// Placeholder tiny waveform thumbnail
		return (0..<24).map { i in
			let v = sin(Double(i) / 5.0) * 0.5 + 0.5
			return CGFloat(v)
		}
	}
}

#if os(iOS)
extension UIApplication {
	var keyWindowPresentedController: UIViewController? {
		connectedScenes
			.compactMap { $0 as? UIWindowScene }
			.flatMap { $0.windows }
			.first { $0.isKeyWindow }?
			.rootViewController?.presentedViewController ?? connectedScenes
			.compactMap { $0 as? UIWindowScene }
			.flatMap { $0.windows }
			.first { $0.isKeyWindow }?
			.rootViewController
	}
}
#endif


