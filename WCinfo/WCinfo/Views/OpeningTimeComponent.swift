import SwiftUI

struct OpeningTimeComponent: View {
    let hasOpeningHours: Bool?
    let isOpen: Bool?
    let openTimestamp: Date?
    let closeTimestamp: Date?

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if hasOpeningHours ?? false {
                Text(isOpen ?? false ? "Geöffnet" : "Geschlossen")
                    .font(.subheadline.bold())
                    .foregroundColor(isOpen ?? false ? .green : .primary)

                if isOpen ?? false, let closeTimestamp {
                    Text(timeUntil(closeTimestamp, prefix: "schließt"))
                        .font(.caption)
                        .foregroundColor(urgencyColor(for: closeTimestamp))
                } else if !(isOpen ?? false), let openTimestamp {
                    Text(timeUntil(openTimestamp, prefix: "öffnet"))
                        .font(.caption)
                        .foregroundColor(.purple)
                }
            } else {
                Text("Keine Öffnungszeiten")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.trailing)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts = [String]()
        if let isOpen {
            parts.append(isOpen ? "Geöffnet" : "Geschlossen")
            if isOpen, let closeTimestamp {
                parts.append("schließt \(timeUntil(closeTimestamp, prefix: ""))")
            } else if !isOpen, let openTimestamp {
                parts.append("öffnet \(timeUntil(openTimestamp, prefix: ""))")
            }
        } else {
            parts.append("Keine Öffnungszeiten verfügbar")
        }
        return parts.joined(separator: ", ")
    }

    private func timeUntil(_ date: Date, prefix: String) -> String {
        let seconds = date.timeIntervalSinceNow
        guard seconds > 0 else { return prefix.isEmpty ? "bald" : "\(prefix) bald" }
        let minutes = Int(seconds / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        let timeString: String
        if hours > 0 {
            if remainingMinutes > 0 {
                timeString = "in \(hours) Std. \(remainingMinutes) Min."
            } else {
                timeString = "in \(hours) Std."
            }
        } else {
            timeString = "in \(minutes) Min."
        }
        return prefix.isEmpty ? timeString : "\(prefix) \(timeString)"
    }

    private func urgencyColor(for closeTimestamp: Date) -> Color {
        let minutes = closeTimestamp.timeIntervalSinceNow / 60
        return minutes < 30 ? .red : .secondary
    }
}
