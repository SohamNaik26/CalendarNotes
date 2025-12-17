//
//  LoadingStateView.swift
//  CalendarNotes
//
//  Created for loading state implementation
//

import SwiftUI

// MARK: - Generic Loading State View Builder

struct GenericLoadingStateView<T, Content: View, Skeleton: View>: View {
    let state: LoadingState<T>
    let content: (T) -> Content
    let skeleton: () -> Skeleton
    let retry: (() -> Void)?
    
    init(
        state: LoadingState<T>,
        @ViewBuilder content: @escaping (T) -> Content,
        @ViewBuilder skeleton: @escaping () -> Skeleton,
        retry: (() -> Void)? = nil
    ) {
        self.state = state
        self.content = content
        self.skeleton = skeleton
        self.retry = retry
    }
    
    var body: some View {
        Group {
            switch state {
            case .idle:
                EmptyView()
            case .loading:
                skeleton()
            case .loaded(let value):
                content(value)
            case .error(let error):
                ErrorView(error: error, retry: retry ?? {})
            }
        }
    }
}

// MARK: - Events Loading View

struct EventsLoadingView: View {
    let state: LoadingState<[CalendarEvent]>
    let retry: () -> Void
    
    var body: some View {
        GenericLoadingStateView(
            state: state,
            content: { events in
                if events.isEmpty {
                    EmptyView()
                } else {
                    ForEach(events, id: \.id) { event in
                        OptimizedEventRowView(event: event, colorScheme: .light)
                    }
                }
            },
            skeleton: {
                VStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in
                        EventRowSkeleton()
                    }
                }
            },
            retry: retry
        )
    }
}

// MARK: - Notes Loading View

struct NotesLoadingView: View {
    let state: LoadingState<[Note]>
    let retry: () -> Void
    
    var body: some View {
        GenericLoadingStateView(
            state: state,
            content: { notes in
                if notes.isEmpty {
                    EmptyView()
                } else {
                    ForEach(notes, id: \.id) { note in
                        NoteCardView(note: note)
                    }
                }
            },
            skeleton: {
                VStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in
                        NoteCardSkeleton()
                    }
                }
            },
            retry: retry
        )
    }
}

// MARK: - Tasks Loading View

struct TasksLoadingView: View {
    let state: LoadingState<[TodoItem]>
    let retry: () -> Void
    
    var body: some View {
        GenericLoadingStateView(
            state: state,
            content: { tasks in
                if tasks.isEmpty {
                    EmptyView()
                } else {
                    ForEach(tasks, id: \.id) { task in
                        // Task row view would go here
                        Text(task.title ?? "Untitled Task")
                    }
                }
            },
            skeleton: {
                VStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in
                        GenericSkeletonView(height: 60, cornerRadius: 8)
                    }
                }
            },
            retry: retry
        )
    }
}

// MARK: - Bookmarks Loading View

struct BookmarksLoadingView: View {
    let state: LoadingState<[Bookmark]>
    let retry: () -> Void
    let layoutMode: BookmarksViewModel.LayoutMode
    
    var body: some View {
        GenericLoadingStateView(
            state: state,
            content: { bookmarks in
                if bookmarks.isEmpty {
                    EmptyView()
                } else {
                    if layoutMode == .grid {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            ForEach(bookmarks, id: \.objectID) { bookmark in
                                // Bookmark grid item would go here
                                Text(bookmark.title ?? "Untitled")
                            }
                        }
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(bookmarks, id: \.objectID) { bookmark in
                                // Bookmark list row would go here
                                Text(bookmark.title ?? "Untitled")
                            }
                        }
                    }
                }
            },
            skeleton: {
                if layoutMode == .grid {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(0..<6, id: \.self) { _ in
                            BookmarkCardSkeleton()
                        }
                    }
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(0..<5, id: \.self) { _ in
                            BookmarkCardSkeleton()
                        }
                    }
                }
            },
            retry: retry
        )
    }
}

