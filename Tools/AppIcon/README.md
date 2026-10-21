The app icons, one per theme: `shopping-bag-sage.svg` is the main icon, and the others are alternate icons people can choose in Household → Appearance.

To update one, render the SVG at 1024 × 1024 with no transparency (for example by opening it in a browser and taking a screenshot), then replace the PNG in the matching `BudgetAndBuy/Assets.xcassets/AppIcon*.appiconset`, and the 360 × 360 copy in `Logo-*.imageset` that the app shows in its settings and introduction.

Each theme's colours in `Shared/Palette.swift` are taken from its icon's gradients.
