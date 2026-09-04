import SwiftUI

struct ToiletFilterSettings: Equatable, Codable {
    var showClosed: Bool = false
    var showNonPublic: Bool = true
    var showNonWheelchairAccessible: Bool = true
    var showWithoutChangingTable: Bool = true
    var showWithoutGenderSeparation: Bool = true
    var showWithoutEuroKey: Bool = true

    static let `default` = ToiletFilterSettings()
    private static let userDefaultsKey = "wcinfo.filter_settings"

    var isDefault: Bool {
        self == .default
    }

    mutating func resetToDefaults() {
        self = .default
    }

    static func load() -> ToiletFilterSettings {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let settings = try? JSONDecoder().decode(ToiletFilterSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
        }
    }

    var apiFilterQueryString: String? {
        var pairs: [String] = []

        if !showClosed {
            pairs.append("is_open:true")
        }
        if !showNonPublic {
            pairs.append("public_accessible:true")
        }
        if !showNonWheelchairAccessible {
            pairs.append("has_wheelchair_access:true")
        }
        if !showWithoutChangingTable {
            pairs.append("has_changing_table:true")
        }
        if !showWithoutGenderSeparation {
            pairs.append("is_gender_separated:true")
        }
        if !showWithoutEuroKey {
            pairs.append("euro_key:yes")
        }

        return pairs.isEmpty ? nil : pairs.joined(separator: ",")
    }

    var summaryText: AttributedString {
        var activeRestrictions: [String] = []

        if !showClosed {
            activeRestrictions.append("jetzt geöffnete")
        }
        if !showNonPublic {
            activeRestrictions.append("öffentliche")
        }
        if !showNonWheelchairAccessible {
            activeRestrictions.append("barrierefreie")
        }
        if !showWithoutChangingTable {
            activeRestrictions.append("mit Wickelraum")
        }
        if !showWithoutGenderSeparation {
            activeRestrictions.append("getrennte")
        }
        if !showWithoutEuroKey {
            activeRestrictions.append("mit Euroschlüssel")
        }

        if activeRestrictions.isEmpty {
            var string = AttributedString("Zeige ")
            var all = AttributedString("alle")
            all.inlinePresentationIntent = .stronglyEmphasized
            string.append(all)
            string.append(AttributedString(" Toiletten an."))
            return string
        } else {
            var string = AttributedString("Zeige nur ")
            var boldPart = AttributedString(activeRestrictions.joined(separator: ", "))
            boldPart.inlinePresentationIntent = .stronglyEmphasized
            string.append(boldPart)
            string.append(AttributedString(" Toiletten an."))
            return string
        }
    }
}

struct FilterBannerView: View {
    @Binding var filterSettings: ToiletFilterSettings
    var onFilterChanged: () -> Void

    @State private var isExpanded = false
    @State private var showingNonPublicInfo = false
    @State private var showingEuroKeyInfo = false

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 12) {
                Text(filterSettings.summaryText)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(isExpanded ? .white : .purple)
                        .padding(8)
                        .background(isExpanded ? Color.purple : Color.purple.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "Filter einklappen" : "Filter ausklappen")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            // Expanded Filter Panel
            if isExpanded {
                Divider()
                    .padding(.horizontal, 14)

                VStack(spacing: 12) {
                    toggleRow(
                        title: "Geschlossene Toiletten anzeigen",
                        isOn: $filterSettings.showClosed
                    )

                    toggleRow(
                        title: "Nicht öffentliche Toiletten anzeigen",
                        isOn: $filterSettings.showNonPublic,
                        infoAction: { showingNonPublicInfo = true }
                    )

                    toggleRow(
                        title: "Nicht-barrierefreie Toiletten anzeigen",
                        isOn: $filterSettings.showNonWheelchairAccessible
                    )

                    toggleRow(
                        title: "Toiletten ohne Wickelraum anzeigen",
                        isOn: $filterSettings.showWithoutChangingTable
                    )

                    toggleRow(
                        title: "Toiletten ohne Geschlechtertrennung anzeigen",
                        isOn: $filterSettings.showWithoutGenderSeparation
                    )

                    toggleRow(
                        title: "Toiletten ohne Euroschlüssel anzeigen",
                        isOn: $filterSettings.showWithoutEuroKey,
                        infoAction: { showingEuroKeyInfo = true }
                    )

                    // Reset Button
                    HStack {
                        Spacer()
                        Button {
                            withAnimation {
                                filterSettings.resetToDefaults()
                            }
                            filterSettings.save()
                            onFilterChanged()
                        } label: {
                            Text("Standard Filter anwenden")
                                .font(.footnote.bold())
                                .foregroundColor(.purple)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 2)
        .alert("Nicht-öffentliche Toiletten", isPresented: $showingNonPublicInfo) {
            Button("Verstanden", role: .cancel) { }
        } message: {
            Text("Nicht-öffentliche Toiletten befinden sich beispielsweise in Restaurants, Geschäften oder privaten Einrichtungen und sind oft Kunden oder Gästen vorbehalten.")
        }
        .sheet(isPresented: $showingEuroKeyInfo) {
            EuroKeyInfoView()
        }
    }

    private func toggleRow(title: String, isOn: Binding<Bool>, infoAction: (() -> Void)? = nil) -> some View {
        HStack(spacing: 8) {
            Toggle(isOn: Binding(
                get: { isOn.wrappedValue },
                set: { newValue in
                    isOn.wrappedValue = newValue
                    filterSettings.save()
                    onFilterChanged()
                }
            )) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)

                    if let infoAction {
                        Button(action: infoAction) {
                            Image(systemName: "info.circle.fill")
                                .font(.caption)
                                .foregroundColor(.purple)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Informationen zu \(title)")
                    }
                }
            }
            .tint(.purple)
        }
    }
}
