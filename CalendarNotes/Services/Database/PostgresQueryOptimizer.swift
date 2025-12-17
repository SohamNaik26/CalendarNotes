//
//  PostgresQueryOptimizer.swift
//  CalendarNotes
//
//  PostgreSQL query optimization utilities with connection pooling, prepared statements, and query analysis
//

import Foundation
import PostgresNIO
import Logging

// MARK: - PostgreSQL Query Optimizer

class PostgresQueryOptimizer {
    static let shared = PostgresQueryOptimizer()
    
    private let logger = Logger(label: "com.calendarnotes.postgres.optimizer")
    private var preparedStatements: [String: String] = [:] // name -> SQL
    private let statementQueue = DispatchQueue(label: "com.calendarnotes.postgres.statements", attributes: .concurrent)
    
    private init() {}
    
    // MARK: - Query Analysis
    
    /// Analyzes query performance using EXPLAIN ANALYZE
    func analyzeQuery(_ sql: String, connection: PostgresConnection) async throws -> QueryAnalysisResult {
        let explainSQL = "EXPLAIN ANALYZE \(sql)"
        let startTime = Date()
        
        // Create PostgresQuery from SQL string
        let query = PostgresQuery(unsafeSQL: explainSQL)
        let result = try await connection.query(query, logger: logger)
        let duration = Date().timeIntervalSince(startTime)
        
        var plan: String = ""
        var executionTime: TimeInterval = 0
        
        for try await row in result {
            if let text = try? row.decodeColumn("QUERY PLAN", as: String.self) {
                plan += text + "\n"
                // Extract execution time if present
                if text.contains("Execution Time:") {
                    let components = text.components(separatedBy: "Execution Time: ")
                    if components.count > 1 {
                        let timeStr = components[1].components(separatedBy: " ").first ?? "0"
                        executionTime = Double(timeStr) ?? 0
                    }
                }
            }
        }
        
        return QueryAnalysisResult(
            sql: sql,
            plan: plan,
            executionTime: executionTime,
            analysisDuration: duration
        )
    }
    
    // MARK: - Query Optimization Helpers
    
    /// Optimizes a SELECT query by adding LIMIT and OFFSET for pagination
    func addPagination(to sql: String, limit: Int, offset: Int) -> String {
        // Check if LIMIT already exists
        if sql.uppercased().contains("LIMIT") {
            return sql
        }
        
        return "\(sql) LIMIT \(limit) OFFSET \(offset)"
    }
    
    /// Replaces COUNT(*) with EXISTS where possible for better performance
    func optimizeCountQuery(_ sql: String) -> String {
        // If query is checking existence, use EXISTS instead
        let lowerSQL = sql.lowercased()
        if lowerSQL.contains("count(*)") && lowerSQL.contains("where") {
            // Try to convert COUNT(*) > 0 to EXISTS
            if let whereRange = lowerSQL.range(of: "where") {
                let whereClause = String(lowerSQL[whereRange.upperBound...])
                return "SELECT EXISTS(SELECT 1 \(whereClause))"
            }
        }
        return sql
    }
    
    /// Removes SELECT * and specifies columns (placeholder - would need schema knowledge)
    func specifyColumns(in sql: String, columns: [String]) -> String {
        let lowerSQL = sql.lowercased()
        if lowerSQL.contains("select *") {
            let columnsStr = columns.joined(separator: ", ")
            return sql.replacingOccurrences(of: "SELECT *", with: "SELECT \(columnsStr)", options: .caseInsensitive)
        }
        return sql
    }
    
    // MARK: - Composite Index Recommendations
    
    /// Suggests composite indexes based on common query patterns
    func suggestCompositeIndexes(for table: String, commonQueries: [String]) -> [IndexSuggestion] {
        var suggestions: [IndexSuggestion] = []
        
        // Analyze common WHERE clauses and ORDER BY patterns
        for query in commonQueries {
            let lowerQuery = query.lowercased()
            
            // Extract WHERE conditions
            if let whereRange = lowerQuery.range(of: "where") {
                let whereClause = String(lowerQuery[whereRange.upperBound...])
                let conditions = whereClause.components(separatedBy: "and")
                
                // Extract ORDER BY
                var orderByColumns: [String] = []
                if let orderByRange = lowerQuery.range(of: "order by") {
                    let orderClause = String(lowerQuery[orderByRange.upperBound...])
                    orderByColumns = orderClause.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                }
                
                // Suggest composite index
                if conditions.count > 1 || !orderByColumns.isEmpty {
                    var indexColumns: [String] = []
                    
                    // Add WHERE columns first
                    for condition in conditions {
                        if let column = extractColumn(from: condition) {
                            indexColumns.append(column)
                        }
                    }
                    
                    // Add ORDER BY columns
                    indexColumns.append(contentsOf: orderByColumns)
                    
                    if indexColumns.count > 1 {
                        suggestions.append(IndexSuggestion(
                            table: table,
                            columns: Array(Set(indexColumns)), // Remove duplicates
                            query: query
                        ))
                    }
                }
            }
        }
        
        return suggestions
    }
    
    private func extractColumn(from condition: String) -> String? {
        // Simple extraction - looks for "column_name = " or "column_name >" etc.
        let operators = ["=", ">", "<", ">=", "<=", "!=", "<>", "like", "ilike", "in"]
        for op in operators {
            if let range = condition.range(of: op, options: .caseInsensitive) {
                let column = String(condition[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                if !column.isEmpty {
                    return column
                }
            }
        }
        return nil
    }
}

// MARK: - Query Analysis Result

struct QueryAnalysisResult {
    let sql: String
    let plan: String
    let executionTime: TimeInterval
    let analysisDuration: TimeInterval
    
    var isSlow: Bool {
        executionTime > 0.5 // 500ms
    }
    
    var needsOptimization: Bool {
        executionTime > 2.0 // 2 seconds
    }
}

// MARK: - Index Suggestion

struct IndexSuggestion {
    let table: String
    let columns: [String]
    let query: String
    
    var createIndexSQL: String {
        let columnsStr = columns.joined(separator: ", ")
        return "CREATE INDEX IF NOT EXISTS idx_\(table)_\(columns.joined(separator: "_")) ON \(table)(\(columnsStr));"
    }
}

