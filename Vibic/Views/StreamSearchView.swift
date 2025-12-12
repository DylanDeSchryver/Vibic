import SwiftUI

struct StreamSearchView: View {
    @EnvironmentObject var libraryController: LibraryController
    @EnvironmentObject var playbackEngine: AudioPlaybackEngine
    
    @State private var searchText = ""
    @State private var searchResults: [YouTubeSearchResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var addedVideoIds: Set<String> = []
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if searchResults.isEmpty && !isSearching && searchText.isEmpty {
                    emptyStateView
                } else if isSearching {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else {
                    resultsList
                }
            }
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Search for music")
            .onSubmit(of: .search) {
                performSearch()
            }
            .onChange(of: searchText) { _, newValue in
                if newValue.isEmpty {
                    searchResults = []
                    errorMessage = nil
                }
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
            
            Text("Find songs to add to your library.\nStreamed tracks work just like your imported music.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
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
        
        isSearching = true
        errorMessage = nil
        
        Task {
            do {
                let results = try await YouTubeService.shared.search(query: searchText)
                await MainActor.run {
                    searchResults = results
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSearching = false
                }
            }
        }
    }
    
    private func addToLibrary(_ result: YouTubeSearchResult) {
        addedVideoIds.insert(result.id)
        
        libraryController.addStreamedTrack(from: result) { track in
            // Track added successfully
        }
    }
    
    private func playResult(_ result: YouTubeSearchResult) {
        // First add to library if not already
        if !libraryController.isTrackInLibrary(videoId: result.id) {
            addedVideoIds.insert(result.id)
        }
        
        libraryController.addStreamedTrack(from: result) { track in
            if let track = track {
                playbackEngine.playTrack(track)
            }
        }
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let result: YouTubeSearchResult
    let isInLibrary: Bool
    let onAdd: () -> Void
    let onPlay: () -> Void
    
    @State private var thumbnailImage: UIImage?
    @State private var isLoading = false
    
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
                    onPlay()
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                
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
                        if isLoading {
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
        isLoading = true
        
        if let data = await YouTubeService.shared.getThumbnail(videoId: result.id),
           let image = UIImage(data: data) {
            await MainActor.run {
                thumbnailImage = image
                isLoading = false
            }
        } else {
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

#Preview {
    StreamSearchView()
        .environmentObject(LibraryController.shared)
        .environmentObject(AudioPlaybackEngine.shared)
}
