import ActivityKit
import SwiftUI
import WidgetKit

@main
struct BudgetAndBuyWidgets: WidgetBundle {
    var body: some Widget {
        ShoppingLiveActivity()
    }
}

/// The store you're in, the basket total so far and what to pick up next.
struct ShoppingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ShoppingActivityAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(.canvas)
                .activitySystemActionForegroundColor(.brandInk)
        } dynamicIsland: { context in
            let color = ListAppearance.color(named: context.attributes.colorName)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.storeName, systemImage: "storefront")
                        .font(.headline)
                        .foregroundStyle(color)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(Money.format(context.state.basketMinor))
                        .font(.title3.bold())
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: "basket")
                    .foregroundStyle(color)
            } compactTrailing: {
                Text(Money.format(context.state.basketMinor))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            } minimal: {
                Image(systemName: "basket")
                    .foregroundStyle(color)
            }
            .keylineTint(color)
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<ShoppingActivityAttributes>

    var body: some View {
        let color = ListAppearance.color(named: context.attributes.colorName)
        HStack(spacing: 12) {
            Text(String(context.attributes.storeName.prefix(1)).uppercased())
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(ListAppearance.foreground(named: context.attributes.colorName))
                .frame(width: 44, height: 44)
                .background(color, in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.storeName)
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                Text(context.state.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Money.format(context.state.basketMinor))
                    .font(.title2.bold())
                    .foregroundStyle(Color.ink)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("\(context.state.basketCount) in basket")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

private extension ShoppingActivityAttributes.ContentState {
    var summary: String {
        if remainingCount == 0 {
            return String(localized: "Everything’s in the basket")
        }
        let next = upNext.joined(separator: ", ")
        return next.isEmpty
            ? String(localized: "\(remainingCount) to buy")
            : String(localized: "\(remainingCount) to buy · \(next)")
    }
}
