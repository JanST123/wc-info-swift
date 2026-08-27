import SwiftUI

struct PhotoUpload: View {
    var onPhotosChanged: (([UIImage]) -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.badge.ellipsis")
                .font(.system(size: 40))
                .foregroundColor(.purple)

            Text("Foto-Upload")
                .font(.headline)

            Text("Fotos von der Toilette oder den Öffnungszeiten können hier hochgeladen werden.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
