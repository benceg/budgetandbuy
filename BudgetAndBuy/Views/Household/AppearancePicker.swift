import SwiftUI
import UIKit

extension AppTheme {
    /// The alternate app icon in this theme's colours; nil for the main one.
    var iconName: String? {
        self == .sage ? nil : "AppIcon-\(rawValue.capitalized)"
    }

    /// A picture of the app icon, for showing in the app.
    var logoName: String { "Logo-\(rawValue.capitalized)" }

    init(iconName: String?) {
        self = AppTheme.allCases.first { $0.iconName == iconName } ?? .sage
    }
}

/// Chooses the app's colours and, separately, its Home Screen icon.
struct AppearancePicker: View {
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .sage
    @State private var icon = AppTheme(iconName: UIApplication.shared.alternateIconName)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            choices(title: "Colour", selection: theme.title) {
                ForEach(AppTheme.allCases) { option in
                    Button {
                        withAnimation { theme = option }
                    } label: {
                        Circle()
                            .fill(option.swatch)
                            .frame(width: 40, height: 40)
                            .padding(4)
                            .overlay {
                                if option == theme {
                                    Circle().strokeBorder(Color.ink.opacity(0.6), lineWidth: 2.5)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(option.title))
                    .accessibilityAddTraits(option == theme ? .isSelected : [])
                }
            }

            choices(title: "App Icon", selection: icon.title) {
                ForEach(AppTheme.allCases) { option in
                    Button {
                        setIcon(option)
                    } label: {
                        Image(option.logoName)
                            .resizable()
                            .frame(width: 44, height: 44)
                            .clipShape(.rect(cornerRadius: 11, style: .continuous))
                            .padding(3)
                            .overlay {
                                if option == icon {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Color.ink.opacity(0.6), lineWidth: 2.5)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("\(option.title) icon"))
                    .accessibilityAddTraits(option == icon ? .isSelected : [])
                }
            }
        }
        .padding(.vertical, 8)
        .sensoryFeedback(.selection, trigger: theme)
    }

    private func choices<Options: View>(title: LocalizedStringResource, selection: LocalizedStringResource, @ViewBuilder options: () -> Options) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .foregroundStyle(Color.ink)
                Spacer()
                Text(selection)
                    .foregroundStyle(Color.inkSecondary)
            }
            HStack(spacing: 0) {
                options()
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func setIcon(_ option: AppTheme) {
        guard option != icon, UIApplication.shared.supportsAlternateIcons else { return }
        let previous = icon
        icon = option
        Task {
            do {
                try await UIApplication.shared.setAlternateIconName(option.iconName)
            } catch {
                icon = previous
            }
        }
    }
}
