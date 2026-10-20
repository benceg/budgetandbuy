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

Before the first App Store release, deploy the CloudKit schema from Development to Production in the CloudKit Console.
