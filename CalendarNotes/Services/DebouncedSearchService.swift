//
//  DebouncedSearchService.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 23/10/25.
//

import Foundation
import Combine

// MARK: - Debounced Search Service

class DebouncedSearchService: ObservableObject {
    @Published var searchText: String = ""
    @Published var debouncedSearchText: String = ""
    
    private var cancellables = Set<AnyCancellable>()
    private let debounceDelay: TimeInterval
    
    init(debounceDelay: TimeInterval = 0.5) {
        self.debounceDelay = debounceDelay
        setupDebouncing()
    }
    
    private func setupDebouncing() {
        $searchText
            .debounce(for: .seconds(debounceDelay), scheduler: RunLoop.main)
            .removeDuplicates()
            .assign(to: \.debouncedSearchText, on: self)
            .store(in: &cancellables)
    }
    
    func clearSearch() {
        searchText = ""
        debouncedSearchText = ""
    }
    
    func updateSearchText(_ text: String) {
        searchText = text
    }
}

// MARK: - Search Result Types

struct PaginatedSearchResult<T> {
    let items: [T]
    let totalCount: Int
    let hasMore: Bool
    let page: Int
    let pageSize: Int
}

// MARK: - Generic Search Manager

class SearchManager<T>: ObservableObject {
    @Published var results: [T] = []
    @Published var isLoading: Bool = false
    @Published var error: Error?
    
    private let searchService: DebouncedSearchService
    private let searchFunction: (String, Int, Int) -> AnyPublisher<PaginatedSearchResult<T>, Error>
    private var cancellables = Set<AnyCancellable>()
    
    private var currentPage = 0
    private let pageSize = 20
    private var hasMoreResults = true
    
    init(searchService: DebouncedSearchService, searchFunction: @escaping (String, Int, Int) -> AnyPublisher<PaginatedSearchResult<T>, Error>) {
        self.searchService = searchService
        self.searchFunction = searchFunction
        setupSearch()
    }
    
    private func setupSearch() {
        searchService.$debouncedSearchText
            .sink { [weak self] searchText in
                self?.performSearch(searchText)
            }
            .store(in: &cancellables)
    }
    
    private func performSearch(_ searchText: String) {
        currentPage = 0
        hasMoreResults = true
        results = []
        
        if searchText.isEmpty {
            return
        }
        
        isLoading = true
        error = nil
        
        searchFunction(searchText, currentPage, pageSize)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] searchResult in
                    self?.results = searchResult.items
                    self?.hasMoreResults = searchResult.hasMore
                    self?.currentPage = searchResult.page
                }
            )
            .store(in: &cancellables)
    }
    
    func loadMore() {
        guard hasMoreResults && !isLoading else { return }
        
        isLoading = true
        currentPage += 1
        
        searchFunction(searchService.debouncedSearchText, currentPage, pageSize)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                        self?.currentPage -= 1 // Revert page increment on error
                    }
                },
                receiveValue: { [weak self] searchResult in
                    self?.results.append(contentsOf: searchResult.items)
                    self?.hasMoreResults = searchResult.hasMore
                    self?.currentPage = searchResult.page
                }
            )
            .store(in: &cancellables)
    }
    
    func clearResults() {
        results = []
        currentPage = 0
        hasMoreResults = true
        error = nil
    }
}
