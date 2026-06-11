import SwiftUI
import MapKit

struct TripMap: View {
    let selection: Selection?
    @Binding var camera: MapCameraPosition

    var body: some View {
        Map(position: $camera, interactionModes: .all) {
            ForEach(TripData.legs) { leg in
                MapPolyline(coordinates: leg.path)
                    .stroke(
                        color(for: leg.direction).opacity(opacity(for: leg)),
                        style: StrokeStyle(
                            lineWidth: isSelected(leg) ? 6 : 4,
                            lineCap: .round,
                            lineJoin: .round,
                            dash: leg.direction == .returning ? [10, 9] : []
                        )
                    )
            }

            MapPolyline(coordinates: TripData.bikePath)
                .stroke(
                    Color.bikeAccent.opacity(bikeOpacity),
                    style: StrokeStyle(lineWidth: selection == .bike ? 5 : 3, lineCap: .round, dash: [4, 6])
                )

            MapPolyline(coordinates: TripData.raceLoop)
                .stroke(
                    Color.raceAccent.opacity(selection == nil ? 0.9 : 0.25),
                    style: StrokeStyle(lineWidth: 3, dash: [6, 7])
                )

            ForEach(Array(TripData.stations.keys), id: \.self) { name in
                Annotation(name, coordinate: TripData.stations[name]!) {
                    Circle()
                        .fill(.white)
                        .strokeBorder(.black.opacity(0.6), lineWidth: 1.5)
                        .frame(width: 10, height: 10)
                }
                .annotationTitles(.hidden)
            }

            Annotation("Motala — start & finish", coordinate: TripData.motala) {
                Text("🚴").font(.title3)
            }
            .annotationTitles(.hidden)
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
    }

    private func color(for direction: Direction) -> Color {
        direction == .outbound ? .outboundAccent : .returnAccent
    }

    private func isSelected(_ leg: Leg) -> Bool {
        selection == .leg(leg.id)
    }

    private func opacity(for leg: Leg) -> Double {
        guard let selection else { return 0.95 }
        if case .direction(let direction) = selection { return leg.direction == direction ? 0.95 : 0.12 }
        return isSelected(leg) ? 1 : 0.12
    }

    private var bikeOpacity: Double {
        switch selection {
        case nil: 0.95
        case .bike: 1
        case .direction(.returning): 0.95
        default: 0.12
        }
    }
}

extension MKCoordinateRegion {
    /// Region fitting the given coordinates, padded, with the center nudged
    /// south so the route sits above the bottom cards.
    init(fitting coordinates: [CLLocationCoordinate2D], paddingFactor: Double = 1.4, bottomBias: Double = 0.18) {
        var minLat = 90.0, maxLat = -90.0, minLon = 180.0, maxLon = -180.0
        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * paddingFactor, 0.5),
            longitudeDelta: max((maxLon - minLon) * paddingFactor, 0.5)
        )
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2 - span.latitudeDelta * bottomBias,
            longitude: (minLon + maxLon) / 2
        )
        self.init(center: center, span: span)
    }
}

extension Color {
    static let outboundAccent = Color(red: 0.176, green: 0.831, blue: 0.749)  // #2dd4bf
    static let returnAccent = Color(red: 0.984, green: 0.573, blue: 0.235)    // #fb923c
    static let bikeAccent = Color(red: 0.290, green: 0.871, blue: 0.502)      // #4ade80
    static let raceAccent = Color(red: 0.980, green: 0.800, blue: 0.082)      // #facc15
}
