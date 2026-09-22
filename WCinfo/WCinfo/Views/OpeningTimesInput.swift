import SwiftUI

struct OpeningTimesInput: View {
    @Binding var periods: [GooglePlacesPeriod]?

    @State private var drafts: [TimeRangeDraft]

    init(periods: Binding<[GooglePlacesPeriod]?>) {
        self._periods = periods
        let initialDrafts = Self.parsePeriodsToDrafts(periods.wrappedValue)
        self._drafts = State(initialValue: initialDrafts)
    }

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

    private static func parsePeriodsToDrafts(_ periods: [GooglePlacesPeriod]?) -> [TimeRangeDraft] {
        guard let periods = periods, !periods.isEmpty else {
            return [
                TimeRangeDraft(
                    selectedDays: [1, 2, 3, 4, 5],
                    openTime: TimeRangeDraft.makeTime(hour: 8, minute: 0),
                    closeTime: TimeRangeDraft.makeTime(hour: 18, minute: 0)
                )
            ]
        }

        struct DraftKey: Hashable {
            let is24Hours: Bool
            let openHour: Int
            let openMinute: Int
            let closeHour: Int
            let closeMinute: Int
        }

        var grouped: [DraftKey: Set<Int>] = [:]
        var keyOrder: [DraftKey] = []

        for period in periods {
            let is24 = period.is24Hours
            let openHour = period.open.hour
            let openMinute = period.open.minute
            let closeHour = period.close?.hour ?? (is24 ? 0 : 18)
            let closeMinute = period.close?.minute ?? 0
            let key = DraftKey(
                is24Hours: is24,
                openHour: openHour,
                openMinute: openMinute,
                closeHour: closeHour,
                closeMinute: closeMinute
            )
            if grouped[key] == nil {
                keyOrder.append(key)
            }
            grouped[key, default: []].insert(period.open.day)
        }

        var result: [TimeRangeDraft] = []
        for key in keyOrder {
            if let days = grouped[key] {
                result.append(
                    TimeRangeDraft(
                        selectedDays: days,
                        openTime: TimeRangeDraft.makeTime(hour: key.openHour, minute: key.openMinute),
                        closeTime: TimeRangeDraft.makeTime(hour: key.closeHour, minute: key.closeMinute),
                        is24Hours: key.is24Hours
                    )
                )
            }
        }

        return result.isEmpty ? [
            TimeRangeDraft(
                selectedDays: [1, 2, 3, 4, 5],
                openTime: TimeRangeDraft.makeTime(hour: 8, minute: 0),
                closeTime: TimeRangeDraft.makeTime(hour: 18, minute: 0)
            )
        ] : result
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

    private var weekdays: [(day: Int, name: String)] {
        let symbols = Calendar.current.shortWeekdaySymbols
        return [
            (1, symbols.indices.contains(1) ? symbols[1] : "Mo"),
            (2, symbols.indices.contains(2) ? symbols[2] : "Di"),
            (3, symbols.indices.contains(3) ? symbols[3] : "Mi"),
            (4, symbols.indices.contains(4) ? symbols[4] : "Do"),
            (5, symbols.indices.contains(5) ? symbols[5] : "Fr"),
            (6, symbols.indices.contains(6) ? symbols[6] : "Sa"),
            (0, symbols.indices.contains(0) ? symbols[0] : "So")
        ]
    }

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
                    .accessibilityLabel(Text("Zeitraum \(index + 1) entfernen"))
                }
            }

            // Quick select presets
            HStack(spacing: 8) {
                presetButton(title: String(localized: "Mo–Fr"), days: [1, 2, 3, 4, 5])
                presetButton(title: String(localized: "Sa–So"), days: [6, 0])
                presetButton(title: String(localized: "Täglich"), days: [0, 1, 2, 3, 4, 5, 6])
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
