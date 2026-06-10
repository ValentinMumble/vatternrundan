import Foundation
import CoreLocation

// MARK: - Model

enum Direction: String, CaseIterable {
    case outbound
    case returning

    var title: String {
        switch self {
        case .outbound: "Outbound · Wed 10 – Thu 11 Jun"
        case .returning: "Return · Mon 22 – Tue 23 Jun"
        }
    }
}

struct Leg: Identifiable, Equatable {
    let id: Int
    let direction: Direction
    let from: String
    let to: String
    let departure: Date
    let arrival: Date
    let price: Double
    let via: [CLLocationCoordinate2D]

    static func == (lhs: Leg, rhs: Leg) -> Bool { lhs.id == rhs.id }

    var path: [CLLocationCoordinate2D] {
        [TripData.stations[from]!] + via + [TripData.stations[to]!]
    }

    var duration: TimeInterval { arrival.timeIntervalSince(departure) }

    var crossesMidnight: Bool {
        !TripData.calendar.isDate(departure, inSameDayAs: arrival)
    }

    var distanceKm: Double {
        let points = path.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
        return zip(points, points.dropFirst()).reduce(0) { $0 + $1.0.distance(from: $1.1) } / 1000
    }
}

enum TripRow: Identifiable {
    case leg(Leg)
    case layover(minutes: Int, beforeLeg: Leg)
    case bike

    var id: String {
        switch self {
        case .leg(let leg): "leg-\(leg.id)"
        case .layover(_, let leg): "layover-\(leg.id)"
        case .bike: "bike"
        }
    }
}

enum Selection: Equatable {
    case leg(Int)
    case layover(beforeLegId: Int)
    case bike
}

// MARK: - Data (ported from the web app)

enum TripData {
    static let stations: [String: CLLocationCoordinate2D] = [
        "Nantes": .init(latitude: 47.2175, longitude: -1.5419),
        "Bruxelles-Midi": .init(latitude: 50.8354, longitude: 4.3369),
        "Köln Hbf": .init(latitude: 50.9430, longitude: 6.9583),
        "Hamburg Hbf": .init(latitude: 53.5527, longitude: 10.0065),
        "Malmö C": .init(latitude: 55.6093, longitude: 13.0007),
        "Stockholm Central": .init(latitude: 59.3301, longitude: 18.0573),
        "Offenburg": .init(latitude: 48.4766, longitude: 7.9468),
        "Strasbourg": .init(latitude: 48.5850, longitude: 7.7349),
    ]

    // Via points so polylines roughly follow real rail corridors.
    static let legs: [Leg] = [
        Leg(id: 0, direction: .outbound, from: "Nantes", to: "Bruxelles-Midi",
            departure: date("2026-06-10T05:59"), arrival: date("2026-06-10T11:01"), price: 22.00,
            via: coords([(47.99, 0.19), (48.73, 2.26), (50.64, 3.07)])),            // Le Mans · Massy · Lille
        Leg(id: 1, direction: .outbound, from: "Bruxelles-Midi", to: "Köln Hbf",
            departure: date("2026-06-10T12:25"), arrival: date("2026-06-10T14:15"), price: 8.00,
            via: coords([(50.62, 5.57), (50.77, 6.09)])),                           // Liège · Aachen
        Leg(id: 2, direction: .outbound, from: "Köln Hbf", to: "Hamburg Hbf",
            departure: date("2026-06-10T15:11"), arrival: date("2026-06-10T19:32"), price: 8.00,
            via: coords([(51.52, 7.46), (51.96, 7.63), (53.08, 8.81)])),            // Dortmund · Münster · Bremen
        Leg(id: 3, direction: .outbound, from: "Hamburg Hbf", to: "Malmö C",
            departure: date("2026-06-10T21:53"), arrival: date("2026-06-11T04:30"), price: 38.60,
            via: coords([(54.79, 9.44), (55.40, 10.39), (55.67, 12.57)])),          // Padborg · Odense · Copenhagen
        Leg(id: 4, direction: .outbound, from: "Malmö C", to: "Stockholm Central",
            departure: date("2026-06-11T05:07"), arrival: date("2026-06-11T10:25"), price: 8.20,
            via: coords([(56.90, 14.55), (58.59, 16.18)])),                         // Alvesta · Norrköping
        Leg(id: 5, direction: .returning, from: "Stockholm Central", to: "Hamburg Hbf",
            departure: date("2026-06-22T17:28"), arrival: date("2026-06-23T05:53"), price: 20.40,
            via: coords([(58.59, 16.18), (56.90, 14.55), (55.61, 13.00), (55.67, 12.57), (55.40, 10.39), (54.79, 9.44)])),
        Leg(id: 6, direction: .returning, from: "Hamburg Hbf", to: "Offenburg",
            departure: date("2026-06-23T07:44"), arrival: date("2026-06-23T13:58"), price: 8.00,
            via: coords([(52.38, 9.74), (50.107, 8.66), (49.01, 8.40)])),           // Hannover · Frankfurt · Karlsruhe
        Leg(id: 7, direction: .returning, from: "Strasbourg", to: "Nantes",
            departure: date("2026-06-23T17:01"), arrival: date("2026-06-23T22:23"), price: 12.00,
            via: coords([(48.73, 2.26), (47.99, 0.19), (47.46, -0.55)])),           // Massy · Le Mans · Angers
    ]

    // Rough Vätternrundan loop (counterclockwise from Motala).
    static let raceLoop: [CLLocationCoordinate2D] = coords([
        (58.537, 15.036), (58.448, 14.890), (58.227, 14.652), (58.025, 14.467),
        (57.781, 14.156), (57.910, 14.070), (58.170, 14.137), (58.300, 14.290),
        (58.540, 14.510), (58.879, 14.902), (58.700, 15.050), (58.537, 15.036),
    ])

    static let motala = CLLocationCoordinate2D(latitude: 58.537, longitude: 15.036)

    static let interrailPass = 240.0
    static let bikeFrom = "Offenburg"
    static let bikeTo = "Strasbourg"
    static let bikeKm = 26.0
    static var bikePath: [CLLocationCoordinate2D] { [stations[bikeFrom]!, stations[bikeTo]!] }

    // MARK: Derived

    static func legs(for direction: Direction) -> [Leg] {
        legs.filter { $0.direction == direction }
    }

    /// Legs interleaved with layovers; the unbooked Rhine crossing shows up
    /// as a bike row wherever consecutive legs don't share a station.
    static func rows(for direction: Direction) -> [TripRow] {
        var rows: [TripRow] = []
        var previous: Leg?
        for leg in legs(for: direction) {
            if let previous {
                if previous.to == leg.from {
                    let minutes = Int(leg.departure.timeIntervalSince(previous.arrival) / 60)
                    rows.append(.layover(minutes: minutes, beforeLeg: leg))
                } else {
                    rows.append(.bike)
                }
            }
            rows.append(.leg(leg))
            previous = leg
        }
        return rows
    }

    static func doorToDoor(for direction: Direction) -> TimeInterval {
        let legs = legs(for: direction)
        return legs.last!.arrival.timeIntervalSince(legs.first!.departure)
    }

    static var totalTrainTime: TimeInterval { legs.reduce(0) { $0 + $1.duration } }
    static var totalKm: Double { legs.reduce(0) { $0 + $1.distanceKm } }
    static var seatCost: Double { legs.reduce(0) { $0 + $1.price } }
    static var allCoordinates: [CLLocationCoordinate2D] { legs.flatMap(\.path) }

    // MARK: Time plumbing

    static let timeZone = TimeZone(identifier: "Europe/Paris")!

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }()
}

// MARK: - Formatting helpers

private let isoFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
    formatter.timeZone = TripData.timeZone
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
}()

private func date(_ iso: String) -> Date { isoFormatter.date(from: iso)! }

private func coords(_ pairs: [(Double, Double)]) -> [CLLocationCoordinate2D] {
    pairs.map { CLLocationCoordinate2D(latitude: $0.0, longitude: $0.1) }
}

private let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    formatter.timeZone = TripData.timeZone
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
}()

func formatTime(_ date: Date) -> String { timeFormatter.string(from: date) }

func formatDuration(_ interval: TimeInterval) -> String {
    let totalMinutes = Int((interval / 60).rounded())
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    if hours == 0 { return "\(minutes)m" }
    return String(format: "%dh%02d", hours, minutes)
}

func shortName(_ station: String) -> String {
    station
        .replacingOccurrences(of: " Hbf", with: "")
        .replacingOccurrences(of: " Central", with: "")
        .replacingOccurrences(of: " C", with: "")
        .replacingOccurrences(of: "-Midi", with: "")
}

func euro(_ value: Double) -> String { String(format: "€%.2f", value) }
