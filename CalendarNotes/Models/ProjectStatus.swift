import Foundation
import SwiftUI

enum ProjectStatus: String, CaseIterable, Identifiable {
    case planning
    case active
    case completed
    case archived

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .planning: return "Planning"
        case .active: return "Active"
        case .completed: return "Completed"
        case .archived: return "Archived"
        }
    }

    var systemImageName: String {
        switch self {
        case .planning: return "lightbulb"
        case .active: return "bolt"
        case .completed: return "checkmark.seal"
        case .archived: return "archivebox"
        }
    }

    var color: Color {
        switch self {
        case .planning: return .blue
        case .active: return .green
        case .completed: return .purple
        case .archived: return .gray
        }
    }
}
