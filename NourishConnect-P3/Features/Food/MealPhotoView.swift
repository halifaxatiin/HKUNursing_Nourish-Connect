import SwiftUI
import PhotosUI

/// Photograph a meal, let the phone guess, ASK the user to confirm, then show the estimate.
/// If there is no model, no camera, or no good guess, the user picks from the list instead.
struct MealPhotoView: View {
    private enum Phase: Equatable {
        case ready
        case thinking
        case confirm(Dish)
        case choose([Dish])
        case noModel
        case noMatch
    }

    @Environment(\.theme) private var theme
    @EnvironmentObject private var speech: SpeechService
    @State private var phase: Phase = .ready
    @State private var image: UIImage?
    @State private var chosen: Dish?
    @State private var showList = false
    @State private var showCamera = false
    @State private var pickerItem: PhotosPickerItem?

    private let classifier: DishClassifying = CoreMLDishClassifier()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 240)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .accessibilityHidden(true)
                }

                content

                Text(Str.mealPhotoNotKept)
                    .font(theme.font(16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                ReadAloudButton(text: Str.mealSpoken)
            }
            .padding(20)
        }
        .navigationTitle(Str.mealTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $chosen) { MealResultView(dish: $0) }
        .navigationDestination(isPresented: $showList) { DishListView() }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { picked in
                showCamera = false
                if let picked {
                    Task { @MainActor in await process(picked) }
                }
            }
            .ignoresSafeArea()
        }
        .speaksOnAppear(Str.mealSpoken)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { @MainActor in
                if let data = try? await item.loadTransferable(type: Data.self),
                   let picked = UIImage(data: data) {
                    await process(picked)
                }
                pickerItem = nil
            }
        }
    }

    // MARK: Pieces

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .ready:
            captureButtons
        case .thinking:
            VStack(spacing: 12) {
                ProgressView().controlSize(.large)
                Text(Str.mealThinking).font(theme.font(24, weight: .semibold))
            }
        case .confirm(let dish):
            VStack(spacing: 16) {
                Text(Str.mealAsk(dish.name))
                    .font(theme.font(30, weight: .bold))
                    .multilineTextAlignment(.center)
                bigButton(Str.mealYes, systemImage: "checkmark.circle.fill") {
                    chosen = dish
                }
                bigButton(Str.mealNo, systemImage: "xmark.circle.fill", prominent: false) {
                    phase = .noMatch
                    showList = true
                }
            }
            .onAppear { speech.speak(Str.mealAsk(dish.name), rate: theme.speechRate) }
        case .choose(let dishes):
            VStack(spacing: 12) {
                Text(Str.mealChoose)
                    .font(theme.font(28, weight: .bold))
                ForEach(dishes) { dish in
                    bigButton(dish.name, systemImage: "fork.knife") { chosen = dish }
                }
                bigButton(Str.mealChooseList, systemImage: "list.bullet", prominent: false) { showList = true }
            }
            .onAppear { speech.speak(Str.mealChoose, rate: theme.speechRate) }
        case .noModel:
            fallbackMessage(Str.mealNoModel)
        case .noMatch:
            fallbackMessage(Str.mealNoMatch)
        }
    }

    private var captureButtons: some View {
        VStack(spacing: 12) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                bigButton(Str.takePhoto, systemImage: "camera.fill") { showCamera = true }
            }
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label(Str.pickPhoto, systemImage: "photo.on.rectangle")
                    .font(theme.font(22, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 60)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            bigButton(Str.mealPickList, systemImage: "list.bullet", prominent: false) { showList = true }
        }
    }

    private func fallbackMessage(_ text: String) -> some View {
        VStack(spacing: 16) {
            Text(text)
                .font(theme.font(24, weight: .semibold))
                .multilineTextAlignment(.center)
            bigButton(Str.mealPickList, systemImage: "list.bullet") { showList = true }
            if image != nil {
                bigButton(Str.scanAgain, systemImage: "arrow.uturn.backward", prominent: false) {
                    image = nil
                    phase = .ready
                }
            }
        }
    }

    private func bigButton(_ title: String, systemImage: String, prominent: Bool = true,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(theme.font(26, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 72)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(prominent ? theme.fill() : Color.gray)
        .foregroundStyle(prominent ? theme.onFill : Color.white)
    }

    // MARK: Logic

    @MainActor
    private func process(_ picked: UIImage) async {
        image = picked
        guard classifier.isAvailable else {
            phase = .noModel
            speech.speak(Str.mealNoModel, rate: theme.speechRate)
            return
        }
        phase = .thinking
        speech.speak(Str.mealThinking, rate: theme.speechRate)
        do {
            let guesses = try await classifier.classify(picked)
            switch DishDecision.decide(guesses) {
            case .confirm(let dish): phase = .confirm(dish)
            case .choose(let dishes): phase = .choose(dishes)
            case .list:
                phase = .noMatch
                speech.speak(Str.mealNoMatch, rate: theme.speechRate)
            }
        } catch {
            phase = .noMatch
            speech.speak(Str.mealNoMatch, rate: theme.speechRate)
        }
    }
}

/// Opens the system camera and hands back one photo.
struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage) }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImage: (UIImage?) -> Void
        init(onImage: @escaping (UIImage?) -> Void) { self.onImage = onImage }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onImage(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImage(nil)
        }
    }
}
