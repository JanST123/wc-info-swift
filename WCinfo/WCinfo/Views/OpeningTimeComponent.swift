import SwiftUI

struct OpeningTimeComponent: View {
    let hasOpeningHours: Bool?
    let isOpen: Bool?
    let openTimestamp: Date?
    let closeTimestamp: Date?
    var accessibleOutsideOpeningTimes: Bool = false
    var isOpen24Hours: Bool = false
    var alignment: HorizontalAlignment = .trailing

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            if isOpen24Hours {
                Text("Jetzt geöffnet")
                    .font(.subheadline.bold())
                    .foregroundColor(.green)

                Text("24 Stunden geöffnet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if hasOpeningHours ?? false {
                Text(isOpen ?? false ? "Jetzt geöffnet" : "Geschlossen")
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

                if !(isOpen ?? false) && accessibleOutsideOpeningTimes {
                    Text("Auch außerhalb der Öffnungszeiten zugänglich")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("Keine Öffnungszeiten")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if accessibleOutsideOpeningTimes {
                    Text("Auch außerhalb der Öffnungszeiten zugänglich")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts = [String]()
        if isOpen24Hours {
            parts.append("Jetzt geöffnet")
            parts.append("24 Stunden geöffnet")
            return parts.joined(separator: ", ")
        }
        if let isOpen {
            parts.append(isOpen ? "Jetzt geöffnet" : "Geschlossen")
            if isOpen, let closeTimestamp {
                parts.append("schließt \(timeUntil(closeTimestamp, prefix: ""))")
            } else if !isOpen, let openTimestamp {
                parts.append("öffnet \(timeUntil(openTimestamp, prefix: ""))")
            }
            if !isOpen && accessibleOutsideOpeningTimes {
                parts.append("Auch außerhalb der Öffnungszeiten zugänglich")
            }
        } else {
            parts.append("Keine Öffnungszeiten verfügbar")
            if accessibleOutsideOpeningTimes {
                parts.append("Auch außerhalb der Öffnungszeiten zugänglich")
            }
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
