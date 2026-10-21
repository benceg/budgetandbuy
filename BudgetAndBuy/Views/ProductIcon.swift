import SwiftUI

/// A product's icon, or its aisle's while it has none.
struct ProductIcon: View {
    let product: Product?

    var body: some View {
        Group {
            if let icon = product?.icon {
                Image(icon.imageName)
            } else {
                Image((product?.category ?? .other).icon.imageName)
            }
        }
        .accessibilityHidden(true)
    }
}
