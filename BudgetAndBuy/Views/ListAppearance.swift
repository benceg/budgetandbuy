import SwiftUI

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
