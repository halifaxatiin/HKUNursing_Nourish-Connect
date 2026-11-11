import SwiftUI

enum FoodRoute: Hashable {
    case barcode
    case label
    case meal
}

/// Food hub: scan a barcode, photograph the nutrition label, or pick a dish from the list.
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
                    BigButtonLabel(title: Str.pickFood,
                                   hint: Str.pickFoodHint,
                                   systemImage: "list.bullet")
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
            case .meal: DishListView()
            }
        }
        .speaksOnAppear(Str.foodSpoken)
    }
}
