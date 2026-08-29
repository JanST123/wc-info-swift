import SwiftUI
import PhotosUI
import ImageIO

struct PhotoUpload: View {
    var toiletId: Int? = nil
    var fixedGeo: String? = nil
    var onPhotoUploaded: ((UploadPhotoResponse) -> Void)? = nil
    var onPhotosChanged: (([UploadedPhotoItem]) -> Void)? = nil

    @State private var selectedPickerItems: [PhotosPickerItem] = []
    @State private var photoItems: [UploadedPhotoItem] = []
    @State private var uploadTasks: [UUID: Task<Void, Never>] = [:]

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 140), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 16) {
            // Photos Picker Button
            PhotosPicker(
                selection: $selectedPickerItems,
                maxSelectionCount: 10,
                matching: .images,
                photoLibrary: .shared()
            ) {
                HStack(spacing: 10) {
                    Image(systemName: "photo.badge.plus")
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fotos auswählen")
                            .font(.headline)
                        Text("Tippe hier, um Fotos hinzuzufügen")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }
                .padding(14)
                .background(Color.purple.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
            .onChange(of: selectedPickerItems) { _, newItems in
                Task {
                    await handlePickedPhotos(newItems)
                }
            }

            // Photo Grid
            if !photoItems.isEmpty {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(photoItems) { item in
                        photoCard(for: item)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onDisappear {
            for task in uploadTasks.values {
                task.cancel()
            }
            uploadTasks.removeAll()
        }
    }

    private func photoCard(for item: UploadedPhotoItem) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: item.image)
                .resizable()
                .scaledToFill()
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            // Bottom Status Overlay
            VStack {
                Spacer()
                HStack {
                    switch item.status {
                    case .pending, .uploading:
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.7)
                        Text("Upload...")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    case .success:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 13))
                        Text("Fertig")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    case .failed:
                        Button {
                            startUpload(for: item)
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Wdh.")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.65))
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Remove Button
            Button {
                removePhotoItem(item)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
                    .padding(4)
            }
            .buttonStyle(.plain)
        }
        .frame(width: 100, height: 100)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
    }

    private func removePhotoItem(_ item: UploadedPhotoItem) {
        // 1. Cancel in-flight upload task if still running
        if let runningTask = uploadTasks[item.id] {
            runningTask.cancel()
            uploadTasks.removeValue(forKey: item.id)
        }

        // 2. If already uploaded successfully, call DELETE /deletePhoto API
        if case .success(_, let tId, let fn) = item.status {
            Task {
                do {
                    _ = try await WCInfoAPIService.shared.deletePhoto(toiletId: tId, filename: fn, soft: 0)
                    Analytics.shared.trackEvent(category: "photo", action: "delete_success", name: fn)
                } catch {
                    ErrorManager.shared.report(error, context: ["action": "deletePhoto", "toiletId": tId, "filename": fn, "soft": 0])
                }
            }
        }

        withAnimation {
            photoItems.removeAll { $0.id == item.id }
        }
        onPhotosChanged?(photoItems)
    }

    private func handlePickedPhotos(_ items: [PhotosPickerItem]) async {
        for pickerItem in items {
            guard let data = try? await pickerItem.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else {
                continue
            }

            // Convert to JPEG representation for upload
            let uploadData = uiImage.jpegData(compressionQuality: 0.85) ?? data
            let exifJSON = ExifExtractor.extractExifJSON(from: data)

            let photoItem = UploadedPhotoItem(
                image: uiImage,
                rawData: uploadData,
                exifJSON: exifJSON,
                status: .uploading
            )

            photoItems.append(photoItem)
            onPhotosChanged?(photoItems)

            startUpload(for: photoItem)
        }

        // Reset picker selection to allow picking more photos later
        selectedPickerItems.removeAll()
    }

    private func startUpload(for item: UploadedPhotoItem) {
        guard let index = photoItems.firstIndex(where: { $0.id == item.id }) else { return }
        photoItems[index].status = .uploading

        // Cancel previous task for this item if any
        uploadTasks[item.id]?.cancel()

        let task = Task {
            do {
                let response = try await WCInfoAPIService.shared.uploadPhoto(
                    imageData: item.rawData,
                    toiletId: toiletId,
                    exif: item.exifJSON,
                    fixedGeo: fixedGeo
                )

                // If cancelled while network request was running, delete the newly created remote photo
                if Task.isCancelled {
                    _ = try? await WCInfoAPIService.shared.deletePhoto(
                        toiletId: response.toiletId,
                        filename: response.filename,
                        soft: 0
                    )
                    return
                }

                if let idx = photoItems.firstIndex(where: { $0.id == item.id }) {
                    photoItems[idx].status = .success(
                        imageUrl: response.imageUrl,
                        toiletId: response.toiletId,
                        filename: response.filename
                    )
                    onPhotosChanged?(photoItems)
                    onPhotoUploaded?(response)
                    Analytics.shared.trackEvent(category: "photo", action: "upload_success", name: String(response.toiletId))
                }
            } catch {
                guard !Task.isCancelled else { return }
                if let idx = photoItems.firstIndex(where: { $0.id == item.id }) {
                    photoItems[idx].status = .failed(error: error.localizedDescription)
                    onPhotosChanged?(photoItems)
                    ErrorManager.shared.report(error, context: ["action": "uploadPhoto", "toiletId": toiletId ?? 0])
                    Analytics.shared.trackEvent(category: "photo", action: "upload_failed")
                }
            }
            uploadTasks.removeValue(forKey: item.id)
        }

        uploadTasks[item.id] = task
    }
}

public struct UploadedPhotoItem: Identifiable {
    public let id = UUID()
    public let image: UIImage
    public let rawData: Data
    public let exifJSON: String?
    public var status: UploadStatus
}

public enum UploadStatus: Equatable {
    case pending
    case uploading
    case success(imageUrl: String, toiletId: Int, filename: String)
    case failed(error: String)
}

public enum ExifExtractor {
    public static func extractExifJSON(from imageData: Data) -> String? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return nil
        }

        var sanitized: [String: Any] = [:]
        for (key, val) in metadata {
            if let str = val as? String {
                sanitized[key] = str
            } else if let num = val as? NSNumber {
                sanitized[key] = num
            } else if let dict = val as? [String: Any] {
                var subDict: [String: Any] = [:]
                for (subKey, subVal) in dict {
                    if let sStr = subVal as? String {
                        subDict[subKey] = sStr
                    } else if let sNum = subVal as? NSNumber {
                        subDict[subKey] = sNum
                    } else if let sArr = subVal as? [Any] {
                        subDict[subKey] = sArr.compactMap { item -> Any? in
                            if let iStr = item as? String { return iStr }
                            if let iNum = item as? NSNumber { return iNum }
                            return nil
                        }
                    }
                }
                sanitized[key] = subDict
            }
        }

        guard !sanitized.isEmpty,
              let jsonData = try? JSONSerialization.data(withJSONObject: sanitized, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }
        return jsonString
    }
}
