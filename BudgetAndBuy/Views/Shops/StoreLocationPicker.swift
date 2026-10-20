import CoreLocation
import MapKit
import SwiftUI

/// Places a store on the map: search Maps and tap a result, or tap anywhere.
struct StoreLocationPicker: View {
    let storeName: String
    let onPick: (CLLocationCoordinate2D) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var position: MapCameraPosition
    @State private var picked: CLLocationCoordinate2D?
    @State private var query: String
    @State private var results: [MKMapItem] = []
    @State private var selectedResult: MKMapItem?
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var locationManager = CLLocationManager()

    init(storeName: String, initial: CLLocationCoordinate2D?, onPick: @escaping (CLLocationCoordinate2D) -> Void) {
        self.storeName = storeName
        self.onPick = onPick
        _picked = State(initialValue: initial)
        _query = State(initialValue: storeName)
        _position = State(initialValue: initial.map {
            .region(MKCoordinateRegion(center: $0, latitudinalMeters: 1_000, longitudinalMeters: 1_000))
        } ?? .userLocation(fallback: .automatic))
    }

    var body: some View {
        NavigationStack {
            MapReader { proxy in
                Map(position: $position, selection: $selectedResult) {
                    UserAnnotation()
                    ForEach(results, id: \.self) { result in
                        Marker(result.name ?? "", coordinate: result.location.coordinate)
                            .tint(.gray)
                            .tag(result)
                    }
                    if let picked {
                        Marker(storeName, systemImage: "storefront.fill", coordinate: picked)
                    }
                }
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                }
                .onMapCameraChange(frequency: .onEnd) { context in
                    visibleRegion = context.region
                }
                .onTapGesture { point in
                    if let coordinate = proxy.convert(point, from: .local) {
                        picked = coordinate
                    }
                }
            }
            .onChange(of: selectedResult) {
                if let selectedResult {
                    picked = selectedResult.location.coordinate
                }
            }
            .safeAreaInset(edge: .bottom) {
                Text("Tap a search result, or anywhere on the map, to place \(storeName.isEmpty ? String(localized: "the store") : storeName).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.bar)
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Maps")
            .onSubmit(of: .search) {
                Task { await search() }
            }
            .navigationTitle("Store Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if let picked { onPick(picked) }
                        dismiss()
                    }
                    .disabled(picked == nil)
                }
            }
            .task {
                locationManager.requestWhenInUseAuthorization()
                if picked == nil, !query.isEmpty {
                    // Give the map a moment to centre on you so results are nearby.
                    try? await Task.sleep(for: .seconds(1))
                    await search()
                }
            }
        }
    }

    private func search() async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .pointOfInterest
        if let visibleRegion { request.region = visibleRegion }
        results = (try? await MKLocalSearch(request: request).start().mapItems) ?? []
        if !results.isEmpty { position = .automatic }
    }
}
