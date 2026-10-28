import SwiftUI
import SwiftData
import MessageUI

/// The call screen: big hold-to-call buttons for the user's contacts, crisis lines and 999.
/// Used by the Help button, the mood alert, and the distress words in chat. It works offline:
/// it uses only the phone's own dialler and saved contacts. Opening it, and every call or message
/// started from it, is logged as an AlertEvent.
struct CallScreenView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Query(sort: \EmergencyContact.priority) private var contacts: [EmergencyContact]

    @State private var logged = false
    @State private var messageTarget: CallTarget?

    let reason: CallReason

    private var targets: [CallTarget] {
        let mine = contacts.enumerated().map { index, contact in
            CallTarget(id: "contact-\(index)", name: contact.name, phone: contact.phone, kind: .contact)
        }
        return CrisisLines.targets(for: reason, contacts: mine)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text(reason.spoken)
                    .font(theme.font(24, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                ForEach(targets) { target in
                    VStack(spacing: 8) {
                        HoldToCallButton(target: target) { place(target) }
                        if target.kind == .contact, MFMessageComposeViewController.canSendText() {
                            Button {
                                messageTarget = target
                            } label: {
                                Label(Str.sendMessage, systemImage: "message.fill")
                                    .font(theme.font(20, weight: .semibold))
                                    .frame(maxWidth: .infinity, minHeight: 48)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                Text(Str.holdHint)
                    .font(theme.font(18))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                ReadAloudButton(text: reason.spoken)

                Button {
                    dismiss()
                } label: {
                    Label(Str.imOkay, systemImage: "checkmark")
                        .font(theme.font(22, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(20)
        }
        .navigationTitle(Str.callTitle)
        .navigationBarTitleDisplayMode(.inline)
        .speaksOnAppear(reason.spoken)
        .onAppear(perform: logShown)
        .sheet(item: $messageTarget) { target in
            MessageComposeView(recipient: target.phone, body: Str.alertMessageBody) {
                log("message composed: \(target.name)")
                messageTarget = nil
            }
        }
    }

    private func logShown() {
        guard !logged else { return }
        logged = true
        log("call screen shown")
    }

    private func place(_ target: CallTarget) {
        log("call placed: \(target.name)")
        let number = target.phone.filter { $0.isNumber || $0 == "+" }
        guard !number.isEmpty, let url = URL(string: "tel://\(number)") else { return }
        openURL(url)
    }

    private func log(_ action: String) {
        context.insert(AlertEvent(trigger: reason.logKey, action: action))
    }
}

/// The call screen shown over everything else, with a close button.
struct CallScreenCover: View {
    @Environment(\.dismiss) private var dismiss
    let reason: CallReason

    var body: some View {
        NavigationStack {
            CallScreenView(reason: reason)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(Str.close) { dismiss() }
                    }
                }
        }
    }
}

/// A button that must be held until its bar fills before the call starts, so a stray touch
/// cannot place a call. VoiceOver users activate it with a normal double tap.
struct HoldToCallButton: View {
    let target: CallTarget
    let onCall: () -> Void

    @State private var progress: CGFloat = 0

    var body: some View {
        BigButtonLabel(title: target.name,
                       hint: target.displayPhone,
                       systemImage: "phone.fill",
                       emphasis: target.kind == .emergency)
            .overlay(alignment: .leading) {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: geometry.size.width * progress)
                }
                .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .onLongPressGesture(minimumDuration: target.holdSeconds, maximumDistance: 80) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onCall()
            } onPressingChanged: { pressing in
                if pressing {
                    withAnimation(.linear(duration: target.holdSeconds)) { progress = 1 }
                } else {
                    withAnimation(.easeOut(duration: 0.2)) { progress = 0 }
                }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onCall() }
            .accessibilityHint(Str.holdHint)
    }
}

/// Apple's message composer, pre-filled. The user still presses Send.
struct MessageComposeView: UIViewControllerRepresentable {
    let recipient: String
    let body: String
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.recipients = [recipient]
        controller.body = body
        controller.messageComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                          didFinishWith result: MessageComposeResult) {
            onFinish()
        }
    }
}
