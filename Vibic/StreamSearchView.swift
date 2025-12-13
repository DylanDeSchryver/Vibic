import SwiftUI

struct StreamSearchView: View {
    @EnvironmentObject var libraryController: LibraryController
    @EnvironmentObject var playbackEngine: AudioPlaybackEngine
    
    @State private var searchText = ""
    @State private var searchResults: [YouTubeSearchResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var addedVideoIds: Set<String> = []
    @State private var loadingVideoId: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var showingSettings = false
    
    var body: some View {
        NavigationStack {
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
                Text("Find songs to add to your library.\nStreamed tracks work just like your imported music.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
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
                SearchResultRow(
                    result: result,
                    isInLibrary: libraryController.isTrackInLibrary(videoId: result.id) || addedVideoIds.contains(result.id),
                    isLoading: loadingVideoId == result.id,
                    onAdd: {
                        addToLibrary(result)
                    },
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
                    
                    // Prefetch stream URLs for top results to speed up playback
                    let videoIds = results.map { $0.id }
                    YouTubeService.shared.prefetchStreamURLs(for: videoIds)
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
    
    private func addToLibrary(_ result: YouTubeSearchResult) {
        addedVideoIds.insert(result.id)
        
        libraryController.addStreamedTrack(from: result) { _ in
            // Track added successfully - UI updates via addedVideoIds
        }
    }
    
    private func playResult(_ result: YouTubeSearchResult) {
        // Show loading indicator
        loadingVideoId = result.id
        
        // Add to library if not already
        if !libraryController.isTrackInLibrary(videoId: result.id) {
            addedVideoIds.insert(result.id)
        }
        
        libraryController.addStreamedTrack(from: result) { [self] track in
            if let track = track {
                playbackEngine.playTrack(track)
            }
            // Clear loading state
            DispatchQueue.main.async {
                loadingVideoId = nil
            }
        }
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let result: YouTubeSearchResult
    let isInLibrary: Bool
    var isLoading: Bool = false
    let onAdd: () -> Void
    let onPlay: () -> Void
    
    @State private var thumbnailImage: UIImage?
    @State private var isLoadingThumbnail = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            thumbnailView
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.body)
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
            
            // Actions
            HStack(spacing: 12) {
                Button {
                    if !isLoading {
                        onPlay()
                    }
                } label: {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 28, height: 28)
                    } else {
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                
                Button {
                    if !isInLibrary {
                        onAdd()
                    }
                } label: {
                    Image(systemName: isInLibrary ? "checkmark.circle.fill" : "plus.circle")
                        .font(.title2)
                        .foregroundStyle(isInLibrary ? Color.green : Color.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(isInLibrary)
            }
        }
        .padding(.vertical, 4)
        .opacity(isLoading ? 0.7 : 1.0)
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
        .environmentObject(LibraryController.shared)
        .environmentObject(AudioPlaybackEngine.shared)
}
