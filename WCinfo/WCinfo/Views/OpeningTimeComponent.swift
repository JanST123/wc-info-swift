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
                    Text(timeUntil(closeTimestamp, action: .closes))
                        .font(.caption)
                        .foregroundColor(urgencyColor(for: closeTimestamp))
                } else if !(isOpen ?? false), let openTimestamp {
                    Text(timeUntil(openTimestamp, action: .opens))
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
            parts.append(String(localized: "Jetzt geöffnet"))
            parts.append(String(localized: "24 Stunden geöffnet"))
            return parts.joined(separator: ", ")
        }
        if let isOpen {
            parts.append(isOpen ? String(localized: "Jetzt geöffnet") : String(localized: "Geschlossen"))
            if isOpen, let closeTimestamp {
                parts.append(timeUntil(closeTimestamp, action: .closes))
            } else if !isOpen, let openTimestamp {
                parts.append(timeUntil(openTimestamp, action: .opens))
            }
            if !isOpen && accessibleOutsideOpeningTimes {
                parts.append(String(localized: "Auch außerhalb der Öffnungszeiten zugänglich"))
            }
        } else {
            parts.append(String(localized: "Keine Öffnungszeiten"))
            if accessibleOutsideOpeningTimes {
                parts.append(String(localized: "Auch außerhalb der Öffnungszeiten zugänglich"))
            }
        }
        return parts.joined(separator: ", ")
    }

    private enum TimeUntilAction {
        case closes
        case opens
    }

    private func timeUntil(_ date: Date, action: TimeUntilAction) -> String {
        let seconds = date.timeIntervalSinceNow
        let minutes = max(0, Int(seconds / 60))
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        switch action {
        case .closes:
            if seconds <= 0 {
                return String(localized: "schließt bald")
            } else if hours > 0 && remainingMinutes > 0 {
                let template = String(localized: "schließt in %lld Std. %lld Min.")
                return String(format: template, hours, remainingMinutes)
            } else if hours > 0 {
                let template = String(localized: "schließt in %lld Std.")
                return String(format: template, hours)
            } else {
                let template = String(localized: "schließt in %lld Min.")
                return String(format: template, minutes)
            }
        case .opens:
            if seconds <= 0 {
                return String(localized: "öffnet bald")
            } else if hours > 0 && remainingMinutes > 0 {
                let template = String(localized: "öffnet in %lld Std. %lld Min.")
                return String(format: template, hours, remainingMinutes)
            } else if hours > 0 {
                let template = String(localized: "öffnet in %lld Std.")
                return String(format: template, hours)
            } else {
                let template = String(localized: "öffnet in %lld Min.")
                return String(format: template, minutes)
            }
        }
    }

    private func urgencyColor(for closeTimestamp: Date) -> Color {
        let minutes = closeTimestamp.timeIntervalSinceNow / 60
        return minutes < 30 ? .red : .secondary
    }
}
