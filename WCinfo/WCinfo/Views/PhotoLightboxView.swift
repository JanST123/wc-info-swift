import SwiftUI

struct PhotoLightboxView: View {
    @Environment(\.dismiss) private var dismiss
    let photos: [ToiletPhoto]
    @State var selectedIndex: Int

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

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

            // Header Overlay with Photo Counter & Close Button
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
            }
        }
    }
}
