import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct FileBrowserView: View {
    @EnvironmentObject var libraryController: LibraryController
    @State private var showingFilePicker = false
    @State private var showingFolderPicker = false
    @State private var showingImportAlert = false
    @State private var importMessage = ""
    
    // Workaround: Use separate views for each file importer to avoid conflicts
    @State private var filePickerID = UUID()
    
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
            .sheet(isPresented: $showingFilePicker) {
                DocumentPickerView(
                    contentTypes: [.audio, .mp3, .mpeg4Audio, .wav, .aiff],
                    allowsMultipleSelection: true
                ) { urls in
                    handleFileImport(.success(urls))
                }
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
        var types: [UTType] = [.mp3, .mpeg4Audio, .wav, .aiff]
        // Add additional audio types that may be available
        if let flac = UTType("org.xiph.flac") {
            types.append(flac)
        }
        if let aac = UTType("public.aac-audio") {
            types.append(aac)
        }
        // Add generic audio as fallback
        types.append(.audio)
        return types
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

// MARK: - Document Picker (UIKit wrapper)

struct DocumentPickerView: UIViewControllerRepresentable {
    let contentTypes: [UTType]
    let allowsMultipleSelection: Bool
    let onPick: ([URL]) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
        picker.allowsMultipleSelection = allowsMultipleSelection
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void
        
        init(onPick: @escaping ([URL]) -> Void) {
            self.onPick = onPick
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls)
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onPick([])
        }
    }
}

#Preview {
    FileBrowserView()
        .environmentObject(LibraryController.shared)
}
