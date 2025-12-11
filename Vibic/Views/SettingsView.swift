import SwiftUI

struct SettingsView: View {
    // Use direct reference instead of @EnvironmentObject to avoid re-renders from currentTime updates
    private let playbackEngine = AudioPlaybackEngine.shared
    
    @AppStorage("keepScreenAwake") private var keepScreenAwake = false
    @AppStorage("defaultRepeatMode") private var defaultRepeatMode = 0
    @AppStorage("gaplessPlayback") private var gaplessPlayback = true
    @AppStorage("crossfadeEnabled") private var crossfadeEnabled = false
    @AppStorage("crossfadeDuration") private var crossfadeDuration = 3.0
    @AppStorage("lyricsAutoScroll") private var lyricsAutoScroll = true
    @AppStorage("lyricsFontSize") private var lyricsFontSize = 1 // 0=small, 1=medium, 2=large
    
    @State private var showingResetAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Playback Section
                Section {
                    Toggle("Gapless Playback", isOn: $gaplessPlayback)
                        .disabled(crossfadeEnabled)
                        .onChange(of: gaplessPlayback) { _, newValue in
                            playbackEngine.gaplessPlayback = newValue
                        }
                    
                    Toggle("Crossfade", isOn: $crossfadeEnabled)
                        .onChange(of: crossfadeEnabled) { _, newValue in
                            playbackEngine.crossfadeEnabled = newValue
                            if newValue {
                                gaplessPlayback = false
                                playbackEngine.gaplessPlayback = false
                            }
                        }
                    
                    if crossfadeEnabled {
                        HStack {
                            Text("Crossfade Duration")
                            Spacer()
                            Text("\(crossfadeDuration, specifier: "%.1f")s")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $crossfadeDuration, in: 1...10, step: 0.5)
                            .onChange(of: crossfadeDuration) { _, newValue in
                                playbackEngine.crossfadeDuration = newValue
                            }
                    }
                    
                    Picker("Default Repeat Mode", selection: $defaultRepeatMode) {
                        Text("Off").tag(0)
                        Text("Repeat All").tag(1)
                        Text("Repeat One").tag(2)
                    }
                    .onChange(of: defaultRepeatMode) { _, newValue in
                        playbackEngine.setDefaultRepeatMode(newValue)
                    }
                } header: {
                    Label("Playback", systemImage: "play.circle")
                } footer: {
                    Text("Gapless removes silence between tracks. Crossfade smoothly blends the end of one track into the next.")
                }
                
                // MARK: - Display Section
                Section {
                    Toggle("Keep Screen Awake", isOn: $keepScreenAwake)
                        .onChange(of: keepScreenAwake) { _, newValue in
                            UIApplication.shared.isIdleTimerDisabled = newValue
                        }
                } header: {
                    Label("Display", systemImage: "display")
                } footer: {
                    Text("Prevents the screen from dimming while playing music.")
                }
                
                // MARK: - Lyrics Section
                Section {
                    Toggle("Auto-scroll Lyrics", isOn: $lyricsAutoScroll)
                    
                    NavigationLink {
                        FontSizePickerView()
                    } label: {
                        HStack {
                            Text("Font Size")
                            Spacer()
                            Text(fontSizeLabel)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Label("Lyrics", systemImage: "text.quote")
                } footer: {
                    Text("Auto-scroll keeps the current lyric line centered on screen.")
                }
                
                // MARK: - About Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text(buildNumber)
                            .foregroundStyle(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://github.com/DylanDeSchryver/Vibic")!) {
                        HStack {
                            Text("GitHub Repository")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Label("About", systemImage: "info.circle")
                }
                
                // MARK: - Reset Section
                Section {
                    Button(role: .destructive) {
                        showingResetAlert = true
                    } label: {
                        HStack {
                            Text("Reset All Settings")
                            Spacer()
                            Image(systemName: "arrow.counterclockwise")
                        }
                    }
                } footer: {
                    Text("This will reset all settings to their default values. Your music library will not be affected.")
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                syncSettingsToEngine()
            }
            .alert("Reset Settings", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetAllSettings()
                }
            } message: {
                Text("Are you sure you want to reset all settings to their default values?")
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    private var fontSizeLabel: String {
        switch lyricsFontSize {
        case 0: return "Small"
        case 2: return "Large"
        default: return "Medium"
        }
    }
    
    // MARK: - Methods
    
    private func syncSettingsToEngine() {
        playbackEngine.gaplessPlayback = gaplessPlayback
        playbackEngine.crossfadeEnabled = crossfadeEnabled
        playbackEngine.crossfadeDuration = crossfadeDuration
        playbackEngine.setDefaultRepeatMode(defaultRepeatMode)
    }
    
    private func resetAllSettings() {
        keepScreenAwake = false
        defaultRepeatMode = 0
        gaplessPlayback = true
        crossfadeEnabled = false
        crossfadeDuration = 3.0
        lyricsAutoScroll = true
        lyricsFontSize = 1
        
        UIApplication.shared.isIdleTimerDisabled = false
        syncSettingsToEngine()
    }
}

// MARK: - Font Size Picker View (Isolated from parent re-renders)

struct FontSizePickerView: View {
    @AppStorage("lyricsFontSize") private var lyricsFontSize = 1
    
    var body: some View {
        List {
            Section {
                ForEach([
                    (0, "Small", "Compact text size"),
                    (1, "Medium", "Default text size"),
                    (2, "Large", "Larger, easier to read")
                ], id: \.0) { size, label, description in
                    Button {
                        lyricsFontSize = size
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(label)
                                    .foregroundStyle(.primary)
                                Text(description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if lyricsFontSize == size {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.accent)
                            }
                        }
                    }
                }
            } footer: {
                Text("Changes apply immediately to the lyrics view.")
            }
        }
        .navigationTitle("Font Size")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView()
}
