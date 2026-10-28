import SwiftUI
import SwiftData

/// Settings for text size, contrast, voice and emergency contacts.
/// Best set up with a staff member the first time.
struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme
    @Query private var settingsList: [UserSettings]
    @Query(sort: \EmergencyContact.priority) private var contacts: [EmergencyContact]
    @State private var showAddContact = false

    var body: some View {
        Form {
            if let settings = settingsList.first {
                DisplaySection(settings: settings)
                VoiceSection(settings: settings)
            }
            contactsSection
            DemoSection()
        }
        .navigationTitle(Str.settingsTitle)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddContact) {
            AddContactView(nextPriority: (contacts.map(\.priority).max() ?? -1) + 1)
        }
        .speaksOnAppear(Str.settingsSpoken)
    }

    private var contactsSection: some View {
        Section {
            ForEach(contacts) { contact in
                VStack(alignment: .leading, spacing: 4) {
                    Text(contact.name).font(theme.font(20, weight: .semibold))
                    Text(contact.phone).font(theme.font(18)).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
            .onDelete { offsets in
                for index in offsets {
                    context.delete(contacts[index])
                }
            }
            Button {
                showAddContact = true
            } label: {
                Label(Str.addContact, systemImage: "plus.circle.fill")
                    .font(theme.font(20, weight: .semibold))
                    .frame(minHeight: 44)
            }
        } header: {
            Text(Str.contactsSection).font(theme.font(16))
        } footer: {
            Text(Str.staffNote).font(theme.font(14))
        }
    }
}

private struct DisplaySection: View {
    @Environment(\.theme) private var theme
    @Bindable var settings: UserSettings

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(Str.textSize).font(theme.font(20, weight: .semibold))
                Slider(value: $settings.textScale, in: Theme.scaleRange, step: 0.1)
                    .accessibilityLabel(Str.textSize)
                Text(Str.textSizeSample).font(theme.font(20))
            }
            Toggle(Str.highContrast, isOn: $settings.highContrast)
                .font(theme.font(20))
        }
    }
}

private struct VoiceSection: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var speech: SpeechService
    @Bindable var settings: UserSettings

    var body: some View {
        Section {
            Toggle(Str.speechEnabled, isOn: $settings.speechEnabled)
                .font(theme.font(20))

            VStack(alignment: .leading, spacing: 8) {
                Text(Str.speechRate).font(theme.font(20, weight: .semibold))
                Slider(value: $settings.speechRate, in: 0.3...0.6, step: 0.02) {
                    Text(Str.speechRate)
                } minimumValueLabel: {
                    Text(Str.slow).font(theme.font(16))
                } maximumValueLabel: {
                    Text(Str.fast).font(theme.font(16))
                }
            }

            Button {
                speech.speak(Str.testVoiceSpoken, rate: settings.speechRate)
            } label: {
                Label(Str.testVoice, systemImage: "speaker.wave.2.fill")
                    .font(theme.font(20, weight: .semibold))
                    .frame(minHeight: 44)
            }

            if !speech.hasCantoneseVoice {
                Text(Str.noCantoneseVoice)
                    .font(theme.font(16))
                    .foregroundStyle(.orange)
            }
        } header: {
            Text(Str.voiceSection).font(theme.font(16))
        }
    }
}

private struct AddContactView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    let nextPriority: Int
    @State private var name = ""
    @State private var phone = ""

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !phone.filter(\.isNumber).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(Str.contactName, text: $name)
                    .font(theme.font(20))
                    .textContentType(.name)
                TextField(Str.contactPhone, text: $phone)
                    .font(theme.font(20))
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
            }
            .navigationTitle(Str.addContact)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Str.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(Str.save) { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        let contact = EmergencyContact(
            name: name.trimmingCharacters(in: .whitespaces),
            phone: phone.trimmingCharacters(in: .whitespaces),
            priority: nextPriority
        )
        context.insert(contact)
        dismiss()
    }
}

private struct DemoSection: View {
    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme
    @State private var message: String?

    var body: some View {
        Section {
            Button {
                DemoData.load(into: context)
                message = Str.demoLoaded
            } label: {
                Label(Str.demoLoad, systemImage: "wand.and.stars")
                    .font(theme.font(20, weight: .semibold))
                    .frame(minHeight: 44)
            }
            Button(role: .destructive) {
                DemoData.clear(from: context)
                message = Str.demoCleared
            } label: {
                Label(Str.demoClear, systemImage: "trash")
                    .font(theme.font(20, weight: .semibold))
                    .frame(minHeight: 44)
            }
            if let message {
                Text(message).font(theme.font(16)).foregroundStyle(.secondary)
            }
        } header: {
            Text(Str.demoSection).font(theme.font(16))
        } footer: {
            Text(Str.demoFooter).font(theme.font(14))
        }
    }
}
