import SwiftUI

// Building blocks shared by every screen, so the app reads as one design.

extension View {
    /// A rounded card on the page.
    func card(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.surface, in: .rect(cornerRadius: 22, style: .continuous))
    }

    /// A grouped list drawn on the app's canvas, with card-coloured rows.
    func themedList() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Color.canvas)
            .listSectionSpacing(20)
    }

    /// Rows drawn as cards; apply to each section of a themed list.
    func onSurface() -> some View {
        listRowBackground(Color.surface)
    }

    /// The page background for scrolling screens that aren't lists.
    func canvasBackground() -> some View {
        background(Color.canvas.ignoresSafeArea())
    }
}

/// The main action on a screen: a full-width forest-green capsule.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.onForest)
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, 20)
            .background(isEnabled ? Color.forest : Color.sage, in: .capsule)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
    }
}

/// A quieter action beside or below a primary one.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.forestInk)
            .frame(maxWidth: .infinity, minHeight: 50)
            .padding(.horizontal, 20)
            .background(Color.sagePale, in: .capsule)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

/// A row of pill-shaped choices, one selected.
struct ChipPicker<Value: Hashable>: View {
    let options: [(value: Value, title: LocalizedStringResource)]
    @Binding var selection: Value
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.value) { option in
                let isSelected = option.value == selection
                Button {
                    withAnimation(.snappy(duration: 0.25)) { selection = option.value }
                } label: {
                    Text(option.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(isSelected ? Color.onForest : Color.ink)
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background {
                            if isSelected {
                                Capsule().fill(Color.forest).matchedGeometryEffect(id: "selection", in: namespace)
                            }
                        }
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color.sunken, in: .capsule)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// A shop's initial on its colour, like a shop sign.
struct StoreBadge: View {
    let name: String?
    let colorName: String?
    var size: CGFloat = 36

    init(store: Store?, size: CGFloat = 36) {
        name = store?.name
        colorName = store?.colorName
        self.size = size
    }

    init(name: String?, colorName: String?, size: CGFloat = 36) {
        self.name = name
        self.colorName = colorName
        self.size = size
    }

    var body: some View {
        Text(String((name ?? "").trimmingCharacters(in: .whitespaces).prefix(1)).uppercased())
            .font(.system(size: size * 0.46, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(ListAppearance.color(named: colorName), in: .circle)
            .accessibilityHidden(true)
    }
}

/// A small rounded tag, such as a quantity or "Cheapest".
struct Tag: View {
    let text: String
    var foreground: Color = .ink
    var background: Color = .sunken

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(background, in: .capsule)
    }
}

/// How far through a budget, as a rounded bar.
struct ProgressBar: View {
    let fraction: Double
    var color: Color = .forest
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.sunken)
                Capsule()
                    .fill(color)
                    .frame(width: max(height, geometry.size.width * min(1, max(0, fraction))))
                    .opacity(fraction > 0 ? 1 : 0)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// A heading above a group of cards.
struct SectionHeading: View {
    let title: LocalizedStringResource
    var detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.ink)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

/// What a screen shows before there's anything on it: what it's for, and the
/// first thing to do.
struct EmptyState<Actions: View>: View {
    let systemImage: String?
    let icon: GroceryIcon?
    let title: LocalizedStringResource
    let message: LocalizedStringResource
    @ViewBuilder let actions: Actions

    init(
        systemImage: String? = nil,
        icon: GroceryIcon? = nil,
        title: LocalizedStringResource,
        message: LocalizedStringResource,
        @ViewBuilder actions: () -> Actions = { EmptyView() }
    ) {
        self.systemImage = systemImage
        self.icon = icon
        self.title = title
        self.message = message
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: 16) {
            Group {
                if let icon {
                    Image(icon.imageName)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
            }
            .font(.system(size: 34))
            .foregroundStyle(Color.forestInk)
            .frame(width: 84, height: 84)
            .background(Color.sagePale, in: .circle)
            .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.ink)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            actions
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

/// A money figure, large, for the top of a screen.
struct HeroAmount: View {
    let minorUnits: Int64
    var size: CGFloat = 40

    var body: some View {
        Text(Money.format(minorUnits))
            .font(.system(size: size, weight: .bold))
            .monospacedDigit()
            .contentTransition(.numericText())
            .foregroundStyle(Color.ink)
    }
}
