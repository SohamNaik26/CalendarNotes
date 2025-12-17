//
//  PostgresHelpers.swift
//  CalendarNotes
//
//  Created on [Date]
//

import Foundation
import PostgresNIO

// MARK: - PostgresRow Decoding Helpers
extension PostgresRow {
    func decodeColumn<T: PostgresDecodable>(_ columnName: String, as type: T.Type) throws -> T {
        // Use makeRandomAccess() to get a PostgresRandomAccessRow for efficient column access
        let randomAccessRow = self.makeRandomAccess()
        // Access column using subscript with column name - returns PostgresCell (non-optional)
        let cell = randomAccessRow[columnName]
        // Decode the cell's data - PostgresCell decode method doesn't use 'as:' label
        return try cell.decode(type)
    }
    
    func decodeColumnOptional<T: PostgresDecodable>(_ columnName: String, as type: T.Type) -> T? {
        // Use makeRandomAccess() to get a PostgresRandomAccessRow for efficient column access
        let randomAccessRow = self.makeRandomAccess()
        // Access column using subscript with column name
        let cell = randomAccessRow[columnName]
        // Decode the cell's data - handle nil case for optional columns
        return try? cell.decode(type)
    }
}

// MARK: - PostgresData Creation Helpers
extension PostgresData {
    static func fromUUID(_ uuid: UUID) -> PostgresData {
        return PostgresData(uuid: uuid)
    }
    
    static func fromString(_ string: String) -> PostgresData {
        return PostgresData(string: string)
    }
    
    static func fromInt(_ int: Int) -> PostgresData {
        return PostgresData(int: int)
    }
    
    static func fromDouble(_ double: Double) -> PostgresData {
        return PostgresData(double: double)
    }
    
    static func fromBool(_ bool: Bool) -> PostgresData {
        return PostgresData(bool: bool)
    }
    
    static func fromDate(_ date: Date) -> PostgresData {
        return PostgresData(date: date)
    }
    
    static func fromOptionalString(_ string: String?) -> PostgresData {
        guard let string = string else { return .null }
        return PostgresData(string: string)
    }
    
    static func fromOptionalUUID(_ uuid: UUID?) -> PostgresData {
        guard let uuid = uuid else { return .null }
        return PostgresData(uuid: uuid)
    }
    
    static func fromOptionalDate(_ date: Date?) -> PostgresData {
        guard let date = date else { return .null }
        return PostgresData(date: date)
    }
    
    static func fromJSONB(_ json: [String: Any]) -> PostgresData? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: json) else {
            return nil
        }
        return PostgresData(jsonb: jsonData)
    }
    
    static func fromStringArray(_ array: [String]) -> PostgresData {
        // Use PostgresBindings for arrays instead of deprecated PostgresData(array:)
        var bindings = PostgresBindings()
        for item in array {
            bindings.append(PostgresData(string: item))
        }
        // For array parameters, we'll need to handle this differently in queries
        // For now, return the first item as a workaround - this should be handled in the query itself
        return array.isEmpty ? .null : PostgresData(string: array.joined(separator: ","))
    }
}

