//
//  Validation.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation

enum PasswordStrength: String {
	case weak, medium, strong
}

enum Validation {
	static func isValidEmail(_ email: String) -> Bool {
		let pattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
		return email.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
	}
	
	static func passwordStrength(_ password: String) -> PasswordStrength {
		let length = password.count
		let hasLetters = password.range(of: #"[A-Za-z]"#, options: .regularExpression) != nil
		let hasDigits = password.range(of: #"\d"#, options: .regularExpression) != nil
		let hasSymbols = password.range(of: #"[^\w\s]"#, options: .regularExpression) != nil
		let score = (length >= 12 ? 2 : length >= 8 ? 1 : 0) + (hasLetters ? 1 : 0) + (hasDigits ? 1 : 0) + (hasSymbols ? 1 : 0)
		switch score {
		case 0...2: return .weak
		case 3...4: return .medium
		default: return .strong
		}
	}
}


