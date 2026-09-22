import SwiftUI

struct PhotoUploadLegalNoticeSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onConfirm: () -> Void
    var onCancel: () -> Void

    private let privacyURL = URL(string: "https://wc-info.de/Law/Privacy")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header Icon & Title
                    VStack(spacing: 12) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 44))
                            .foregroundColor(.purple)
                            .padding(.top, 8)

                        Text("Bevor du dein erstes Foto hochlädst")
                            .font(.title3.bold())
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 4)

                    // Intro Text
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Bilder von Toiletten sollten nach Möglichkeit keine Personen beinhalten. Wenn du doch Bilder von anderen Menschen hochlädst, greifst du evtl. in deren Persönlichkeitsrecht ein. Bitte vergewissere dich daher, dass die Menschen, die auf den Fotos zu sehen sind, damit einverstanden sind, dass du die Bilder hier veröffentlichst.")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineSpacing(3)
                    }
                    .padding(14)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Rules Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Bitte halte dich zudem an geltendes Recht. Dies bedeutet u.A.:")
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)

                        ruleRow(text: "Keine illegalen, rassistischen, diskriminierenden oder gegen die Menschenwürde verstossenden Inhalte")
                        ruleRow(text: "Keine Darstellung von Alkohol- oder Drogenmissbrauch")
                        ruleRow(text: "Keine sexuellen, pornografischen oder jugendgefährdenden Inhalte")
                        ruleRow(text: "Keine Verstöße gegen Marken- oder Urheberrecht, keine Verletzung fremden geistigen Eigentums")
                        ruleRow(text: "Keine Schadsoftware / Viren")
                    }
                    .padding(14)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Privacy Note
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Der Zeitpunkt und deine IP werden im Zusammenhang mit den hochgeladenen Fotos bei uns gespeichert. Weitere Informationen findest du auch in unserer [Datenschutzerklärung](https://wc-info.de/Law/Privacy).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .tint(.purple)
                            .lineSpacing(2)
                    }
                    .padding(.horizontal, 4)

                    // Buttons
                    VStack(spacing: 12) {
                        Button {
                            onConfirm()
                            dismiss()
                        } label: {
                            Text("Zustimmen & Hochladen")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.purple)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: Color.purple.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                        .accessibilityLabel(Text("Zustimmen und Foto hochladen"))

                        Button {
                            onCancel()
                            dismiss()
                        } label: {
                            Text("Abbrechen")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 2)
                        .accessibilityLabel(Text("Abbrechen"))
                    }
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Hinweise zum Foto-Upload")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        onCancel()
                        dismiss()
                    }
                }
            }
        }
    }

    private func ruleRow(text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "xmark.circle.fill")
                .font(.footnote)
                .foregroundColor(.red.opacity(0.85))
                .padding(.top, 2)

            Text(text)
                .font(.footnote)
                .foregroundColor(.secondary)
                .lineSpacing(2)
        }
    }
}

#Preview {
    PhotoUploadLegalNoticeSheet(onConfirm: {}, onCancel: {})
}
