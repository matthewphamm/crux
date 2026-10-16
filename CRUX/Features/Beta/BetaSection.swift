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
                TextField("Notes: sequence, foot beta, what to try next…", text: $climb.notes, axis: .vertical)
                    .font(.system(size: 15))
                    .lineSpacing(15 * 0.45)
                    .lineLimit(3...12)
                    .focused($notesFocused)
                    .onChange(of: notesFocused) { _, focused in
                        if !focused { try? context.save() }
                    }

                if !media.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
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
                    if CameraPicker.isAvailable {
                        Button {
                            showingCamera = true
                        } label: {
                            Label("Camera", systemImage: "camera")
                        }
                        .buttonStyle(ControlButtonStyle(height: 44, ink: Theme.accent))
                    }

                    PhotosPicker(selection: $pickerItems, maxSelectionCount: 6, matching: .any(of: [.images, .videos])) {
                        Label(importing ? "Importing…" : "Library", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(ControlButtonStyle(height: 44, ink: Theme.accent))
                    .disabled(importing)
                }
            }
            .glassCard(padding: 16, radius: 24)
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
        .fullScreenCover(item: $viewing) { item in
            MediaViewer(media: item) {
                withAnimation(Theme.spring) { BetaImporter.delete(item, context: context) }
            }
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
            .overlay {
                if media.kind == .video {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.black.opacity(0.55), in: .circle)
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

/// Full-screen black viewer: close, date, and a red delete.
struct MediaViewer: View {
    let media: BetaMedia
    var onDelete: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var confirmingDelete = false

    var body: some View {
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
        .overlay(alignment: .top) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .controlBackground(Circle())
                }
                .accessibilityLabel("Close")
                Spacer()
                Text(media.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                if onDelete != nil {
                    Button { confirmingDelete = true } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.danger)
                            .frame(width: 40, height: 40)
                            .controlBackground(Circle())
                    }
                    .accessibilityLabel("Delete")
                } else {
                    Color.clear.frame(width: 40, height: 40)
                }
            }
            .padding(.horizontal, Theme.Spacing.gutter)
            .padding(.top, 8)
        }
        .alert(media.kind == .video ? "Delete this video?" : "Delete this photo?", isPresented: $confirmingDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete?()
                dismiss()
            }
        }
        .onAppear {
            if media.kind == .video { player = AVPlayer(url: MediaStore.url(for: media.fileName)) }
        }
        .onDisappear { player?.pause() }
    }
}
