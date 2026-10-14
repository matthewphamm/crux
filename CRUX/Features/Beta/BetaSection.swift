import AVKit
import PhotosUI
import SwiftData
import SwiftUI

/// Notes plus a grid of photos and videos for a climb.
struct BetaSection: View {
    @Bindable var climb: Climb

    @Environment(\.modelContext) private var context
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showingCamera = false
    @State private var viewing: BetaMedia?
    @State private var importing = false
    @FocusState private var notesFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.stack) {
            SectionHeader(title: "Beta", trailing: media.isEmpty ? nil : "\(media.count)")

            VStack(alignment: .leading, spacing: 14) {
                TextField("Sequence, foot beta, what to try next…", text: $climb.notes, axis: .vertical)
                    .lineLimit(3...10)
                    .focused($notesFocused)
                    .onChange(of: notesFocused) { _, focused in
                        if !focused { try? context.save() }
                    }

                if !media.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                        ForEach(media) { item in
                            Button { viewing = item } label: { MediaThumbnail(media: item) }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Delete", systemImage: "trash", role: .destructive) {
                                        withAnimation(Theme.spring) { BetaImporter.delete(item, context: context) }
                                    }
                                }
                        }
                    }
                    .animation(Theme.spring, value: media.map(\.id))
                }

                HStack(spacing: 10) {
                    PhotosPicker(selection: $pickerItems, maxSelectionCount: 6, matching: .any(of: [.images, .videos])) {
                        Label(importing ? "Importing…" : "Library", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .disabled(importing)

                    if CameraPicker.isAvailable {
                        Button {
                            showingCamera = true
                        } label: {
                            Label("Camera", systemImage: "camera")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                    }
                }
            }
            .glassCard()
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            importing = true
            Task {
                await BetaImporter.importItems(items, into: climb, context: context)
                pickerItems = []
                importing = false
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { capture in
                BetaImporter.importCaptured(capture, into: climb, context: context)
            }
            .ignoresSafeArea()
        }
        .sheet(item: $viewing) { item in
            MediaViewer(media: item)
        }
    }

    private var media: [BetaMedia] {
        (climb.media ?? []).sorted { $0.createdAt > $1.createdAt }
    }
}

/// Square thumbnail; videos show a poster frame and a play glyph.
struct MediaThumbnail: View {
    let media: BetaMedia
    var size: CGFloat? = nil

    @State private var image: UIImage?

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .frame(width: size, height: size)
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Theme.surfaceRaised
                }
            }
            .overlay(alignment: .bottomLeading) {
                if media.kind == .video {
                    Image(systemName: "play.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(.black.opacity(0.45), in: .circle)
                        .padding(6)
                }
            }
            .clipShape(.rect(cornerRadius: 14))
            .task(id: media.fileName) {
                image = media.kind == .video
                    ? await MediaStore.thumbnail(forVideo: media.fileName)
                    : MediaStore.image(for: media.fileName)
            }
            .accessibilityLabel(media.kind == .video ? "Beta video" : "Beta photo")
    }
}

/// Full-screen viewer with inline video playback.
struct MediaViewer: View {
    let media: BetaMedia
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                switch media.kind {
                case .video:
                    if let player {
                        VideoPlayer(player: player)
                            .onAppear { player.play() }
                    }
                case .photo:
                    if let image = MediaStore.image(for: media.fileName) {
                        Image(uiImage: image).resizable().scaledToFit()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Text(media.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear {
            if media.kind == .video { player = AVPlayer(url: MediaStore.url(for: media.fileName)) }
        }
        .onDisappear { player?.pause() }
    }
}
