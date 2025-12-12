import SwiftUI

struct LazyArtworkView: View {
    let trackId: UUID?
    let artworkData: Data?
    let size: CGSize
    let cornerRadius: CGFloat
    
    @State private var thumbnail: UIImage?
    @State private var isLoading = true
    
    init(trackId: UUID?, artworkData: Data?, size: CGFloat, cornerRadius: CGFloat = 8) {
        self.trackId = trackId
        self.artworkData = artworkData
        self.size = CGSize(width: size, height: size)
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        Group {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholderView
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .onAppear {
            loadThumbnail()
        }
        .id(trackId)
    }
    
    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.gray.opacity(0.2))
            .overlay {
                if isLoading && artworkData != nil {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "music.note")
                        .font(size.width > 50 ? .title2 : .caption)
                        .foregroundStyle(.gray)
                }
            }
    }
    
    private func loadThumbnail() {
        // Try sync first (cache hit)
        if let cached = ImageCache.shared.thumbnail(for: trackId, artworkData: artworkData, size: size) {
            thumbnail = cached
            isLoading = false
            return
        }
        
        // Load async
        ImageCache.shared.thumbnailAsync(for: trackId, artworkData: artworkData, size: size) { image in
            thumbnail = image
            isLoading = false
        }
    }
}

struct LazyArtworkView_Equatable: View, Equatable {
    let trackId: UUID?
    let artworkData: Data?
    let size: CGFloat
    let cornerRadius: CGFloat
    
    static func == (lhs: LazyArtworkView_Equatable, rhs: LazyArtworkView_Equatable) -> Bool {
        lhs.trackId == rhs.trackId && lhs.size == rhs.size
    }
    
    var body: some View {
        LazyArtworkView(trackId: trackId, artworkData: artworkData, size: size, cornerRadius: cornerRadius)
    }
}

#Preview {
    VStack {
        LazyArtworkView(trackId: UUID(), artworkData: nil, size: 60)
        LazyArtworkView(trackId: UUID(), artworkData: nil, size: 44)
    }
}
