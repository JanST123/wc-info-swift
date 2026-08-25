import SwiftUI

struct ResizableSplit<Primary: View, Secondary: View>: View {
    let axis: Axis
    @Binding var ratio: CGFloat
    @Binding var isDragging: Bool
    @ViewBuilder let primary: () -> Primary
    @ViewBuilder let secondary: () -> Secondary

    @State private var previewRatio: CGFloat?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let minRatio: CGFloat = 0.2
    private let maxRatio: CGFloat = 0.8
    private let handleThickness: CGFloat = 28
    private let step: CGFloat = 0.05

    private var activeRatio: CGFloat {
        previewRatio ?? ratio
    }

    var body: some View {
        GeometryReader { geometry in
            let totalSize = axis == .horizontal ? geometry.size.width : geometry.size.height
            let primarySize = totalSize * activeRatio
            let secondarySize = totalSize - primarySize - handleThickness

            Group {
                if axis == .horizontal {
                    HStack(spacing: 0) {
                        primary()
                            .frame(width: primarySize)
                        handle(in: geometry)
                            .frame(width: handleThickness)
                        secondary()
                            .frame(width: max(0, secondarySize))
                    }
                } else {
                    VStack(spacing: 0) {
                        primary()
                            .frame(height: primarySize)
                        handle(in: geometry)
                            .frame(height: handleThickness)
                        secondary()
                            .frame(height: max(0, secondarySize))
                    }
                }
            }
        }
    }

    private func handle(in geometry: GeometryProxy) -> some View {
        let totalSize = axis == .horizontal ? geometry.size.width : geometry.size.height
        return Rectangle()
            .fill(Color(.systemGray5))
            .overlay {
                if axis == .horizontal {
                    HStack(spacing: 3) {
                        Capsule()
                            .fill(Color(.systemGray3))
                            .frame(width: 4, height: 28)
                        Capsule()
                            .fill(Color(.systemGray3))
                            .frame(width: 4, height: 28)
                    }
                } else {
                    VStack(spacing: 3) {
                        Capsule()
                            .fill(Color(.systemGray3))
                            .frame(width: 28, height: 4)
                        Capsule()
                            .fill(Color(.systemGray3))
                            .frame(width: 28, height: 4)
                    }
                }
            }
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(axis == .horizontal ? "Teiler horizontal" : "Teiler vertikal")
            .accessibilityValue(String(format: "Listengröße %.0f Prozent", activeRatio * 100))
            .accessibilityHint("Passe die Größe der Liste und der Karte an.")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    updateRatio(ratio + step)
                case .decrement:
                    updateRatio(ratio - step)
                @unknown default:
                    break
                }
            }
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if previewRatio == nil {
                            previewRatio = ratio
                            isDragging = true
                        }
                        let delta = axis == .horizontal ? value.translation.width : value.translation.height
                        let newRatio = (previewRatio ?? ratio) + (delta / totalSize)
                        previewRatio = min(maxRatio, max(minRatio, newRatio))
                    }
                    .onEnded { _ in
                        if let final = previewRatio {
                            updateRatio(final)
                        }
                        previewRatio = nil
                        isDragging = false
                    }
            )
    }

    private func updateRatio(_ newRatio: CGFloat) {
        let clamped = min(maxRatio, max(minRatio, newRatio))
        if reduceMotion {
            ratio = clamped
        } else {
            withAnimation(.easeOut(duration: 0.15)) {
                ratio = clamped
            }
        }
    }
}
