import MapKit
import SwiftUI

/// Sets where a shop is: choose an address from Maps' suggestions as you
/// type, or move the map so the pin sits on the shop. Either way fills in the
/// address, which a shop can't be saved without.
struct ShopLocationChooser: View {
    @Binding var place: ShopPlace?
    /// What to suggest addresses for to begin with, such as the shop's name.
    var startingQuery = ""

    @State private var query = ""
    @State private var completer = AddressCompleter()
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var center: CLLocationCoordinate2D?
    @State private var isMovingMap = false
    @State private var lookUp: Task<Void, Never>?
    @State private var isLookingUp = false
    @State private var isNowhere = false
    @FocusState private var isTyping: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.inkSecondary)
                TextField("Search for the address", text: $query)
                    .focused($isTyping)
                    .textContentType(.fullStreetAddress)
                    .submitLabel(.search)
                if isTyping && !query.isEmpty {
                    Button("Clear", systemImage: "xmark.circle") { query = "" }
                        .labelStyle(.iconOnly)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            .padding(14)
            .background(Color.sunken, in: .rect(cornerRadius: 14))

            if isTyping && !completer.results.isEmpty {
                suggestions
            }

            map

            status
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onChange(of: query) {
            if isTyping { completer.update(query, near: center) }
        }
        .onChange(of: isTyping) {
            if isTyping { completer.update(query, near: center) }
        }
        .task { start() }
    }

    private var suggestions: some View {
        VStack(spacing: 0) {
            ForEach(Array(completer.results.prefix(5).enumerated()), id: \.offset) { index, completion in
                Button {
                    Task { await choose(completion) }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(completion.title)
                            .foregroundStyle(Color.ink)
                        if !completion.subtitle.isEmpty {
                            Text(completion.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(Color.inkSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                if index < min(completer.results.count, 5) - 1 {
                    Divider().overlay(Color.hairline)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(Color.surface, in: .rect(cornerRadius: 14))
    }

    private var map: some View {
        Map(position: $position) {
            UserAnnotation()
        }
        .mapControls {
            MapUserLocationButton()
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            center = context.region.center
            // Only a move you made sets the address: not the map settling on
            // where you are, or on an address you chose.
            guard isMovingMap else { return }
            isMovingMap = false
            lookUpAddress(at: context.region.center)
        }
        .simultaneousGesture(DragGesture(minimumDistance: 4).onChanged { _ in
            isMovingMap = true
            isTyping = false
        })
        .overlay {
            // The pin's point sits on the middle of the map.
            Image(systemName: "mappin")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.brand)
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                .offset(y: -17)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .frame(height: 260)
        .clipShape(.rect(cornerRadius: 18, style: .continuous))
        .accessibilityLabel("Map. Move it so the pin is on the shop.")
    }

    @ViewBuilder
    private var status: some View {
        if isLookingUp {
            HStack(spacing: 8) {
                ProgressView()
                Text("Finding the address…")
                    .foregroundStyle(Color.inkSecondary)
            }
        } else if let place {
            Label(place.fullAddress, systemImage: "mappin.and.ellipse")
                .foregroundStyle(Color.ink)
        } else if isNowhere {
            Text("There’s no address there. Move the pin onto a street, or search for the address.")
                .foregroundStyle(Color.apricot)
        } else {
            Text("Choose an address from the suggestions, or move the map so the pin is on the shop.")
                .foregroundStyle(Color.inkSecondary)
        }
    }

    private func start() {
        if let place {
            query = place.fullAddress
            position = Self.region(around: place.coordinate)
        } else {
            query = startingQuery
            isTyping = true
        }
    }

    private func choose(_ completion: MKLocalSearchCompletion) async {
        isTyping = false
        lookUp?.cancel()
        isLookingUp = true
        defer { isLookingUp = false }
        guard let item = try? await MKLocalSearch(request: MKLocalSearch.Request(completion: completion)).start().mapItems.first else {
            isNowhere = true
            return
        }
        var found = ShopPlace(address: item)
        if found.fullAddress.isEmpty {
            found.fullAddress = [completion.title, completion.subtitle].filter { !$0.isEmpty }.joined(separator: ", ")
            found.address = completion.title
        }
        set(found)
        withAnimation { position = Self.region(around: found.coordinate) }
    }

    private func lookUpAddress(at coordinate: CLLocationCoordinate2D) {
        lookUp?.cancel()
        isLookingUp = true
        lookUp = Task {
            let found = await ShopPlace.lookUp(coordinate)
            guard !Task.isCancelled else { return }
            isLookingUp = false
            if let found {
                set(found)
            } else {
                place = nil
                isNowhere = true
            }
        }
    }

    private func set(_ found: ShopPlace) {
        place = found
        query = found.fullAddress
        isNowhere = false
    }

    private static func region(around coordinate: CLLocationCoordinate2D) -> MapCameraPosition {
        .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 400, longitudinalMeters: 400))
    }
}

/// Changes a shop's location, from its Edit screen.
struct ShopLocationSheet: View {
    let storeName: String
    let onDone: (ShopPlace) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var place: ShopPlace?

    init(storeName: String, place: ShopPlace, onDone: @escaping (ShopPlace) -> Void) {
        self.storeName = storeName
        self.onDone = onDone
        _place = State(initialValue: place)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                ShopLocationChooser(place: $place)
                    .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .canvasBackground()
            .navigationTitle(storeName.isEmpty ? String(localized: "Location") : storeName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if let place { onDone(place) }
                        dismiss()
                    }
                    .disabled(place == nil)
                }
            }
        }
    }
}

/// Suggests addresses and places from Maps as you type.
@MainActor
@Observable
final class AddressCompleter: NSObject, @preconcurrency MKLocalSearchCompleterDelegate {
    private(set) var results: [MKLocalSearchCompletion] = []
    @ObservationIgnored private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.resultTypes = [.address, .pointOfInterest]
        completer.delegate = self
    }

    func update(_ query: String, near coordinate: CLLocationCoordinate2D?) {
        if let coordinate {
            completer.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 40_000, longitudinalMeters: 40_000)
        }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            completer.cancel()
            results = []
        } else {
            completer.queryFragment = trimmed
        }
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
        results = []
    }
}
