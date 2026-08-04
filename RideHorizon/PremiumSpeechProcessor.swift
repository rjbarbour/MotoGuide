import Foundation
import AVFoundation

enum SpeechCompressionPreset: String, CaseIterable, Codable, Equatable, Sendable, Identifiable {
    case off
    case light
    case medium
    case strong

    var id: String { rawValue }

    var label: String { rawValue.capitalized }

    var ratio: Float {
        switch self {
        case .off: 1
        case .light: 2
        case .medium: 3
        case .strong: 4
        }
    }

    var thresholdDBFS: Float? {
        switch self {
        case .off: nil
        case .light: -18
        case .medium: -22
        case .strong: -24
        }
    }
}

struct SpeechProcessingProfile: Codable, Equatable, Sendable {
    let outputGainDB: Float
    let compressionPreset: SpeechCompressionPreset
    let presenceGainDB: Float
    let highPassFrequencyHz: Float
    let samplePeakCeilingDBFS: Float
    let automaticPeakNormalisationMaximumGainDB: Float

    static let production = SpeechProcessingProfile(
        outputGainDB: 0,
        compressionPreset: .off,
        presenceGainDB: 0,
        highPassFrequencyHz: 0,
        samplePeakCeilingDBFS: -2,
        automaticPeakNormalisationMaximumGainDB: 20 * log10(2)
    )

    static func calibrationCandidate(
        outputGainDB: Float,
        compressionPreset: SpeechCompressionPreset,
        presenceGainDB: Float
    ) -> SpeechProcessingProfile {
        SpeechProcessingProfile(
            outputGainDB: min(24, max(0, outputGainDB)),
            compressionPreset: compressionPreset,
            presenceGainDB: min(18, max(0, presenceGainDB)),
            highPassFrequencyHz: 100,
            samplePeakCeilingDBFS: -2,
            automaticPeakNormalisationMaximumGainDB: Self.production.automaticPeakNormalisationMaximumGainDB
        )
    }
}

enum PremiumAudioPlaybackError: Error {
    case emptyAudio
    case unsupportedFormat
    case engineConfigurationChanged
}

struct PreparedPremiumAudio: @unchecked Sendable {
    let buffers: [AVAudioPCMBuffer]
    let gainDecibels: Float
    let resultingSamplePeak: Float
    let processingDuration: TimeInterval
}

protocol PremiumSpeechProcessing: Sendable {
    func prepare(
        speechAudio: [Data],
        profile: SpeechProcessingProfile
    ) async throws -> PreparedPremiumAudio
}

struct DefaultPremiumSpeechProcessor: PremiumSpeechProcessing {
    func prepare(
        speechAudio: [Data],
        profile: SpeechProcessingProfile
    ) async throws -> PreparedPremiumAudio {
        let task = Task.detached(priority: .userInitiated) {
            try Self.prepareSynchronously(speechAudio: speechAudio, profile: profile)
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    static func prepareSynchronously(
        speechAudio: [Data],
        profile: SpeechProcessingProfile
    ) throws -> PreparedPremiumAudio {
        let started = ContinuousClock.now
        guard !speechAudio.isEmpty else { throw PremiumAudioPlaybackError.emptyAudio }
        var buffers: [AVAudioPCMBuffer] = []

        for data in speechAudio {
            try Task.checkCancellation()
            buffers.append(try decode(data: data))
        }

        if profile.highPassFrequencyHz > 0 {
            try applyHighPass(profile.highPassFrequencyHz, to: buffers)
        }
        if profile.presenceGainDB > 0 {
            try applyPresenceEQ(gainDB: profile.presenceGainDB, to: buffers)
        }
        if profile.compressionPreset != .off {
            try applyCompression(profile.compressionPreset, to: buffers)
        }

        let peakBeforeGain = try buffers.reduce(Float(0)) {
            max($0, try SpeechAudioPeakNormaliser.peak(in: $1))
        }
        let normalisationMaximum = Self.linearGain(decibels: profile.automaticPeakNormalisationMaximumGainDB)
        let ceiling = Self.linearGain(decibels: profile.samplePeakCeilingDBFS)
        let normalisationGain: Float
        if peakBeforeGain > 0 {
            normalisationGain = max(1, min(normalisationMaximum, ceiling / peakBeforeGain))
        } else {
            normalisationGain = 1
        }
        let requestedGain = normalisationGain * Self.linearGain(decibels: profile.outputGainDB)

        for buffer in buffers {
            try Task.checkCancellation()
            if profile == .production {
                try applyGain(requestedGain, to: buffer)
            } else {
                try applyGainWithPeakLimiter(requestedGain, ceiling: ceiling, to: buffer)
            }
        }
        let resultingPeak = try buffers.reduce(Float(0)) {
            max($0, try SpeechAudioPeakNormaliser.peak(in: $1))
        }

        return PreparedPremiumAudio(
            buffers: buffers,
            gainDecibels: requestedGain > 0 ? 20 * log10(requestedGain) : 0,
            resultingSamplePeak: resultingPeak,
            processingDuration: started.duration(to: .now).timeInterval
        )
    }

    private static func decode(data: Data) throws -> AVAudioPCMBuffer {
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp3")
        try data.write(to: temporaryURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        let file = try AVAudioFile(forReading: temporaryURL)
        guard file.length > 0, file.length <= AVAudioFramePosition(UInt32.max),
              let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: AVAudioFrameCount(file.length)
              ) else {
            throw PremiumAudioPlaybackError.emptyAudio
        }
        try file.read(into: buffer)
        guard buffer.frameLength > 0 else { throw PremiumAudioPlaybackError.emptyAudio }
        return buffer
    }

    private static func applyHighPass(
        _ frequency: Float,
        to buffers: [AVAudioPCMBuffer]
    ) throws {
        for buffer in buffers {
            guard let channels = buffer.floatChannelData else {
                throw PremiumAudioPlaybackError.unsupportedFormat
            }
            let sampleRate = Float(buffer.format.sampleRate)
            let cutoff = min(max(20, frequency), sampleRate * 0.45)
            let rc = 1 / (2 * Float.pi * cutoff)
            let dt = 1 / sampleRate
            let alpha = rc / (rc + dt)
            for channel in 0..<Int(buffer.format.channelCount) {
                var previousInput: Float = 0
                var previousOutput: Float = 0
                let samples = channels[channel]
                for frame in 0..<Int(buffer.frameLength) {
                    if frame.isMultiple(of: 2_048) { try Task.checkCancellation() }
                    let input = samples[frame]
                    let output = alpha * (previousOutput + input - previousInput)
                    samples[frame] = output
                    previousInput = input
                    previousOutput = output
                }
            }
        }
    }

    private static func applyPresenceEQ(
        gainDB: Float,
        to buffers: [AVAudioPCMBuffer]
    ) throws {
        for buffer in buffers {
            guard let channels = buffer.floatChannelData else {
                throw PremiumAudioPlaybackError.unsupportedFormat
            }
            let sampleRate = Float(buffer.format.sampleRate)
            let centreFrequency = min(2_800, sampleRate * 0.4)
            let q: Float = 0.8
            let a = pow(10, gainDB / 40)
            let omega = 2 * Float.pi * centreFrequency / sampleRate
            let alpha = sin(omega) / (2 * q)
            let b0 = 1 + alpha * a
            let b1 = -2 * cos(omega)
            let b2 = 1 - alpha * a
            let a0 = 1 + alpha / a
            let a1 = -2 * cos(omega)
            let a2 = 1 - alpha / a

            for channel in 0..<Int(buffer.format.channelCount) {
                var x1: Float = 0
                var x2: Float = 0
                var y1: Float = 0
                var y2: Float = 0
                let samples = channels[channel]
                for frame in 0..<Int(buffer.frameLength) {
                    if frame.isMultiple(of: 2_048) { try Task.checkCancellation() }
                    let x0 = samples[frame]
                    let y0 = (b0 / a0) * x0 + (b1 / a0) * x1 + (b2 / a0) * x2
                        - (a1 / a0) * y1 - (a2 / a0) * y2
                    samples[frame] = y0
                    x2 = x1
                    x1 = x0
                    y2 = y1
                    y1 = y0
                }
            }
        }
    }

    private static func applyCompression(
        _ preset: SpeechCompressionPreset,
        to buffers: [AVAudioPCMBuffer]
    ) throws {
        guard let thresholdDB = preset.thresholdDBFS else { return }
        let kneeWidthDB: Float = 6
        for buffer in buffers {
            guard let channels = buffer.floatChannelData else {
                throw PremiumAudioPlaybackError.unsupportedFormat
            }
            let sampleRate = Float(buffer.format.sampleRate)
            let attackCoefficient = exp(-1 / (sampleRate * 0.010))
            let releaseCoefficient = exp(-1 / (sampleRate * 0.120))
            for channel in 0..<Int(buffer.format.channelCount) {
                var envelope: Float = 0
                let samples = channels[channel]
                for frame in 0..<Int(buffer.frameLength) {
                    if frame.isMultiple(of: 2_048) { try Task.checkCancellation() }
                    let magnitude = abs(samples[frame])
                    let coefficient = magnitude > envelope ? attackCoefficient : releaseCoefficient
                    envelope = coefficient * envelope + (1 - coefficient) * magnitude
                    let levelDB = 20 * log10(max(envelope, 0.000_001))
                    let overDB = levelDB - thresholdDB
                    let compressedOverDB: Float
                    if overDB <= -kneeWidthDB / 2 {
                        compressedOverDB = overDB
                    } else if overDB >= kneeWidthDB / 2 {
                        compressedOverDB = overDB / preset.ratio
                    } else {
                        let position = (overDB + kneeWidthDB / 2) / kneeWidthDB
                        let fullCompression = overDB / preset.ratio
                        compressedOverDB = overDB + position * position * (fullCompression - overDB)
                    }
                    let gainReductionDB = min(0, compressedOverDB - overDB)
                    samples[frame] *= linearGain(decibels: gainReductionDB)
                }
            }
        }
    }

    private static func applyGain(
        _ gain: Float,
        to buffer: AVAudioPCMBuffer
    ) throws {
        guard let channels = buffer.floatChannelData else {
            throw PremiumAudioPlaybackError.unsupportedFormat
        }
        for channel in 0..<Int(buffer.format.channelCount) {
            let samples = channels[channel]
            for frame in 0..<Int(buffer.frameLength) {
                if frame.isMultiple(of: 2_048) { try Task.checkCancellation() }
                samples[frame] *= gain
            }
        }
    }

    private static func applyGainWithPeakLimiter(
        _ gain: Float,
        ceiling: Float,
        to buffer: AVAudioPCMBuffer
    ) throws {
        guard let channels = buffer.floatChannelData else {
            throw PremiumAudioPlaybackError.unsupportedFormat
        }
        let channelCount = Int(buffer.format.channelCount)
        let releaseCoefficient = exp(-1 / (Float(buffer.format.sampleRate) * 0.050))
        // Leave bounded headroom for reconstruction peaks because this probe uses
        // a sample limiter rather than claiming standards-based true-peak limiting.
        let limiterCeiling = ceiling * 0.88
        var limiterGain: Float = 1

        for frame in 0..<Int(buffer.frameLength) {
            if frame.isMultiple(of: 2_048) { try Task.checkCancellation() }
            var amplifiedPeak: Float = 0
            for channel in 0..<channelCount {
                amplifiedPeak = max(amplifiedPeak, abs(channels[channel][frame] * gain))
            }
            let requiredGain = amplifiedPeak > limiterCeiling ? limiterCeiling / amplifiedPeak : 1
            if requiredGain < limiterGain {
                limiterGain = requiredGain
            } else {
                limiterGain = releaseCoefficient * limiterGain + (1 - releaseCoefficient)
            }
            for channel in 0..<channelCount {
                channels[channel][frame] *= gain * limiterGain
            }
        }
    }

    private static func linearGain(decibels: Float) -> Float {
        pow(10, decibels / 20)
    }
}

enum SpeechAudioPeakNormaliser {
    static let maximumGain: Float = 2
    static let targetPeak: Float = 0.794_328_2 // -2 dBFS sample peak

    static func gain(forPeak peak: Float) -> Float {
        guard peak > 0 else { return 1 }
        return max(1, min(maximumGain, targetPeak / peak))
    }

    static func peak(in buffer: AVAudioPCMBuffer) throws -> Float {
        guard let channelData = buffer.floatChannelData else {
            throw PremiumAudioPlaybackError.unsupportedFormat
        }
        let channelCount = Int(buffer.format.channelCount)
        let frameCount = Int(buffer.frameLength)
        var peak: Float = 0

        for channel in 0..<channelCount {
            let samples = channelData[channel]
            for frame in 0..<frameCount {
                if frame.isMultiple(of: 2_048) { try Task.checkCancellation() }
                peak = max(peak, abs(samples[frame]))
            }
        }
        return peak
    }

    static func apply(to buffer: AVAudioPCMBuffer) throws -> Float {
        let appliedGain = gain(forPeak: try peak(in: buffer))
        try apply(gain: appliedGain, to: buffer)
        return appliedGain > 1 ? 20 * log10(appliedGain) : 0
    }

    static func apply(gain appliedGain: Float, to buffer: AVAudioPCMBuffer) throws {
        guard let channelData = buffer.floatChannelData else {
            throw PremiumAudioPlaybackError.unsupportedFormat
        }
        let channelCount = Int(buffer.format.channelCount)
        let frameCount = Int(buffer.frameLength)

        guard appliedGain > 1 else { return }
        for channel in 0..<channelCount {
            let samples = channelData[channel]
            for frame in 0..<frameCount {
                if frame.isMultiple(of: 2_048) { try Task.checkCancellation() }
                samples[frame] *= appliedGain
            }
        }
    }
}

enum PremiumAudioPreparer {
#if INTERNAL_AUDIO_CALIBRATION
    static func processingProfile(defaults: UserDefaults = .standard) -> SpeechProcessingProfile {
        SpeechCalibrationRuntimeProfileStore(defaults: defaults).activeProfile() ?? .production
    }
#endif

    static func prepare(dataSegments: [Data]) async throws -> PreparedPremiumAudio {
#if INTERNAL_AUDIO_CALIBRATION
        let profile = processingProfile()
#else
        let profile = SpeechProcessingProfile.production
#endif
        return try await DefaultPremiumSpeechProcessor().prepare(
            speechAudio: dataSegments,
            profile: profile
        )
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        let components = self.components
        return TimeInterval(components.seconds)
            + TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000
    }
}
