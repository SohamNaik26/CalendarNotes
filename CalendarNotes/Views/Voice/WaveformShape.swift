//
//  WaveformShape.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import SwiftUI

struct WaveformShape: Shape {
	let samples: [CGFloat]
	let lineWidth: CGFloat
	
	func path(in rect: CGRect) -> Path {
		var path = Path()
		guard !samples.isEmpty else { return path }
		let midY = rect.midY
		let count = samples.count
		let step = max(lineWidth, rect.width / CGFloat(count))
		var x: CGFloat = 0
		for s in samples {
			let clamped = min(max(s, 0), 1)
			let height = clamped * rect.height / 2
			path.move(to: CGPoint(x: x, y: midY - height))
			path.addLine(to: CGPoint(x: x, y: midY + height))
			x += step
		}
		return path.strokedPath(.init(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
	}
}


