import SwiftUI
import CoreLocation

struct AddToiletByPhotoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let coordinate: CLLocationCoordinate2D
    var onToiletCreated: (() -> Void)? = nil

    @State private var uploadedPhotoCount = 0
    @State private var isUploading = false

    private var fixedGeoJSON: String {
        "{\"lat\": \(coordinate.latitude), \"lon\": \(coordinate.longitude)}"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Card
                    VStack(spacing: 12) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 48))
                            .foregroundColor(.purple)
                            .padding(.top, 8)

                        Text("Toilette per Foto anlegen")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)

                        Text("Lade einfach ein oder mehrere Fotos der Toilette hoch – wir erledigen den Rest für dich!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                    .padding(.bottom, 4)

                    // Photo Tips Guide
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Hilfreiche Fotos:")
                            .font(.headline)
                            .foregroundColor(.primary)

                        tipRow(
                            icon: "door.left.hand.open",
                            title: "Eingang & Türen",
                            description: "Kennzeichnungen für Geschlechtertrennung, Euro-Schlüssel oder barrierefreien Zugang."
                        )

                        tipRow(
                            icon: "building.2.fill",
                            title: "Zugehöriger Ort",
                            description: "Zeige, zu welchem Gebäude, Restaurant oder Geschäft die Toilette gehört."
                        )

                        tipRow(
                            icon: "info.circle.fill",
                            title: "Schilder & Hinweise",
                            description: "Öffnungszeiten, Kosten/Gebühren oder allgemeine Hinweise."
                        )
                    }
                    .padding(16)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // Photo Upload Component
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Fotos hochladen")
                            .font(.headline)

                        PhotoUpload(
                            fixedGeo: fixedGeoJSON,
                            onPhotosChanged: { items in
                                let successItems = items.filter { item in
                                    if case .success = item.status { return true }
                                    return false
                                }
                                uploadedPhotoCount = successItems.count
                                isUploading = items.contains { $0.status == .uploading }
                            }
                        )
                    }

                    if uploadedPhotoCount > 0 {
                        Button {
                            onToiletCreated?()
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Fertigstellen (\(uploadedPhotoCount) \(uploadedPhotoCount == 1 ? "Foto" : "Fotos"))")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: Color.purple.opacity(0.3), radius: 6, x: 0, y: 3)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Per Foto anlegen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") {
                        if uploadedPhotoCount > 0 {
                            onToiletCreated?()
                        }
                        dismiss()
                    }
                }
            }
        }
    }

    private func tipRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.purple)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
