# Budget & Buy

A shared shopping list for iPhone. iCloud is the whole backend: there's no server and no login, and nothing is collected.

## Getting started

Open `BudgetAndBuy.xcodeproj` in Xcode 27 or later. The first time you run on a device, Xcode registers the bundle ID `app.budgetandbuy` and the iCloud container `iCloud.app.budgetandbuy` with the team.

- Run tests: ⌘U, or `xcodebuild test -scheme BudgetAndBuy -destination 'platform=iOS Simulator,name=iPhone 17'`
- Debug builds launched with `-sampleData` use in-memory sample data instead of your iCloud data.

## How it fits together

- **Household** is the unit of sharing. It owns lists, products and (later) stores and prices. Everyone starts with their own; sharing it is one iCloud invite.
- **Product** is the household's name for a thing ("Semi-skimmed milk"), reused by every list, so prices can attach to it later.
- **Item** is a product on a particular list, with a quantity and whether it's in the basket.
- Core Data mirrors a private store (households you own) and a shared store (households shared with you) to CloudKit. CloudKit requires every attribute to be optional or defaulted and every relationship to have an inverse.
- Devices that create data before their first sync can produce duplicate households or products. `Deduplication.swift` merges them deterministically on every remote change.
- `GroceryCatalogue.swift` lists everyday items with their aisle and icon. Items it recognises get both straight away; anything else is sorted by Apple's on-device model, choosing from the aisle's icons.

## The app

- **Lists** tab: each list has three pages. **Items** has the add field, aisles and basket. **Where to Shop** shows the cheapest, one-stop and closest plans (`Planning.swift`). **Budget** shows the estimated cost by aisle and the month's spending. The bottom button starts and finishes a shop.
- **Shops** tab: shops are added from Maps (nearby, or by name), with the journey estimated by Maps (`ShopFinder.swift`).
- **Savings** tab: money saved and carbon avoided, from finished trips.
- **Household** tab: members and invitations, the monthly budget, settings and help.
- First launch runs a four-step introduction (`OnboardingView.swift`) that adds shops and a first list.
- Colours and shared components live in `Shared/Palette.swift` and `Theme/Components.swift`. The app icon's source is `Tools/AppIcon/icon.svg`.

## Product icons

Product icons are custom SF Symbols adapted from free icon sets (mostly Hugeicons; all MIT, ISC or Apache 2.0). `Tools/Icons/icons.json` says where each one comes from. To rebuild them after changing that file:

```sh
brew install swiftdraw
python3 Tools/Icons/build.py
```

The script writes `Assets.xcassets/Grocery Icons` and `Resources/Icon Licences.txt`, which must ship with the app.

Before the first App Store release, deploy the CloudKit schema from Development to Production in the CloudKit Console.
