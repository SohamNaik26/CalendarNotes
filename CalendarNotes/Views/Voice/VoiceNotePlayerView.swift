//
//  VoiceNotePlayerView.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import SwiftUI
import AVFoundation

struct VoiceNotePlayerView: View {
	let note: VoiceNote
	let onClose: () -> Void
	
	@State private var isExpanded: Bool = false
	@State private var isPlaying: Bool = false
	@State private var currentTime: TimeInterval = 0
	@State private var duration: TimeInterval = 0
	@State private var timer: Timer?
	
	#if os(iOS)
	@State private var player: AVAudioPlayer?
	#endif
	
	var body: some View {
		VStack(spacing: 8) {
			HStack {
				WaveformShape(samples: (0..<24).map { _ in CGFloat.random(in: 0.1...0.9) }, lineWidth: 2)
					.fill(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
					.frame(width: 64, height: 24)
					.opacity(0.8)
				Text(note.audioFileURL.lastPathComponent)
					.lineLimit(1)
				Spacer()
				Button { togglePlay() } label: {
					Image(systemName: isPlaying ? "pause.fill" : "play.fill")
				}
				.buttonStyle(.borderedProminent)
				Button { onClose() } label: { Image(systemName: "xmark") }
			}
			Slider(value: Binding(get: { currentTime }, set: { setTime($0) }), in: 0...max(duration, 0.1))
		}
		.padding(12)
		.background(.ultraThinMaterial)
		.clipShape(RoundedRectangle(cornerRadius: 16))
		.onAppear {
			#if os(iOS)
			player = try? AVAudioPlayer(contentsOf: note.audioFileURL)
			duration = player?.duration ?? 0
			#endif
		}
		.onDisappear { stopTimer() }
	}
	
	private func togglePlay() {
		#if os(iOS)
		guard let p = player else { return }
		if p.isPlaying {
			p.pause()
			stopTimer()
			isPlaying = false
		} else {
			p.play()
			startTimer()
			isPlaying = true
		}
		#endif
	}
	
	private func setTime(_ t: TimeInterval) {
		let clamped = min(max(0, t), duration)
		currentTime = clamped
		#if os(iOS)
		player?.currentTime = clamped
		#endif
	}
	
	private func startTimer() {
		stopTimer()
		// Timer will be invalidated in onDisappear or stopTimer
		timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
			#if os(iOS)
			currentTime = player?.currentTime ?? 0
			if currentTime >= duration {
				player?.stop()
				isPlaying = false
				stopTimer()
			}
			#endif
		}
	}
	
	private func stopTimer() {
		timer?.invalidate()
		timer = nil
	}
}


