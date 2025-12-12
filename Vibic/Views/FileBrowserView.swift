import SwiftUI
import UniformTypeIdentifiers

struct FileBrowserView: View {
    @EnvironmentObject var libraryController: LibraryController
    @State private var showingFilePicker = false
    @State private var showingFolderPicker = false
    @State private var showingImportAlert = false
    @State private var importMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 80))
                    .foregroundStyle(.accent)
                
                VStack(spacing: 8) {
                    Text("Import Audio Files")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Import audio files or folders from your device to add them to your Vibic library.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                VStack(spacing: 12) {
                    Button {
                        showingFilePicker = true
                    } label: {
                        Label("Browse Files", systemImage: "doc.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button {
                        showingFolderPicker = true
                    } label: {
                        Label("Import Folder as Playlist", systemImage: "folder.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    
                    Text("Supported formats: MP3, M4A, WAV, AAC, FLAC, AIFF")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                VStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    
                    Text("You can also share audio files from other apps directly to Vibic, or use the Files app to copy files to Vibic's documents folder.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("Files")
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: supportedAudioTypes,
                allowsMultipleSelection: true
            ) { result in
                handleFileImport(result)
            }
            .fileImporter(
                isPresented: $showingFolderPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                handleFolderImport(result)
            }
            .alert("Import Result", isPresented: $showingImportAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importMessage)
            }
            .overlay {
                if libraryController.isImporting {
                    ProgressView("Importing...")
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
    
    private var supportedAudioTypes: [UTType] {
        [.audio, .mp3, .mpeg4Audio, .wav, .aiff]
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if urls.isEmpty {
                importMessage = "No files selected."
                showingImportAlert = true
            } else {
                libraryController.importFiles(from: urls)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    if let error = libraryController.importError {
                        importMessage = error
                    } else {
                        importMessage = "Successfully imported \(urls.count) file(s)."
                    }
                    showingImportAlert = true
                }
            }
        case .failure(let error):
            importMessage = "Failed to import: \(error.localizedDescription)"
            showingImportAlert = true
        }
    }
    
    private func handleFolderImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let folderURL = urls.first else {
                importMessage = "No folder selected."
                showingImportAlert = true
                return
            }
            
            libraryController.importFolderAsPlaylist(from: folderURL) { importResult in
                switch importResult {
                case .success(let info):
                    importMessage = "Created playlist \"\(info.playlistName)\" with \(info.trackCount) track(s)."
                    showingImportAlert = true
                case .failure(let error):
                    importMessage = "Failed to import folder: \(error.localizedDescription)"
                    showingImportAlert = true
                }
            }
        case .failure(let error):
            importMessage = "Failed to select folder: \(error.localizedDescription)"
            showingImportAlert = true
        }
    }
}

#Preview {
    FileBrowserView()
        .environmentObject(LibraryController.shared)
}
