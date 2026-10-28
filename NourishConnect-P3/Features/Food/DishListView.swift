import SwiftUI

/// The whole dish list as big buttons. Always available, with or without a camera or model.
struct DishListView: View {
    @Environment(\.theme) private var theme
    @State private var chosen: Dish?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(DishCatalog.all) { dish in
                    Button {
                        chosen = dish
                    } label: {
                        Text(dish.name)
                            .font(theme.font(26, weight: .bold))
                            .foregroundStyle(theme.onFill)
                            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                            .padding(.horizontal, 20)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(theme.fill()))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .navigationTitle(Str.mealListTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $chosen) { MealResultView(dish: $0) }
        .speaksOnAppear(Str.mealListSpoken)
    }
}
