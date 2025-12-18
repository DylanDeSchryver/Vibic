import SwiftUI
import WebKit

// MARK: - YouTube Embed Player Controller

class YouTubeEmbedPlayerController: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isReady = false
    @Published var isLoading = true
    
    weak var webView: WKWebView?
    
    func play() {
        webView?.evaluateJavaScript("player.playVideo();", completionHandler: nil)
    }
    
    func pause() {
        webView?.evaluateJavaScript("player.pauseVideo();", completionHandler: nil)
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func seek(to seconds: Double) {
        webView?.evaluateJavaScript("player.seekTo(\(seconds), true);", completionHandler: nil)
    }
    
    func setVolume(_ volume: Int) {
        let clampedVolume = max(0, min(100, volume))
        webView?.evaluateJavaScript("player.setVolume(\(clampedVolume));", completionHandler: nil)
    }
}

// MARK: - YouTube Embed WebView

struct YouTubeEmbedWebView: UIViewRepresentable {
    let videoId: String
    @ObservedObject var controller: YouTubeEmbedPlayerController
    
    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "playerState")
        config.userContentController = contentController
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        
        controller.webView = webView
        
        let html = generateEmbedHTML(videoId: videoId)
        webView.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com"))
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Video ID changes handled by parent view recreating this view
    }
    
    private func generateEmbedHTML(videoId: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                html, body { 
                    width: 100%; 
                    height: 100%; 
                    background: transparent;
                    overflow: hidden;
                }
                #player {
                    position: absolute;
                    top: 0;
                    left: 0;
                    width: 100%;
                    height: 100%;
                }
            </style>
        </head>
        <body>
            <div id="player"></div>
            <script>
                var player;
                var updateInterval;
                
                var tag = document.createElement('script');
                tag.src = "https://www.youtube.com/iframe_api";
                var firstScriptTag = document.getElementsByTagName('script')[0];
                firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);
                
                function onYouTubeIframeAPIReady() {
                    player = new YT.Player('player', {
                        videoId: '\(videoId)',
                        playerVars: {
                            'playsinline': 1,
                            'controls': 0,
                            'disablekb': 1,
                            'fs': 0,
                            'modestbranding': 1,
                            'rel': 0,
                            'showinfo': 0,
                            'iv_load_policy': 3,
                            'origin': 'https://www.youtube.com'
                        },
                        events: {
                            'onReady': onPlayerReady,
                            'onStateChange': onPlayerStateChange
                        }
                    });
                }
                
                function onPlayerReady(event) {
                    var duration = player.getDuration();
                    sendMessage('ready', { duration: duration });
                    
                    updateInterval = setInterval(function() {
                        if (player && player.getCurrentTime) {
                            var time = player.getCurrentTime();
                            var dur = player.getDuration();
                            sendMessage('timeUpdate', { currentTime: time, duration: dur });
                        }
                    }, 250);
                }
                
                function onPlayerStateChange(event) {
                    var states = {
                        '-1': 'unstarted',
                        '0': 'ended',
                        '1': 'playing',
                        '2': 'paused',
                        '3': 'buffering',
                        '5': 'cued'
                    };
                    sendMessage('stateChange', { state: states[event.data] || 'unknown', stateCode: event.data });
                }
                
                function sendMessage(type, data) {
                    window.webkit.messageHandlers.playerState.postMessage({
                        type: type,
                        data: data
                    });
                }
            </script>
        </body>
        </html>
        """
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let controller: YouTubeEmbedPlayerController
        
        init(controller: YouTubeEmbedPlayerController) {
            self.controller = controller
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let type = body["type"] as? String,
                  let data = body["data"] as? [String: Any] else { return }
            
            DispatchQueue.main.async { [weak self] in
                switch type {
                case "ready":
                    self?.controller.isReady = true
                    self?.controller.isLoading = false
                    if let duration = data["duration"] as? Double {
                        self?.controller.duration = duration
                    }
                    
                case "stateChange":
                    if let state = data["state"] as? String {
                        self?.controller.isPlaying = (state == "playing")
                        if state == "playing" {
                            self?.controller.isLoading = false
                        } else if state == "buffering" {
                            self?.controller.isLoading = true
                        }
                    }
                    
                case "timeUpdate":
                    if let time = data["currentTime"] as? Double {
                        self?.controller.currentTime = time
                    }
                    if let duration = data["duration"] as? Double {
                        self?.controller.duration = duration
                    }
                    
                default:
                    break
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Page loaded
        }
    }
}

// MARK: - Micro Player View

struct YouTubeMicroPlayer: View {
    let videoId: String
    let title: String
    let artist: String
    let thumbnailURL: String?
    let onClose: () -> Void
    
    @StateObject private var controller = YouTubeEmbedPlayerController()
    @State private var thumbnailImage: UIImage?
    @State private var isDragging = false
    @State private var dragOffset: Double = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Hidden WebView (plays audio from video)
            YouTubeEmbedWebView(videoId: videoId, controller: controller)
                .frame(width: 1, height: 1)
                .opacity(0.01)
            
            // Player UI
            VStack(spacing: 12) {
                // Track info row
                HStack(spacing: 12) {
                    // Thumbnail
                    thumbnailView
                    
                    // Title and artist
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        
                        Text(artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Close button
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Progress bar
                VStack(spacing: 4) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 4)
                            
                            // Progress
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.accentColor)
                                .frame(width: progressWidth(in: geometry.size.width), height: 4)
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isDragging = true
                                    let progress = max(0, min(1, value.location.x / geometry.size.width))
                                    dragOffset = progress * controller.duration
                                }
                                .onEnded { value in
                                    let progress = max(0, min(1, value.location.x / geometry.size.width))
                                    let seekTime = progress * controller.duration
                                    controller.seek(to: seekTime)
                                    isDragging = false
                                }
                        )
                    }
                    .frame(height: 4)
                    
                    // Time labels
                    HStack {
                        Text(formatTime(isDragging ? dragOffset : controller.currentTime))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        
                        Spacer()
                        
                        Text(formatTime(controller.duration))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                
                // Controls
                HStack(spacing: 32) {
                    // Rewind 10s
                    Button {
                        controller.seek(to: max(0, controller.currentTime - 10))
                    } label: {
                        Image(systemName: "gobackward.10")
                            .font(.title2)
                    }
                    .disabled(!controller.isReady)
                    
                    // Play/Pause
                    Button {
                        controller.togglePlayPause()
                    } label: {
                        if controller.isLoading {
                            ProgressView()
                                .frame(width: 44, height: 44)
                        } else {
                            Image(systemName: controller.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 44))
                        }
                    }
                    .disabled(!controller.isReady && !controller.isLoading)
                    
                    // Forward 10s
                    Button {
                        controller.seek(to: min(controller.duration, controller.currentTime + 10))
                    } label: {
                        Image(systemName: "goforward.10")
                            .font(.title2)
                    }
                    .disabled(!controller.isReady)
                }
                .foregroundStyle(Color.accentColor)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
            )
            .padding(.horizontal)
        }
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
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        guard controller.duration > 0 else { return 0 }
        let time = isDragging ? dragOffset : controller.currentTime
        let progress = time / controller.duration
        return totalWidth * CGFloat(progress)
    }
    
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func loadThumbnail() async {
        guard let urlString = thumbnailURL,
              let url = URL(string: urlString) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    thumbnailImage = image
                }
            }
        } catch {
            // Fallback to YouTube thumbnail
            if let data = await YouTubeService.shared.getThumbnail(videoId: videoId),
               let image = UIImage(data: data) {
                await MainActor.run {
                    thumbnailImage = image
                }
            }
        }
    }
}

#Preview {
    VStack {
        Spacer()
        YouTubeMicroPlayer(
            videoId: "dQw4w9WgXcQ",
            title: "Never Gonna Give You Up",
            artist: "Rick Astley",
            thumbnailURL: nil,
            onClose: {}
        )
    }
}
