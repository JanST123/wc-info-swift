import SwiftUI

struct ResizableSplit<Primary: View, Secondary: View>: View {
    let axis: Axis
    @Binding var ratio: CGFloat
    @Binding var isDragging: Bool
    @ViewBuilder let primary: () -> Primary
    @ViewBuilder let secondary: () -> Secondary

    @State private var dragStartRatio: CGFloat?

    private let minRatio: CGFloat = 0.2
    private let maxRatio: CGFloat = 0.8
    private let handleThickness: CGFloat = 28

    var body: some View {
        GeometryReader { geometry in
            let totalSize = axis == .horizontal ? geometry.size.width : geometry.size.height
            let primarySize = totalSize * ratio
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
                VStack(spacing: 3) {
                    Capsule()
                        .fill(Color(.systemGray3))
                        .frame(width: 28, height: 4)
                    Capsule()
                        .fill(Color(.systemGray3))
                        .frame(width: 28, height: 4)
                }
            }
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if dragStartRatio == nil {
                            dragStartRatio = ratio
                            isDragging = true
                        }
                        let delta = axis == .horizontal ? value.translation.width : value.translation.height
                        let newRatio = (dragStartRatio ?? ratio) + (delta / totalSize)
                        ratio = min(maxRatio, max(minRatio, newRatio))
                    }
                    .onEnded { _ in
                        dragStartRatio = nil
                        isDragging = false
                    }
            )
    }
}
