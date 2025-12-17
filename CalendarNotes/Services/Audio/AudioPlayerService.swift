//
//  AudioPlayerService.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation
import AVFoundation
import Combine
import MediaPlayer
#if os(iOS)
import UIKit
#endif

/// Service for managing audio playback of voice notes with background playback,
/// lock screen controls, queue management, and audio effects.
final class AudioPlayerService: NSObject, ObservableObject {
	
	// MARK: - Singleton
	
	static let shared = AudioPlayerService()
	
	private override init() {
		super.init()
		setupAudioSession()
		setupRemoteCommandCenter()
		setupNotifications()
	}
	
	// MARK: - Published Properties
	
	@Published private(set) var isPlaying: Bool = false
	@Published private(set) var currentTime: TimeInterval = 0
	@Published private(set) var duration: TimeInterval = 0
	@Published private(set) var playbackRate: Float = 1.0
	@Published private(set) var currentVoiceNote: VoiceNote?
	@Published private(set) var queue: [VoiceNote] = []
	@Published private(set) var currentQueueIndex: Int = -1
	@Published private(set) var shuffleMode: Bool = false
	@Published private(set) var repeatMode: RepeatMode = .off
	
	// MARK: - Audio Effects
	
	@Published var equalizerPreset: EqualizerPreset = .none
	@Published var pitchAdjustment: Float = 0.0 // -12 to +12 semitones
	@Published var speedAdjustment: Float = 1.0 // 0.5x to 2.0x
	@Published var noiseReductionEnabled: Bool = false
	@Published var volumeBoost: Float = 1.0 // 1.0 to 2.0
	
	// MARK: - Private Properties
	
	private var player: AVAudioPlayer?
	private var updateTimer: Timer?
	private var audioEngine: AVAudioEngine?
	private var playerNode: AVAudioPlayerNode?
	private var timePitchNode: AVAudioUnitTimePitch?
	private var eqNode: AVAudioUnitEQ?
	private var file: AVAudioFile?
	
	private var shuffledQueue: [VoiceNote] = []
	private var originalQueue: [VoiceNote] = []
	
	#if os(iOS)
	private var backgroundTaskId: UIBackgroundTaskIdentifier?
	#endif
	
	// MARK: - Enums
	
	enum RepeatMode {
		case off
		case one
		case all
	}
	
	enum EqualizerPreset: String, CaseIterable {
		case none = "None"
		case voice = "Voice"
		case bass = "Bass Boost"
		case treble = "Treble Boost"
		case flat = "Flat"
		
		var frequencies: [(frequency: Float, gain: Float)] {
			switch self {
			case .none:
				return []
			case .voice:
				return [
					(250, 3.0),   // Low-mid boost for voice clarity
					(1000, 2.0),  // Mid boost
					(4000, 1.5)   // High-mid boost
				]
			case .bass:
				return [
					(60, 6.0),    // Low bass boost
					(170, 4.0)    // Mid-bass boost
				]
			case .treble:
				return [
					(4000, 4.0),  // High-mid boost
					(8000, 3.0)   // High boost
				]
			case .flat:
				return []
			}
		}
	}
	
	// MARK: - Audio Session Configuration
	
	private func setupAudioSession() {
		#if os(iOS)
		do {
			let session = AVAudioSession.sharedInstance()
			try session.setCategory(.playback, mode: .spokenAudio, options: [
				.allowBluetoothHFP,
				.allowBluetoothA2DP,
				.allowAirPlay,
				.duckOthers
			])
			try session.setActive(true)
		} catch {
			print("Failed to configure audio session: \(error)")
		}
		#endif
	}
	
	// MARK: - Playback Methods
	
	/// Play a voice note from a URL
	func play(url: URL) throws {
		// Stop current playback
		stop()
		
		// Load the voice note from queue if available
		if let note = queue.first(where: { $0.audioFileURL == url }) {
			currentVoiceNote = note
			if let index = queue.firstIndex(where: { $0.audioFileURL == url }) {
				currentQueueIndex = index
			}
		} else {
			// Create a temporary voice note for playback
			currentVoiceNote = VoiceNote(
				id: UUID(),
				title: url.deletingPathExtension().lastPathComponent,
				audioFileURL: url,
				duration: 0
			)
		}
		
		// Initialize player
		if speedAdjustment != 1.0 || pitchAdjustment != 0.0 || equalizerPreset != .none {
			try setupAudioEnginePlayer(url: url)
		} else {
			try setupSimplePlayer(url: url)
		}
		
		// Update now playing info
		updateNowPlayingInfo()
		
		// Start playback
		if let player = player {
			player.play()
			isPlaying = true
			startUpdateTimer()
		} else if let playerNode = playerNode {
			playerNode.play()
			isPlaying = true
			startUpdateTimer()
		}
		
		// Request background time if needed
		#if os(iOS)
		requestBackgroundTime()
		#endif
	}
	
	/// Play a voice note from the model
	func play(voiceNote: VoiceNote) throws {
		try play(url: voiceNote.audioFileURL)
		currentVoiceNote = voiceNote
	}
	
	/// Pause playback
	func pause() {
		player?.pause()
		playerNode?.pause()
		isPlaying = false
		stopUpdateTimer()
		updateNowPlayingInfo()
	}
	
	/// Stop playback
	func stop() {
		player?.stop()
		playerNode?.stop()
		audioEngine?.stop()
		isPlaying = false
		currentTime = 0
		stopUpdateTimer()
		updateNowPlayingInfo()
		#if os(iOS)
		endBackgroundTask()
		#endif
	}
	
	/// Seek to a specific time
	func seek(to time: TimeInterval) {
		let clampedTime = max(0, min(time, duration))
		currentTime = clampedTime
		
		if let player = player {
			player.currentTime = clampedTime
		} else if let file = file, let playerNode = playerNode {
			// For audio engine, we need to restart playback from the new position
			playerNode.stop()
			let framePosition = AVAudioFramePosition(clampedTime * file.fileFormat.sampleRate)
			playerNode.scheduleSegment(
				file,
				startingFrame: framePosition,
				frameCount: AVAudioFrameCount(file.length - framePosition),
				at: nil
			) { [weak self] in
				DispatchQueue.main.async {
					self?.handlePlaybackFinished()
				}
			}
			if isPlaying {
				playerNode.play()
			}
		}
		
		updateNowPlayingInfo()
	}
	
	/// Set playback rate (0.5x to 2.0x)
	func setPlaybackRate(rate: Float) {
		let clampedRate = max(0.5, min(2.0, rate))
		playbackRate = clampedRate
		
		if let player = player {
			player.enableRate = true
			player.rate = clampedRate
		} else if let timePitchNode = timePitchNode {
			timePitchNode.rate = clampedRate
		}
		
		updateNowPlayingInfo()
	}
	
	/// Skip forward by specified seconds
	func skipForward(seconds: TimeInterval) {
		seek(to: currentTime + seconds)
	}
	
	/// Skip backward by specified seconds
	func skipBackward(seconds: TimeInterval) {
		seek(to: currentTime - seconds)
	}
	
	/// Toggle loop mode
	func toggleLoop(enabled: Bool) {
		if enabled {
			repeatMode = .one
		} else {
			repeatMode = .off
		}
		player?.numberOfLoops = enabled ? -1 : 0
	}
	
	// MARK: - Queue Management
	
	/// Set the queue of voice notes to play
	func setQueue(_ voiceNotes: [VoiceNote], startIndex: Int = 0) {
		originalQueue = voiceNotes
		queue = shuffleMode ? voiceNotes.shuffled() : voiceNotes
		shuffledQueue = shuffleMode ? queue : []
		currentQueueIndex = startIndex >= 0 && startIndex < queue.count ? startIndex : -1
	}
	
	/// Add voice notes to the queue
	func addToQueue(_ voiceNotes: [VoiceNote]) {
		originalQueue.append(contentsOf: voiceNotes)
		let newItems = shuffleMode ? voiceNotes.shuffled() : voiceNotes
		queue.append(contentsOf: newItems)
		if shuffleMode {
			shuffledQueue.append(contentsOf: newItems)
		}
	}
	
	/// Clear the queue
	func clearQueue() {
		queue = []
		originalQueue = []
		shuffledQueue = []
		currentQueueIndex = -1
	}
	
	/// Play next voice note in queue
	func playNext() {
		guard !queue.isEmpty else { return }
		
		let nextIndex: Int
		if shuffleMode {
			// In shuffle mode, pick a random item
			nextIndex = Int.random(in: 0..<queue.count)
		} else {
			nextIndex = (currentQueueIndex + 1) % queue.count
		}
		
		guard nextIndex < queue.count else { return }
		
		currentQueueIndex = nextIndex
		do {
			try play(voiceNote: queue[nextIndex])
		} catch {
			print("Failed to play next voice note: \(error)")
		}
	}
	
	/// Play previous voice note in queue
	func playPrevious() {
		guard !queue.isEmpty else { return }
		
		let prevIndex: Int
		if shuffleMode {
			// In shuffle mode, pick a random item
			prevIndex = Int.random(in: 0..<queue.count)
		} else {
			prevIndex = currentQueueIndex <= 0 ? queue.count - 1 : currentQueueIndex - 1
		}
		
		guard prevIndex >= 0 && prevIndex < queue.count else { return }
		
		currentQueueIndex = prevIndex
		do {
			try play(voiceNote: queue[prevIndex])
		} catch {
			print("Failed to play previous voice note: \(error)")
		}
	}
	
	/// Toggle shuffle mode
	func setShuffleMode(_ enabled: Bool) {
		shuffleMode = enabled
		if enabled {
			shuffledQueue = queue
			queue = queue.shuffled()
		} else {
			queue = originalQueue
			shuffledQueue = []
		}
	}
	
	/// Set repeat mode
	func setRepeatMode(_ mode: RepeatMode) {
		repeatMode = mode
		player?.numberOfLoops = (mode == .one) ? -1 : 0
	}
	
	// MARK: - Audio Engine Setup (for effects)
	
	private func setupAudioEnginePlayer(url: URL) throws {
		// Clean up existing engine
		audioEngine?.stop()
		
		// Create new engine
		audioEngine = AVAudioEngine()
		guard let engine = audioEngine else {
			throw NSError(domain: "AudioPlayer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio engine"])
		}
		
		// Create player node
		playerNode = AVAudioPlayerNode()
		guard let playerNode = playerNode else {
			throw NSError(domain: "AudioPlayer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create player node"])
		}
		
		// Create time pitch node for speed and pitch adjustment
		timePitchNode = AVAudioUnitTimePitch()
		guard let timePitchNode = timePitchNode else {
			throw NSError(domain: "AudioPlayer", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create time pitch node"])
		}
		
		// Create EQ node if needed
		if equalizerPreset != .none {
			eqNode = AVAudioUnitEQ(numberOfBands: equalizerPreset.frequencies.count)
			if let eqNode = eqNode {
				for (index, freq) in equalizerPreset.frequencies.enumerated() {
					eqNode.bands[index].frequency = freq.frequency
					eqNode.bands[index].gain = freq.gain
					eqNode.bands[index].bandwidth = 1.0
				}
			}
		}
		
		// Load audio file
		file = try AVAudioFile(forReading: url)
		guard let file = file else {
			throw NSError(domain: "AudioPlayer", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to load audio file"])
		}
		
		duration = Double(file.length) / file.fileFormat.sampleRate
		
		// Connect nodes
		engine.attach(playerNode)
		engine.attach(timePitchNode)
		
		if let eqNode = eqNode {
			engine.attach(eqNode)
			engine.connect(playerNode, to: timePitchNode, format: file.processingFormat)
			engine.connect(timePitchNode, to: eqNode, format: file.processingFormat)
			engine.connect(eqNode, to: engine.mainMixerNode, format: file.processingFormat)
		} else {
			engine.connect(playerNode, to: timePitchNode, format: file.processingFormat)
			engine.connect(timePitchNode, to: engine.mainMixerNode, format: file.processingFormat)
		}
		
		// Configure time pitch
		timePitchNode.rate = speedAdjustment
		timePitchNode.pitch = pitchAdjustment * 100 // Convert semitones to cents
		
		// Start engine
		try engine.start()
		
		// Schedule file
		playerNode.scheduleFile(file, at: nil) { [weak self] in
			DispatchQueue.main.async {
				self?.handlePlaybackFinished()
			}
		}
	}
	
	private func setupSimplePlayer(url: URL) throws {
		player = try AVAudioPlayer(contentsOf: url)
		player?.delegate = self
		player?.enableRate = true
		player?.rate = playbackRate
		player?.volume = volumeBoost
		duration = player?.duration ?? 0
	}
	
	// MARK: - Timer Management
	
	private func startUpdateTimer() {
		stopUpdateTimer()
		updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
			self?.updateCurrentTime()
		}
	}
	
	private func stopUpdateTimer() {
		updateTimer?.invalidate()
		updateTimer = nil
	}
	
	private func updateCurrentTime() {
		if let player = player {
			currentTime = player.currentTime
			if currentTime >= duration && !player.isPlaying {
				handlePlaybackFinished()
			}
		} else if let file = file, let playerNode = playerNode {
			// For audio engine, we need to track time manually
			// This is a simplified version - in production you'd want more accurate tracking
			if let nodeTime = playerNode.lastRenderTime,
			   let playerTime = playerNode.playerTime(forNodeTime: nodeTime) {
				currentTime = Double(playerTime.sampleTime) / file.fileFormat.sampleRate
			}
		}
		
		updateNowPlayingInfo()
	}
	
	// MARK: - Playback Finished Handler
	
	private func handlePlaybackFinished() {
		stopUpdateTimer()
		isPlaying = false
		currentTime = 0
		
		switch repeatMode {
		case .one:
			// Loop current track
			if let note = currentVoiceNote {
				do {
					try play(voiceNote: note)
				} catch {
					print("Failed to loop voice note: \(error)")
				}
			}
		case .all:
			// Play next in queue
			playNext()
		case .off:
			// Auto-advance to next if queue has items
			if !queue.isEmpty && currentQueueIndex >= 0 {
				playNext()
			} else {
				stop()
			}
		}
	}
	
	// MARK: - Now Playing Info (Lock Screen)
	
	private func updateNowPlayingInfo() {
		#if os(iOS)
		var nowPlayingInfo = [String: Any]()
		
		if let note = currentVoiceNote {
			nowPlayingInfo[MPMediaItemPropertyTitle] = note.displayTitle
			nowPlayingInfo[MPMediaItemPropertyArtist] = "Voice Note"
			
			// Add transcription snippet if available
			if let transcription = note.transcriptionSnippet {
				nowPlayingInfo[MPMediaItemPropertyLyrics] = transcription
			}
		}
		
		nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
		nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
		nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? Double(playbackRate) : 0.0
		
		// Add artwork if waveform samples are available
		if let note = currentVoiceNote, !note.waveformSamples.isEmpty {
			if let artwork = generateWaveformArtwork(samples: note.waveformSamples) {
				nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
			}
		}
		
		MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
		#endif
	}
	
	#if os(iOS)
	private func generateWaveformArtwork(samples: [Double]) -> MPMediaItemArtwork? {
		let size = CGSize(width: 400, height: 400)
		
		return MPMediaItemArtwork(boundsSize: size) { _ in
			let renderer = UIGraphicsImageRenderer(size: size)
			return renderer.image { context in
				let cgContext = context.cgContext
				
				// Background
				cgContext.setFillColor(UIColor.systemBackground.cgColor)
				cgContext.fill(CGRect(origin: .zero, size: size))
				
				// Waveform
				let barWidth = size.width / CGFloat(samples.count)
				let maxHeight = size.height * 0.8
				
				cgContext.setFillColor(UIColor.systemBlue.cgColor)
				
				for (index, sample) in samples.enumerated() {
					let height = CGFloat(sample) * maxHeight
					let x = CGFloat(index) * barWidth
					let y = (size.height - height) / 2
					
					cgContext.fill(CGRect(x: x, y: y, width: barWidth - 1, height: height))
				}
			}
		}
	}
	#endif
	
	// MARK: - Remote Command Center
	
	private func setupRemoteCommandCenter() {
		#if os(iOS)
		let commandCenter = MPRemoteCommandCenter.shared()
		
		// Play command
		commandCenter.playCommand.isEnabled = true
		commandCenter.playCommand.addTarget { [weak self] _ in
			guard let self = self, let player = self.player else { return .commandFailed }
			if !self.isPlaying {
				player.play()
				self.isPlaying = true
				self.startUpdateTimer()
				return .success
			}
			return .commandFailed
		}
		
		// Pause command
		commandCenter.pauseCommand.isEnabled = true
		commandCenter.pauseCommand.addTarget { [weak self] _ in
			guard let self = self else { return .commandFailed }
			self.pause()
			return .success
		}
		
		// Toggle play/pause
		commandCenter.togglePlayPauseCommand.isEnabled = true
		commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
			guard let self = self else { return .commandFailed }
			if self.isPlaying {
				self.pause()
			} else if self.currentVoiceNote != nil {
				do {
					try self.play(url: self.currentVoiceNote!.audioFileURL)
				} catch {
					return .commandFailed
				}
			}
			return .success
		}
		
		// Next track
		commandCenter.nextTrackCommand.isEnabled = true
		commandCenter.nextTrackCommand.addTarget { [weak self] _ in
			guard let self = self else { return .commandFailed }
			self.playNext()
			return .success
		}
		
		// Previous track
		commandCenter.previousTrackCommand.isEnabled = true
		commandCenter.previousTrackCommand.addTarget { [weak self] _ in
			guard let self = self else { return .commandFailed }
			self.playPrevious()
			return .success
		}
		
		// Skip forward
		commandCenter.skipForwardCommand.isEnabled = true
		commandCenter.skipForwardCommand.preferredIntervals = [15, 30, 60] // 15s, 30s, 1min
		commandCenter.skipForwardCommand.addTarget { [weak self] event in
			guard let self = self else { return .commandFailed }
			if let skipEvent = event as? MPSkipIntervalCommandEvent {
				self.skipForward(seconds: skipEvent.interval)
				return .success
			}
			return .commandFailed
		}
		
		// Skip backward
		commandCenter.skipBackwardCommand.isEnabled = true
		commandCenter.skipBackwardCommand.preferredIntervals = [15, 30, 60] // 15s, 30s, 1min
		commandCenter.skipBackwardCommand.addTarget { [weak self] event in
			guard let self = self else { return .commandFailed }
			if let skipEvent = event as? MPSkipIntervalCommandEvent {
				self.skipBackward(seconds: skipEvent.interval)
				return .success
			}
			return .commandFailed
		}
		
		// Change playback position
		commandCenter.changePlaybackPositionCommand.isEnabled = true
		commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
			guard let self = self else { return .commandFailed }
			if let positionEvent = event as? MPChangePlaybackPositionCommandEvent {
				self.seek(to: positionEvent.positionTime)
				return .success
			}
			return .commandFailed
		}
		#endif
	}
	
	// MARK: - Notifications & Interruptions
	
	private func setupNotifications() {
		#if os(iOS)
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(handleInterruption),
			name: AVAudioSession.interruptionNotification,
			object: nil
		)
		
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(handleRouteChange),
			name: AVAudioSession.routeChangeNotification,
			object: nil
		)
		#endif
	}
	
	#if os(iOS)
	@objc private func handleInterruption(_ notification: Notification) {
		guard let userInfo = notification.userInfo,
			  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
			  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
			return
		}
		
		switch type {
		case .began:
			// Interruption started (e.g., phone call)
			pause()
		case .ended:
			// Interruption ended
			if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
				let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
				if options.contains(.shouldResume) {
					// Resume playback if appropriate
					if let note = currentVoiceNote {
						do {
							try play(voiceNote: note)
						} catch {
							print("Failed to resume after interruption: \(error)")
						}
					}
				}
			}
		@unknown default:
			break
		}
	}
	
	@objc private func handleRouteChange(_ notification: Notification) {
		guard let userInfo = notification.userInfo,
			  let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
			  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
			return
		}
		
		switch reason {
		case .oldDeviceUnavailable:
			// Headphones disconnected
			if isPlaying {
				pause()
			}
		case .newDeviceAvailable:
			// New audio device available
			break
		default:
			break
		}
	}
	#endif
	
	deinit {
		stopUpdateTimer()
		stop()
		#if os(iOS)
		NotificationCenter.default.removeObserver(self)
		#endif
	}
	
	// MARK: - Background Task
	
	#if os(iOS)
	private func requestBackgroundTime() {
		endBackgroundTask()
		backgroundTaskId = UIApplication.shared.beginBackgroundTask { [weak self] in
			self?.endBackgroundTask()
		}
	}
	
	private func endBackgroundTask() {
		if let taskId = backgroundTaskId {
			UIApplication.shared.endBackgroundTask(taskId)
			backgroundTaskId = nil
		}
	}
	#endif
	
	// MARK: - Audio Effects
	
	/// Apply equalizer preset
	func applyEqualizerPreset(_ preset: EqualizerPreset) {
		equalizerPreset = preset
		// Reinitialize player with new EQ settings if playing
		if let note = currentVoiceNote, isPlaying {
			let wasPlaying = isPlaying
			let savedTime = currentTime
			do {
				try play(url: note.audioFileURL)
				if wasPlaying {
					seek(to: savedTime)
				}
			} catch {
				print("Failed to apply equalizer: \(error)")
			}
		}
	}
	
	/// Set pitch adjustment
	func setPitchAdjustment(_ semitones: Float) {
		let clamped = max(-12, min(12, semitones))
		pitchAdjustment = clamped
		timePitchNode?.pitch = clamped * 100 // Convert to cents
	}
	
	/// Set speed adjustment (without pitch change)
	func setSpeedAdjustment(_ rate: Float) {
		let clamped = max(0.5, min(2.0, rate))
		speedAdjustment = clamped
		setPlaybackRate(rate: clamped)
	}
	
	/// Toggle noise reduction
	func setNoiseReduction(_ enabled: Bool) {
		noiseReductionEnabled = enabled
		// Note: Actual noise reduction would require more advanced audio processing
		// This is a placeholder for future implementation
	}
	
	/// Set volume boost
	func setVolumeBoost(_ boost: Float) {
		let clamped = max(1.0, min(2.0, boost))
		volumeBoost = clamped
		player?.volume = clamped
		audioEngine?.mainMixerNode.outputVolume = clamped
	}
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlayerService: AVAudioPlayerDelegate {
	func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
		handlePlaybackFinished()
	}
	
	func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
		print("Audio player decode error: \(error?.localizedDescription ?? "Unknown error")")
		stop()
	}
}

