//
//  VoiceNoteDetailView.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import SwiftUI
import AVFoundation

struct VoiceNoteDetailView: View {
	let note: VoiceNote
	
	@State private var isPlaying: Bool = false
	@State private var currentTime: TimeInterval = 0
	@State private var duration: TimeInterval = 0
	@State private var rate: Float = 1.0
	@State private var loop: Bool = false
	@State private var transcription: String = ""
	@State private var timer: Timer?
	@State private var errorMessage: String?
	
	#if os(iOS)
	@State private var player: AVAudioPlayer?
	#endif
	
	var body: some View {
		GeometryReader { geometry in
			VStack(spacing: 16) {
				// Waveform placeholder with playhead
				ZStack(alignment: .leading) {
					WaveformShape(samples: (0..<120).map { i in CGFloat(sin(Double(i)/7.0) * 0.5 + 0.5) }, lineWidth: 3)
						.fill(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
						.frame(height: 120)
						.opacity(0.8)
					Rectangle()
						.fill(Color.white)
						.frame(width: 2, height: 120)
						.offset(x: CGFloat(progress()) * (geometry.size.width - 32) * 0.9)
				}
				.clipShape(RoundedRectangle(cornerRadius: 16))
			
			// Controls
			HStack(spacing: 18) {
				Button { seek(by: -15) } label: { Image(systemName: "gobackward.15") }
				Button { togglePlay() } label: {
					Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
						.font(.system(size: 48))
				}
				Button { seek(by: 15) } label: { Image(systemName: "goforward.15") }
				Menu {
					Button("0.5x") { setRate(0.5) }
					Button("1x") { setRate(1.0) }
					Button("1.5x") { setRate(1.5) }
					Button("2x") { setRate(2.0) }
				} label: {
					Label("\(rate, specifier: "%.1fx")", systemImage: "speedometer")
				}
				Toggle(isOn: $loop) { Image(systemName: "repeat") }
					.toggleStyle(.button)
			}
			
			// Slider
			VStack {
				Slider(value: Binding(
					get: { currentTime },
					set: { setTime($0) }
				), in: 0...max(duration, 0.1))
				HStack {
					Text(format(currentTime)).font(.caption)
					Spacer()
					Text(format(duration)).font(.caption)
				}
			}
			
			// Transcription
			VStack(alignment: .leading, spacing: 8) {
				HStack {
					Text("Transcription").font(.headline)
					Spacer()
					Button("Transcribe") {
						Task {
							do {
								let text = try await VoiceTranscriptionService.shared.transcribeAudioFile(url: note.audioFileURL)
								transcription = text
							} catch {
								errorMessage = error.localizedDescription
							}
						}
					}
				}
				TextEditor(text: $transcription)
					.frame(minHeight: 120)
					.overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
				if let errorMessage {
					Text(errorMessage).foregroundColor(.red).font(.footnote)
				}
			}
			
			// Metadata
			VStack(alignment: .leading, spacing: 6) {
				Text("Recorded: \(note.createdAt.formatted(date: .abbreviated, time: .shortened))")
				Text("Duration: \(format(note.duration))")
				if let size = fileSize(note.audioFileURL) {
					Text("File size: \(size)")
				}
				Text("Language: \(VoiceTranscriptionService.shared.preferredLocale().identifier)")
			}
			.font(.caption)
			.foregroundColor(.secondary)
			
			Spacer()
			}
			.padding()
			.onAppear {
				transcription = note.transcription ?? ""
				duration = note.duration
				#if os(iOS)
				preparePlayer()
				#endif
			}
			.onDisappear {
				stopTimer()
				#if os(iOS)
				player?.stop()
				#endif
			}
		}
	}
	
	private func progress() -> CGFloat {
		guard duration > 0 else { return 0 }
		return CGFloat(currentTime / duration)
	}
	
	#if os(iOS)
	private func preparePlayer() {
		do {
			player = try AVAudioPlayer(contentsOf: note.audioFileURL)
			player?.enableRate = true
			player?.prepareToPlay()
			duration = player?.duration ?? note.duration
		} catch {
			errorMessage = error.localizedDescription
		}
	}
	#endif
	
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
	
	private func setRate(_ r: Float) {
		rate = r
		#if os(iOS)
		player?.rate = r
		#endif
	}
	
	private func seek(by delta: TimeInterval) {
		setTime(currentTime + delta)
	}
	
	private func setTime(_ t: TimeInterval) {
		let clamped = min(max(0, t), duration)
		currentTime = clamped
		#if os(iOS)
		player?.currentTime = clamped
		if player?.isPlaying == true { startTimer() }
		#endif
	}
	
	private func startTimer() {
		stopTimer()
		// Timer will be invalidated in onDisappear or stopTimer
		timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
			#if os(iOS)
			guard let p = player else { return }
			currentTime = p.currentTime
			if p.currentTime >= duration {
				if loop {
					p.currentTime = 0
					p.play()
				} else {
					p.stop()
					isPlaying = false
					stopTimer()
				}
			}
			#endif
		}
	}
	
	private func stopTimer() {
		timer?.invalidate()
		timer = nil
	}
	
	private func format(_ t: TimeInterval) -> String {
		let s = Int(t)
		return String(format: "%d:%02d", s/60, s%60)
	}
	
	private func fileSize(_ url: URL) -> String? {
		if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
		   let size = attrs[.size] as? NSNumber {
			return ByteCountFormatter.string(fromByteCount: size.int64Value, countStyle: .file)
		}
		return nil
	}
}


