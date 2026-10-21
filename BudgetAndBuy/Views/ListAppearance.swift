import SwiftUI

extension ShoppingList {
    var color: Color { ListAppearance.color(named: colorName) }
    /// Its symbol's colour on `color`.
    var foreground: Color { ListAppearance.foreground(named: colorName) }
    var symbol: String { symbolName ?? "cart.fill" }
}

extension Store {
    var color: Color { ListAppearance.color(named: colorName) }
}

/// A white symbol on a coloured circle.
struct ListIcon: View {
    let symbolName: String
    let color: Color
    var foreground: Color = .white
    var size: CGFloat = 32

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: size * 0.48, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(color, in: .circle)
            .accessibilityHidden(true)
    }
}
