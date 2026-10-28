import SwiftUI

enum FoodRoute: Hashable {
    case barcode
    case label
    case meal
}

/// Food hub: scan a barcode, or photograph the nutrition label. Or photograph a meal.
struct FoodView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                NavigationLink(value: FoodRoute.barcode) {
                    BigButtonLabel(title: Str.scanBarcode,
                                   hint: Str.scanBarcodeHint,
                                   systemImage: "barcode.viewfinder")
                }
                .buttonStyle(.plain)

                NavigationLink(value: FoodRoute.label) {
                    BigButtonLabel(title: Str.scanLabel,
                                   hint: Str.scanLabelHint,
                                   systemImage: "text.viewfinder")
                }
                .buttonStyle(.plain)

                NavigationLink(value: FoodRoute.meal) {
                    BigButtonLabel(title: Str.mealPhoto,
                                   hint: Str.mealPhotoHint,
                                   systemImage: "camera.macro")
                }
                .buttonStyle(.plain)

                ReadAloudButton(text: Str.foodSpoken)
            }
            .padding(20)
        }
        .navigationTitle(Str.food)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: FoodRoute.self) { route in
            switch route {
            case .barcode: ScanBarcodeView()
            case .label: ScanLabelView()
            case .meal: MealPhotoView()
            }
        }
        .speaksOnAppear(Str.foodSpoken)
    }
}
