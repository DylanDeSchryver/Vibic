import Foundation
import AVFoundation
import Combine

// MARK: - EQ Preset

enum EQPreset: String, CaseIterable, Identifiable {
    case flat = "Flat"
    case bassBoost = "Bass Boost"
    case bassCut = "Bass Cut"
    case trebleBoost = "Treble Boost"
    case trebleCut = "Treble Cut"
    case vocal = "Vocal"
    case electronic = "Electronic"
    case hiphop = "Hip-Hop"
    case rock = "Rock"
    case jazz = "Jazz"
    case classical = "Classical"
    case podcast = "Podcast"
    case custom = "Custom"
    
    var id: String { rawValue }
    
    var bands: [Float] {
        switch self {
        case .flat:
            return [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        case .bassBoost:
            return [6, 5, 4, 2, 0, 0, 0, 0, 0, 0]
        case .bassCut:
            return [-6, -5, -4, -2, 0, 0, 0, 0, 0, 0]
        case .trebleBoost:
            return [0, 0, 0, 0, 0, 0, 2, 4, 5, 6]
        case .trebleCut:
            return [0, 0, 0, 0, 0, 0, -2, -4, -5, -6]
        case .vocal:
            return [-2, -1, 0, 2, 4, 4, 3, 1, 0, -1]
        case .electronic:
            return [5, 4, 1, 0, -2, 0, 1, 3, 4, 5]
        case .hiphop:
            return [5, 4, 1, 3, -1, -1, 1, 0, 2, 3]
        case .rock:
            return [5, 4, 2, 0, -1, 0, 2, 3, 4, 4]
        case .jazz:
            return [3, 2, 1, 2, -1, -1, 0, 1, 2, 3]
        case .classical:
            return [4, 3, 2, 1, -1, -1, 0, 2, 3, 4]
        case .podcast:
            return [-2, 0, 2, 4, 4, 3, 2, 1, 0, -1]
        case .custom:
            return [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        }
    }
}

// MARK: - Frequency Band

struct FrequencyBand: Identifiable {
    let id: Int
    let frequency: Int
    var gain: Float
    
    var label: String {
        if frequency >= 1000 {
            return "\(frequency / 1000)k"
        }
        return "\(frequency)"
    }
}

// MARK: - Equalizer Manager

final class EqualizerManager: ObservableObject {
    static let shared = EqualizerManager()
    
    // Standard 10-band EQ frequencies (Hz)
    static let frequencies = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "eqEnabled")
            applyEQ()
        }
    }
    
    @Published var bands: [FrequencyBand] {
        didSet {
            saveBands()
            applyEQ()
        }
    }
    
    @Published var currentPreset: EQPreset {
        didSet {
            UserDefaults.standard.set(currentPreset.rawValue, forKey: "eqPreset")
            if currentPreset != .custom {
                applyPreset(currentPreset)
            }
        }
    }
    
    // AVAudioEngine components for EQ processing
    private var audioEngine: AVAudioEngine?
    private var eqNode: AVAudioUnitEQ?
    
    private init() {
        // Load saved settings
        self.isEnabled = UserDefaults.standard.bool(forKey: "eqEnabled")
        
        let presetName = UserDefaults.standard.string(forKey: "eqPreset") ?? EQPreset.flat.rawValue
        self.currentPreset = EQPreset(rawValue: presetName) ?? .flat
        
        // Initialize bands
        self.bands = Self.frequencies.enumerated().map { index, freq in
            FrequencyBand(id: index, frequency: freq, gain: 0)
        }
        
        // Load saved band values
        loadBands()
        
        // Setup audio engine
        setupAudioEngine()
    }
    
    // MARK: - Audio Engine Setup
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        
        // Create 10-band parametric EQ
        eqNode = AVAudioUnitEQ(numberOfBands: 10)
        
        guard let eq = eqNode else { return }
        
        // Configure each band
        for (index, freq) in Self.frequencies.enumerated() {
            let band = eq.bands[index]
            band.filterType = .parametric
            band.frequency = Float(freq)
            band.bandwidth = 1.0 // Q factor
            band.gain = bands[index].gain
            band.bypass = false
        }
    }
    
    // MARK: - EQ Application
    
    func applyEQ() {
        guard let eq = eqNode, isEnabled else {
            // Bypass all bands if disabled
            eqNode?.bands.forEach { $0.bypass = true }
            return
        }
        
        for (index, band) in bands.enumerated() {
            eq.bands[index].gain = band.gain
            eq.bands[index].bypass = false
        }
        
        // Notify AudioPlaybackEngine to apply EQ
        NotificationCenter.default.post(name: .eqSettingsChanged, object: nil)
    }
    
    // MARK: - Presets
    
    func applyPreset(_ preset: EQPreset) {
        let gains = preset.bands
        for (index, gain) in gains.enumerated() {
            bands[index] = FrequencyBand(
                id: index,
                frequency: Self.frequencies[index],
                gain: gain
            )
        }
    }
    
    func setBandGain(at index: Int, gain: Float) {
        guard index >= 0 && index < bands.count else { return }
        bands[index] = FrequencyBand(
            id: index,
            frequency: Self.frequencies[index],
            gain: gain
        )
        
        // When user manually adjusts, switch to custom preset
        if currentPreset != .custom {
            currentPreset = .custom
        }
    }
    
    // MARK: - Persistence
    
    private func saveBands() {
        let gains = bands.map { $0.gain }
        UserDefaults.standard.set(gains, forKey: "eqBands")
    }
    
    private func loadBands() {
        guard let gains = UserDefaults.standard.array(forKey: "eqBands") as? [Float],
              gains.count == Self.frequencies.count else { return }
        
        bands = Self.frequencies.enumerated().map { index, freq in
            FrequencyBand(id: index, frequency: freq, gain: gains[index])
        }
    }
    
    // MARK: - Reset
    
    func reset() {
        currentPreset = .flat
        applyPreset(.flat)
    }
    
    // MARK: - Get EQ Node for Audio Engine
    
    func getEQNode() -> AVAudioUnitEQ? {
        return eqNode
    }
    
    func getCurrentGains() -> [Float] {
        return bands.map { $0.gain }
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let eqSettingsChanged = Notification.Name("eqSettingsChanged")
}
