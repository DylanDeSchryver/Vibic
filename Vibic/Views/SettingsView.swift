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
    @AppStorage("youtubeAPIKey") private var youtubeAPIKey = ""
    @AppStorage("acrCloudAccessKey") private var acrCloudAccessKey = ""
    @AppStorage("acrCloudAccessSecret") private var acrCloudAccessSecret = ""
    
    @State private var showingResetAlert = false
    @State private var showingAPIKeyInfo = false
    @State private var showingACRCloudInfo = false
    @State private var showingEqualizer = false
    
    @ObservedObject private var eqManager = EqualizerManager.shared
    
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
                
                // MARK: - Equalizer Section
                Section {
                    Button {
                        showingEqualizer = true
                    } label: {
                        HStack {
                            Text("Equalizer")
                                .foregroundStyle(.primary)
                            Spacer()
                            HStack(spacing: 6) {
                                Text(eqManager.isEnabled ? eqManager.currentPreset.rawValue : "Off")
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Label("Sound", systemImage: "slider.horizontal.3")
                } footer: {
                    Text("Customize audio output with a 10-band equalizer and presets.")
                }
                
                // MARK: - Appearance Section
                Section {
                    NavigationLink {
                        ThemePickerView()
                    } label: {
                        HStack {
                            Text("Theme Color")
                            Spacer()
                            Circle()
                                .fill(ThemeManager.shared.accentColor)
                                .frame(width: 24, height: 24)
                        }
                    }
                    
                    Toggle("Keep Screen Awake", isOn: $keepScreenAwake)
                        .onChange(of: keepScreenAwake) { _, newValue in
                            UIApplication.shared.isIdleTimerDisabled = newValue
                        }
                } header: {
                    Label("Appearance", systemImage: "paintbrush")
                } footer: {
                    Text("Customize the app's accent color. Keep Screen Awake prevents dimming while playing.")
                }
                
                // MARK: - Streaming Section
                Section {
                    HStack {
                        Text("YouTube API Key")
                        Spacer()
                        if youtubeAPIKey.isEmpty {
                            Text("Not Set")
                                .foregroundStyle(.red)
                        } else {
                            Text("Configured")
                                .foregroundStyle(.green)
                        }
                    }
                    
                    SecureField("Enter API Key", text: $youtubeAPIKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    
                    Button {
                        showingAPIKeyInfo = true
                    } label: {
                        HStack {
                            Text("How to Get an API Key")
                            Spacer()
                            Image(systemName: "questionmark.circle")
                        }
                    }
                } header: {
                    Label("Music Search", systemImage: "magnifyingglass")
                } footer: {
                    Text("A free YouTube Data API key is required to search for music. The free tier allows 10,000 searches per day.")
                }
                
                // MARK: - Music Recognition Section
                Section {
                    HStack {
                        Text("ACRCloud Status")
                        Spacer()
                        if acrCloudAccessKey.isEmpty || acrCloudAccessSecret.isEmpty {
                            Text("Not Set")
                                .foregroundStyle(.red)
                        } else {
                            Text("Configured")
                                .foregroundStyle(.green)
                        }
                    }
                    
                    SecureField("Access Key", text: $acrCloudAccessKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    
                    SecureField("Access Secret", text: $acrCloudAccessSecret)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    
                    Button {
                        showingACRCloudInfo = true
                    } label: {
                        HStack {
                            Text("How to Get ACRCloud Keys")
                            Spacer()
                            Image(systemName: "questionmark.circle")
                        }
                    }
                } header: {
                    Label("Music Recognition", systemImage: "waveform")
                } footer: {
                    Text("ACRCloud is used to identify songs playing around you. Free tier allows 100 identifications per day.")
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
            .sheet(isPresented: $showingAPIKeyInfo) {
                APIKeyInfoView()
            }
            .sheet(isPresented: $showingACRCloudInfo) {
                ACRCloudInfoView()
            }
            .sheet(isPresented: $showingEqualizer) {
                EqualizerView()
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
        // Note: API keys are NOT reset for safety
        
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

// MARK: - Theme Picker View

struct ThemePickerView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        List {
            Section {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Button {
                        withAnimation {
                            themeManager.currentTheme = theme
                        }
                    } label: {
                        HStack(spacing: 16) {
                            // Color preview circle with gradient
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: theme.gradientColors,
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 36, height: 36)
                            }
                            
                            Text(theme.rawValue)
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            if themeManager.currentTheme == theme {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(theme.color)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            } footer: {
                Text("The accent color is used throughout the app for buttons, highlights, and the player interface.")
            }
        }
        .navigationTitle("Theme Color")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - API Key Info View

struct APIKeyInfoView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("How to Get a Free YouTube API Key")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        instructionStep(
                            number: 1,
                            title: "Go to Google Cloud Console",
                            detail: "Visit console.cloud.google.com and sign in with your Google account."
                        )
                        
                        instructionStep(
                            number: 2,
                            title: "Create a New Project",
                            detail: "Click 'Select a Project' → 'New Project'. Name it anything (e.g., 'Vibic App')."
                        )
                        
                        instructionStep(
                            number: 3,
                            title: "Enable YouTube Data API",
                            detail: "Go to 'APIs & Services' → 'Library'. Search for 'YouTube Data API v3' and click 'Enable'."
                        )
                        
                        instructionStep(
                            number: 4,
                            title: "Create API Credentials",
                            detail: "Go to 'APIs & Services' → 'Credentials'. Click 'Create Credentials' → 'API Key'."
                        )
                        
                        instructionStep(
                            number: 5,
                            title: "Copy Your API Key",
                            detail: "Copy the generated API key and paste it in the Settings above."
                        )
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Free Tier Limits")
                            .font(.headline)
                        
                        Text("• 10,000 units per day (about 100 searches)")
                        Text("• No credit card required")
                        Text("• Resets daily at midnight Pacific Time")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    
                    Link(destination: URL(string: "https://console.cloud.google.com")!) {
                        HStack {
                            Text("Open Google Cloud Console")
                            Image(systemName: "arrow.up.right.square")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding()
            }
            .navigationTitle("API Key Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func instructionStep(number: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 28, height: 28)
                Text("\(number)")
                    .font(.callout)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - ACRCloud Info View

struct ACRCloudInfoView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("How to Get Free ACRCloud Keys")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        instructionStep(
                            number: 1,
                            title: "Create an ACRCloud Account",
                            detail: "Visit console.acrcloud.com and sign up for a free account."
                        )
                        
                        instructionStep(
                            number: 2,
                            title: "Create a New Project",
                            detail: "Click 'Create Project' and select 'Audio & Video Recognition'. Choose 'Music' as the recognition type."
                        )
                        
                        instructionStep(
                            number: 3,
                            title: "Select a Region",
                            detail: "Choose a region close to you (e.g., us-west-2). The default host will work for most users."
                        )
                        
                        instructionStep(
                            number: 4,
                            title: "Copy Your Credentials",
                            detail: "After creating the project, you'll see your Access Key and Access Secret. Copy both values."
                        )
                        
                        instructionStep(
                            number: 5,
                            title: "Paste in Settings",
                            detail: "Paste the Access Key and Access Secret in the fields above."
                        )
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Free Tier Limits")
                            .font(.headline)
                        
                        Text("• 100 recognitions per day")
                        Text("• No credit card required")
                        Text("• Identifies most commercial music")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    
                    Link(destination: URL(string: "https://console.acrcloud.com")!) {
                        HStack {
                            Text("Open ACRCloud Console")
                            Image(systemName: "arrow.up.right.square")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding()
            }
            .navigationTitle("ACRCloud Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func instructionStep(number: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 28, height: 28)
                Text("\(number)")
                    .font(.callout)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    SettingsView()
}
