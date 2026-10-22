The app icons, one per theme: `shopping-bag-sage.svg` is the main icon, and the others are alternate icons people can choose in Household → Appearance.

To update them, edit the SVGs and run `python3 Tools/AppIcon/render.py` (it needs Inkscape). It renders each theme's light, dark and tinted icons into the matching `BudgetAndBuy/Assets.xcassets/AppIcon*.appiconset`. iOS uses the tinted icon for clear icons too. The script finds the background and shadow by their ids (`rect18`, `ellipse18`), so keep those ids if you edit the SVGs. Also replace the 360 × 360 copy in `Logo-*.imageset` that the app shows in its settings and introduction.

Each theme's colours in `Shared/Palette.swift` are taken from its icon's gradients.
