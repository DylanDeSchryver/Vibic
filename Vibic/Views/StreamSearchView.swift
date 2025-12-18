import SwiftUI

struct StreamSearchView: View {
    @StateObject private var musicRecognition = MusicRecognitionService.shared
    
    @State private var searchText = ""
    @State private var searchResults: [YouTubeSearchResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var showingSettings = false
    @State private var selectedVideo: YouTubeSearchResult?
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    if searchResults.isEmpty && !isSearching && searchText.isEmpty {
                        emptyStateView
                    } else if isSearching {
                        loadingView
                    } else if let error = errorMessage, searchResults.isEmpty {
                        errorView(error)
                    } else {
                        resultsList
                    }
                }
                
                // Micro player overlay
                if let video = selectedVideo {
                    YouTubeMicroPlayer(
                        videoId: video.id,
                        title: video.title,
                        artist: video.artist,
                        thumbnailURL: video.thumbnailURL,
                        onClose: {
                            withAnimation {
                                selectedVideo = nil
                            }
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Search for songs, artists...")
            .onSubmit(of: .search) {
                performSearch()
            }
            .onChange(of: searchText) { _, newValue in
                if newValue.isEmpty {
                    searchTask?.cancel()
                    searchResults = []
                    errorMessage = nil
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            // Shazam Identify Button
            shazamButton
                .padding(.bottom, 20)
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("Search for Music")
                .font(.title2)
                .fontWeight(.semibold)
            
            if !hasAPIKey {
                Text("A YouTube API key is required to search.\nTap the settings button to add your free API key.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Button {
                    showingSettings = true
                } label: {
                    Label("Open Settings", systemImage: "gear")
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            } else {
                Text("Find songs and stream them instantly.\nTap play to open the embedded player.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
        .onChange(of: musicRecognition.identifiedSong?.searchQuery) { oldValue, newValue in
            if let query = newValue, !query.isEmpty {
                // Auto-fill search and trigger search
                searchText = query
                performSearch()
            }
        }
    }
    
    private var shazamButton: some View {
        Button {
            if musicRecognition.isListening {
                musicRecognition.stopListening()
            } else {
                Task {
                    await musicRecognition.startListening()
                }
            }
        } label: {
            VStack(spacing: 12) {
                ZStack {
                    // Progress ring
                    if musicRecognition.isListening {
                        Circle()
                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 4)
                            .frame(width: 88, height: 88)
                        
                        Circle()
                            .trim(from: 0, to: musicRecognition.recordingProgress)
                            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 88, height: 88)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.1), value: musicRecognition.recordingProgress)
                    }
                    
                    Circle()
                        .fill(musicRecognition.isListening ? Color.accentColor : Color(.tertiarySystemFill))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: musicRecognition.isListening ? "waveform" : "music.note.list")
                        .font(.system(size: 32))
                        .foregroundStyle(musicRecognition.isListening ? Color.white : Color.accentColor)
                        .symbolEffect(.variableColor.iterative, isActive: musicRecognition.isListening)
                }
                
                Text(musicRecognition.isListening ? "Listening..." : "Identify Song")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(musicRecognition.isListening ? Color.accentColor : Color.primary)
            }
        }
        .buttonStyle(.plain)
        .alert("Identification Failed", isPresented: .init(
            get: { musicRecognition.errorMessage != nil },
            set: { if !$0 { musicRecognition.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(musicRecognition.errorMessage ?? "")
        }
    }
    
    private var hasAPIKey: Bool {
        let key = UserDefaults.standard.string(forKey: "youtubeAPIKey")
        return key != nil && !key!.isEmpty
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("Searching...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundStyle(.orange)
            
            Text("Search Failed")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Try Again") {
                performSearch()
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
    }
    
    private var resultsList: some View {
        List {
            ForEach(searchResults) { result in
                StreamSearchResultRow(
                    result: result,
                    onPlay: {
                        playResult(result)
                    }
                )
            }
        }
        .listStyle(.plain)
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        // Cancel any existing search
        searchTask?.cancel()
        
        isSearching = true
        errorMessage = nil
        
        searchTask = Task {
            do {
                let results = try await YouTubeService.shared.search(query: searchText)
                
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    if results.isEmpty {
                        errorMessage = "No results found for \"\(searchText)\""
                    }
                    searchResults = results
                    isSearching = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSearching = false
                }
            }
        }
    }
    
    private func playResult(_ result: YouTubeSearchResult) {
        // Open the embedded micro player instead of extracting audio
        withAnimation {
            selectedVideo = result
        }
    }
}

// MARK: - Stream Search Result Row

struct StreamSearchResultRow: View {
    let result: YouTubeSearchResult
    let onPlay: () -> Void
    
    @State private var thumbnailImage: UIImage?
    @State private var isLoadingThumbnail = false
    
    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 12) {
                // Thumbnail
                thumbnailView
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.title)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    
                    HStack(spacing: 4) {
                        Text(result.artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        
                        if let duration = result.duration {
                            Text("•")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text(duration)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Play icon
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .task {
            await loadThumbnail()
        }
    }
    
    private var thumbnailView: some View {
        Group {
            if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .overlay {
                        if isLoadingThumbnail {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else {
                            Image(systemName: "music.note")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                    }
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    private func loadThumbnail() async {
        guard thumbnailImage == nil else { return }
        isLoadingThumbnail = true
        
        if let data = await YouTubeService.shared.getThumbnail(videoId: result.id),
           let image = UIImage(data: data) {
            await MainActor.run {
                thumbnailImage = image
                isLoadingThumbnail = false
            }
        } else {
            await MainActor.run {
                isLoadingThumbnail = false
            }
        }
    }
}

#Preview {
    StreamSearchView()
}
