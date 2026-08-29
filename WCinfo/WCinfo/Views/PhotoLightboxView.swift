import SwiftUI

struct PhotoLightboxView: View {
    @Environment(\.dismiss) private var dismiss
    let toiletId: Int
    @State var photos: [ToiletPhoto]
    @State var selectedIndex: Int
    var onPhotoDeleted: (() -> Void)? = nil

    @State private var isShowingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if photos.isEmpty {
                VStack(spacing: 12) {
                    Text("Keine Fotos vorhanden")
                        .foregroundColor(.white)
                    Button("Schließen") {
                        dismiss()
                    }
                    .foregroundColor(.purple)
                }
            } else {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                        GeometryReader { geometry in
                            ZStack {
                                AsyncImage(url: URL(string: photo.url)) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(1.2)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: geometry.size.width, height: geometry.size.height)
                                    case .failure:
                                        VStack(spacing: 8) {
                                            Image(systemName: "photo.badge.exclamationmark")
                                                .font(.largeTitle)
                                                .foregroundColor(.white.opacity(0.7))
                                            Text("Foto konnte nicht geladen werden")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .always : .never))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                // Header & Footer Overlays
                VStack {
                    HStack {
                        if photos.count > 1 {
                            Text("\(selectedIndex + 1) / \(photos.count)")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Capsule())
                        }

                        Spacer()

                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Schließen")
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    Spacer()

                    // Bottom "Remove this photo" Button
                    Button(role: .destructive) {
                        isShowingDeleteConfirmation = true
                    } label: {
                        HStack(spacing: 6) {
                            if isDeleting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "nosign")
                                    .font(.subheadline.bold())
                            }
                            Text("Remove this photo")
                                .font(.subheadline.bold())
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isDeleting)
                    .accessibilityLabel("Remove this photo")
                    .padding(.bottom, photos.count > 1 ? 44 : 24)
                }
            }
        }
        .alert("Foto löschen?", isPresented: $isShowingDeleteConfirmation) {
            Button("Löschen", role: .destructive) {
                deleteCurrentPhoto()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Ist dies ein unpassendes Foto oder hast du persönliche Gründe dieses Foto zu löschen? Wählst du 'Löschen' wird das Foto sofort gelöscht und das Foto im Nachgang durch uns geprüft. Wir behalten uns vor das Foto nachträglich wiederherzustellen sollte es doch passend sein und unserer Meinung kein Persönlichkeitsrecht verletzen")
        }
    }

    private func deleteCurrentPhoto() {
        guard photos.indices.contains(selectedIndex) else { return }
        let photoToDelete = photos[selectedIndex]
        let filename = photoToDelete.resolvedFilename
        guard !filename.isEmpty else { return }

        isDeleting = true

        Task {
            do {
                _ = try await WCInfoAPIService.shared.deletePhoto(toiletId: toiletId, filename: filename)
                isDeleting = false
                Analytics.shared.trackEvent(category: "photo", action: "delete_lightbox_success", name: filename)

                withAnimation {
                    photos.remove(at: selectedIndex)
                    if selectedIndex >= photos.count {
                        selectedIndex = max(0, photos.count - 1)
                    }
                }
                onPhotoDeleted?()
                if photos.isEmpty {
                    dismiss()
                }
            } catch {
                isDeleting = false
                deleteError = error.localizedDescription
                ErrorManager.shared.report(error, context: ["action": "deletePhotoLightbox", "toiletId": toiletId, "filename": filename])
            }
        }
    }
}
