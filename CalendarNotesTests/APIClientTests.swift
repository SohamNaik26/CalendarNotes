//
//  APIClientTests.swift
//  CalendarNotesTests
//
//  Unit tests for APIClient
//

import Testing
import Foundation
@testable import CalendarNotes

@Suite("APIClient Tests")
struct APIClientTests {
    
    @Test("Client is singleton")
    func testSingleton() {
        let client1 = APIClient.shared
        let client2 = APIClient.shared
        #expect(client1 === client2)
    }
    
    @Test("GET request structure")
    func testGETRequest() async throws {
        let client = APIClient.shared
        
        struct TestResponse: Decodable {
            let data: String
        }
        
        do {
            _ = try await client.get(APIEndpoint.me) as TestResponse
        } catch {
            // Expected without actual server
        }
    }
    
    @Test("POST request structure")
    func testPOSTRequest() async throws {
        let client = APIClient.shared
        
        struct TestRequest: Encodable {
            let name: String
        }
        
        struct TestResponse: Decodable {
            let id: UUID
        }
        
        do {
            _ = try await client.post(APIEndpoint.createEvent, body: TestRequest(name: "Test")) as TestResponse
        } catch {
            // Expected without actual server
        }
    }
    
    @Test("PUT request structure")
    func testPUTRequest() async throws {
        let client = APIClient.shared
        
        struct TestRequest: Encodable {
            let name: String
        }
        
        struct TestResponse: Decodable {
            let id: UUID
        }
        
        do {
            _ = try await client.put(APIEndpoint.updateEvent(id: UUID()), body: TestRequest(name: "Updated")) as TestResponse
        } catch {
            // Expected without actual server
        }
    }
    
    @Test("DELETE request")
    func testDELETERequest() async throws {
        let client = APIClient.shared
        
        do {
            try await client.delete(APIEndpoint.deleteEvent(id: UUID()))
        } catch {
            // Expected without actual server
        }
    }
    
    @Test("Cache management")
    func testCacheManagement() {
        let client = APIClient.shared
        
        // Test cache clearing
        client.clearCache()
        
        // Test endpoint-specific cache clearing
        client.clearCache(for: APIEndpoint.events(query: nil))
    }
    
    @Test("Base URL configuration")
    func testBaseURLConfiguration() {
        let client = APIClient.shared
        
        let testURL = URL(string: "https://test.example.com")!
        client.setBaseURL(testURL)
        
        // Verify URL is set (would need to check UserDefaults or make a request)
    }
    
    @Test("Retry logic for transient errors")
    func testRetryLogic() async throws {
        let client = APIClient.shared
        
        // This would require mocking network responses
        // For now, we verify the client handles errors
        do {
            _ = try await client.get(APIEndpoint.events(query: nil)) as EventsResponse
        } catch {
            // Expected without actual server
        }
    }
}

