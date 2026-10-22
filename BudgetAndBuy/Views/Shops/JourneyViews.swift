import CoreLocation
import SwiftUI

/// "[car] 6 min · [walking figure] 22 min", or a crossed-out location arrow
/// when Location is off.
struct JourneyLabel: View {
    let journey: Journey?
    /// Without a journey: true when your location is what's missing, rather
    /// than Maps not having answered yet.
    var isLocationOff = false

    var body: some View {
        if let journey {
            Text("\(Image(systemName: "car")) \(Journey.format(minutes: journey.driveMinutes)) · \(Image(systemName: "figure.walk")) \(Journey.format(minutes: journey.walkMinutes))")
                .monospacedDigit()
                .accessibilityLabel("\(Journey.format(minutes: journey.driveMinutes)) by car, \(Journey.format(minutes: journey.walkMinutes)) on foot")
        } else if isLocationOff {
            Image(systemName: "location.slash")
                .accessibilityLabel("Location is off")
        } else {
            Text("\(Image(systemName: "car")) – · \(Image(systemName: "figure.walk")) –")
                .accessibilityLabel("Working out how far it is")
        }
    }
}

/// How long it takes to get to a shop from where you are, worked out when shown.
struct ShopJourney: View {
    let store: Store
    private var journeys: Journeys { .shared }

    var body: some View {
        JourneyLabel(journey: journeys.fromHere(to: store), isLocationOff: journeys.access != .allowed)
            .task(id: JourneyKey(location: journeys.location, store: store)) {
                await journeys.load(to: [store])
            }
    }
}

/// Changes when you've moved far enough, or the shop has, for the journey to change.
struct JourneyKey: Hashable {
    let location: CLLocation?
    let latitude: Double
    let longitude: Double

    init(location: CLLocation?, store: Store) {
        self.location = location
        latitude = store.latitude
        longitude = store.longitude
    }
}

/// Asks to turn Location on, so the app can show how far each shop is. Show
/// it only while `Journeys.shared.access` isn't `.allowed`.
struct LocationBanner: View {
    var message: LocalizedStringResource = "See how far each shop is, and plan the best route."
    @Environment(\.openURL) private var openURL
    private var journeys: Journeys { .shared }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "location")
                .font(.title3)
                .foregroundStyle(Color.brandInk)
                .frame(width: 40, height: 40)
                .background(Color.brandPale, in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text(journeys.access == .denied ? "Location is off" : "Turn on Location")
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if journeys.access == .denied {
                    // iOS only asks once; after that it's up to you in Settings.
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .font(.subheadline.weight(.semibold))
                } else {
                    Button("Turn On Location") {
                        Task { await journeys.requestAccess() }
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
            Spacer(minLength: 0)
        }
    }
}
