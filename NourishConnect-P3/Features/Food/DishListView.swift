import SwiftUI

/// Pick what you ate from a list of common dishes, grouped by kind (rice, noodles, dim sum...).
/// The app does not guess from a photo: the user always chooses.
struct DishListView: View {
    @Environment(\.theme) private var theme
    @State private var chosen: Dish?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12, pinnedViews: [.sectionHeaders]) {
                // First, so it can be reached without scrolling past the whole list.
                ReadAloudButton(text: Str.mealListSpoken)
                    .padding(.top, 12)

                ForEach(DishCatalog.sections, id: \.category) { section in
                    Section {
                        ForEach(section.dishes) { dish in
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
                    } header: {
                        Text(section.category.title)
                            .font(theme.font(24, weight: .heavy))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 12)
                            .padding(.bottom, 6)
                            .background(Color(.systemBackground))
                            .accessibilityAddTraits(.isHeader)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .navigationTitle(Str.mealListTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $chosen) { MealResultView(dish: $0) }
        .speaksOnAppear(Str.mealListSpoken)
    }
}
