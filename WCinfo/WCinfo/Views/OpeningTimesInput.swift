import SwiftUI

struct OpeningTimesInput: View {
    @Binding var periods: [GooglePlacesPeriod]?

    @State private var drafts: [TimeRangeDraft] = [
        TimeRangeDraft(
            selectedDays: [1, 2, 3, 4, 5],
            openTime: TimeRangeDraft.makeTime(hour: 8, minute: 0),
            closeTime: TimeRangeDraft.makeTime(hour: 18, minute: 0)
        )
    ]

    var body: some View {
        VStack(spacing: 16) {
            ForEach(Array(drafts.enumerated()), id: \.element.id) { index, draft in
                TimeRangeCardView(
                    draft: draft,
                    index: index,
                    canDelete: drafts.count > 1,
                    onUpdate: { updated in
                        if let idx = drafts.firstIndex(where: { $0.id == updated.id }) {
                            drafts[idx] = updated
                            syncOutput()
                        }
                    },
                    onDelete: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            drafts.removeAll { $0.id == draft.id }
                        }
                        syncOutput()
                    }
                )
            }

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    drafts.append(
                        TimeRangeDraft(
                            selectedDays: [],
                            openTime: TimeRangeDraft.makeTime(hour: 8, minute: 0),
                            closeTime: TimeRangeDraft.makeTime(hour: 18, minute: 0)
                        )
                    )
                }
                syncOutput()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Weiteren Zeitraum hinzufügen")
                }
                .font(.subheadline.bold())
                .foregroundColor(.purple)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color.purple.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            syncOutput()
        }
    }

    private func syncOutput() {
        var computedPeriods: [GooglePlacesPeriod] = []

        for draft in drafts {
            guard !draft.selectedDays.isEmpty else { continue }

            let openComponents = Calendar.current.dateComponents([.hour, .minute], from: draft.openTime)
            let closeComponents = Calendar.current.dateComponents([.hour, .minute], from: draft.closeTime)

            let openHour = openComponents.hour ?? 8
            let openMinute = openComponents.minute ?? 0
            let closeHour = closeComponents.hour ?? 18
            let closeMinute = closeComponents.minute ?? 0

            for day in draft.selectedDays.sorted() {
                if draft.is24Hours {
                    let openPoint = GooglePlacesPoint(day: day, hour: 0, minute: 0)
                    computedPeriods.append(GooglePlacesPeriod(open: openPoint, close: nil))
                } else {
                    let openPoint = GooglePlacesPoint(day: day, hour: openHour, minute: openMinute)
                    let closePoint = GooglePlacesPoint(day: day, hour: closeHour, minute: closeMinute)
                    computedPeriods.append(GooglePlacesPeriod(open: openPoint, close: closePoint))
                }
            }
        }

        periods = computedPeriods.isEmpty ? nil : computedPeriods
    }
}

private struct TimeRangeCardView: View {
    let draft: TimeRangeDraft
    let index: Int
    let canDelete: Bool
    let onUpdate: (TimeRangeDraft) -> Void
    let onDelete: () -> Void

    @State private var localDraft: TimeRangeDraft

    private let weekdays: [(day: Int, name: String)] = [
        (1, "Mo"),
        (2, "Di"),
        (3, "Mi"),
        (4, "Do"),
        (5, "Fr"),
        (6, "Sa"),
        (0, "So")
    ]

    init(
        draft: TimeRangeDraft,
        index: Int,
        canDelete: Bool,
        onUpdate: @escaping (TimeRangeDraft) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.draft = draft
        self.index = index
        self.canDelete = canDelete
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self._localDraft = State(initialValue: draft)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Zeitraum \(index + 1)")
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)

                Spacer()

                if canDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(6)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Zeitraum \(index + 1) entfernen")
                }
            }

            // Quick select presets
            HStack(spacing: 8) {
                presetButton(title: "Mo–Fr", days: [1, 2, 3, 4, 5])
                presetButton(title: "Sa–So", days: [6, 0])
                presetButton(title: "Täglich", days: [0, 1, 2, 3, 4, 5, 6])
            }

            // Weekday Chips
            HStack(spacing: 6) {
                ForEach(weekdays, id: \.day) { item in
                    let isSelected = localDraft.selectedDays.contains(item.day)
                    Button {
                        if isSelected {
                            localDraft.selectedDays.remove(item.day)
                        } else {
                            localDraft.selectedDays.insert(item.day)
                        }
                        onUpdate(localDraft)
                    } label: {
                        Text(item.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(isSelected ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(isSelected ? Color.purple : Color(.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            // 24 Hours Toggle
            Toggle(isOn: $localDraft.is24Hours) {
                Text("24 Stunden geöffnet")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .tint(.purple)
            .onChange(of: localDraft.is24Hours) { _, _ in
                onUpdate(localDraft)
            }

            // Time Pickers (if not 24h)
            if !localDraft.is24Hours {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Öffnet um")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        DatePicker(
                            "",
                            selection: $localDraft.openTime,
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .onChange(of: localDraft.openTime) { _, _ in
                            onUpdate(localDraft)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Schließt um")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        DatePicker(
                            "",
                            selection: $localDraft.closeTime,
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .onChange(of: localDraft.closeTime) { _, _ in
                            onUpdate(localDraft)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 0.8)
        )
    }

    private func presetButton(title: String, days: Set<Int>) -> some View {
        let isMatching = localDraft.selectedDays == days
        return Button {
            localDraft.selectedDays = days
            onUpdate(localDraft)
        } label: {
            Text(title)
                .font(.caption2.bold())
                .foregroundColor(isMatching ? .white : .purple)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isMatching ? Color.purple : Color.purple.opacity(0.12))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct TimeRangeDraft: Identifiable {
    let id = UUID()
    var selectedDays: Set<Int>
    var openTime: Date
    var closeTime: Date
    var is24Hours: Bool = false

    static func makeTime(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }
}
