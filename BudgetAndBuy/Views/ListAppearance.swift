import SwiftUI

/// The colours and symbols a list can wear, as in Reminders.
enum ListAppearance {
    static let colorNames = [
        "red", "orange", "yellow", "green", "mint", "teal",
        "cyan", "blue", "indigo", "purple", "pink", "brown",
    ]

    static let symbolNames = [
        "cart.fill", "basket.fill", "bag.fill", "carrot.fill", "fork.knife", "cup.and.saucer.fill",
        "wineglass.fill", "birthday.cake.fill", "frying.pan.fill", "flame.fill", "leaf.fill", "house.fill",
        "gift.fill", "pawprint.fill", "stroller.fill", "tshirt.fill", "heart.fill", "star.fill",
    ]

    static func color(named name: String?) -> Color {
        switch name {
        case "red": .red
        case "orange": .orange
        case "yellow": .yellow
        case "mint": .mint
        case "teal": .teal
        case "cyan": .cyan
        case "blue": .blue
        case "indigo": .indigo
        case "purple": .purple
        case "pink": .pink
        case "brown": .brown
        default: .green
        }
    }
}

extension ShoppingList {
    var color: Color { ListAppearance.color(named: colorName) }
    var symbol: String { symbolName ?? "cart.fill" }
}

extension Store {
    var color: Color { ListAppearance.color(named: colorName) }
}

/// A white symbol on a coloured circle.
struct ListIcon: View {
    let symbolName: String
    let color: Color
    var size: CGFloat = 32

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: size * 0.48, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: .circle)
            .accessibilityHidden(true)
    }
}
