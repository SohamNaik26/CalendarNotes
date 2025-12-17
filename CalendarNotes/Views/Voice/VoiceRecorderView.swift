//
//  VoiceRecorderView.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import SwiftUI
import AVFoundation

struct VoiceRecorderView: View {
	@StateObject private var recorder = VoiceRecorderService.shared
	@State private var samples: [CGFloat] = Array(repeating: 0.05, count: 120)
	@State private var isProcessing: Bool = false
	@State private var savedURL: URL?
	@State private var errorMessage: String?
	@State private var fileSizeText: String = "--"
	@State private var freeSpaceText: String = "--"
	
	private var durationText: String {
		let t = Int(recorder.getCurrentTime())
		return String(format: "%02d:%02d", t / 60, t % 60)
	}
	
	private var recordButtonColor: Color {
		if isProcessing { return .gray }
		if recorder.isPaused { return .yellow }
		return recorder.isRecording ? .red : .gray
	}
	
	var body: some View {
		VStack(spacing: 16) {
			// Waveform
			ZStack {
				WakeGradient()
					.clipShape(RoundedRectangle(cornerRadius: 16))
					.frame(height: 140)
				WaveformShape(samples: samples, lineWidth: 3)
					.fill(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
					.frame(height: 120)
					.padding(.horizontal, 12)
					.opacity(recorder.isRecording ? 1 : 0.4)
			}
			
			// Meter and timer
			HStack {
				LevelMeter(level: recorder.currentLevel)
				Spacer()
				Text(durationText)
					.font(.system(.title2, design: .monospaced))
					.bold()
				Spacer()
				VStack(alignment: .trailing) {
					Text("File: \(fileSizeText)")
						.font(.caption)
						.foregroundColor(.secondary)
					Text("Free: \(freeSpaceText)")
						.font(.caption)
						.foregroundColor(.secondary)
				}
			}
			
			// Controls
			HStack(spacing: 24) {
				Button {
					recorder.cancelRecording()
					savedURL = nil
				} label: {
					Image(systemName: "xmark.circle.fill").font(.system(size: 28))
				}
				.disabled(!recorder.isRecording && savedURL == nil)
				
				Button {
					Task { await toggleRecord() }
				} label: {
					Circle()
						.fill(recordButtonColor)
						.frame(width: 80, height: 80)
						.overlay(
							Circle().stroke(Color.white.opacity(0.8), lineWidth: 3)
						)
						.overlay(
							Image(systemName: recorder.isRecording ? "pause.fill" : "mic.fill")
								.font(.title)
								.foregroundColor(.white)
						)
						.shadow(color: recordButtonColor.opacity(0.4), radius: 10, x: 0, y: 6)
						.scaleEffect(recorder.isRecording ? 1.05 : 1.0)
						.animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: recorder.isRecording)
				}
				.disabled(isProcessing)
				
				Button {
					if recorder.isRecording {
						recorder.pauseRecording()
					} else if recorder.isPaused {
						recorder.resumeRecording()
					}
				} label: {
					Image(systemName: recorder.isPaused ? "play.circle.fill" : "pause.circle.fill")
						.font(.system(size: 28))
						.foregroundColor(.yellow)
				}
				.disabled(!recorder.isRecording && !recorder.isPaused)
				
				Button {
					if let url = recorder.stopRecording() {
						savedURL = url
						updateFileInfo(url)
					}
				} label: {
					Image(systemName: "checkmark.circle.fill").font(.system(size: 28)).foregroundColor(.green)
				}
				.disabled(!recorder.isRecording && !recorder.isPaused)
			}
			
			if let errorMessage {
				Text(errorMessage)
					.foregroundColor(.red)
					.font(.footnote)
			}
			
			if let savedURL {
				HStack {
					Image(systemName: "doc.waveform")
					Text(savedURL.lastPathComponent)
					Spacer()
					Button {
						recorder.deleteRecording(at: savedURL)
						self.savedURL = nil
						fileSizeText = "--"
					} label: {
						Image(systemName: "trash")
					}
				}
				.padding(12)
				.background(Color.cnSecondaryBackground)
				.clipShape(RoundedRectangle(cornerRadius: 12))
			}
			
			Spacer()
		}
		.padding()
		.onAppear {
			updateFreeSpace()
		}
		.onChange(of: recorder.currentLevel) { _, newValue in
			appendSample(newValue)
		}
	}
	
	private func toggleRecord() async {
		do {
			if recorder.isRecording {
				recorder.pauseRecording()
			} else if recorder.isPaused {
				recorder.resumeRecording()
			} else {
				guard recorder.hasSufficientDiskSpace() else {
					errorMessage = "Not enough free space to record."
					return
				}
				try await recorder.startRecording()
				errorMessage = nil
				fileSizeText = "--"
			}
		} catch {
			errorMessage = error.localizedDescription
		}
	}
	
	private func appendSample(_ level: Float) {
		var s = samples
		s.append(CGFloat(level))
		if s.count > 240 {
			s.removeFirst(s.count - 240)
		}
		withAnimation(.linear(duration: 1.0/60.0)) {
			samples = s
		}
	}
	
	private func updateFileInfo(_ url: URL) {
		if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
		   let size = attrs[.size] as? NSNumber {
			fileSizeText = ByteCountFormatter.string(fromByteCount: size.int64Value, countStyle: .file)
		}
		updateFreeSpace()
	}
	
	private func updateFreeSpace() {
		guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
			  let free = attrs[.systemFreeSize] as? NSNumber else {
			freeSpaceText = "--"
			return
		}
		freeSpaceText = ByteCountFormatter.string(fromByteCount: free.int64Value, countStyle: .file)
	}
}

private struct LevelMeter: View {
	let level: Float // 0...1
	var body: some View {
		HStack(spacing: 2) {
			ForEach(0..<12, id: \.self) { i in
				let h = CGFloat(i + 1) / 12.0
				Rectangle()
					.fill(LinearGradient(colors: [.green, .yellow, .red], startPoint: .bottom, endPoint: .top))
					.frame(width: 4, height: 40 * h)
					.opacity(level > Float(h) ? 1 : 0.2)
					.animation(.easeInOut(duration: 0.1), value: level)
			}
		}
		.frame(height: 42)
	}
}

private struct WakeGradient: View {
	var body: some View {
		LinearGradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)], startPoint: .leading, endPoint: .trailing)
	}
}


