import SwiftUI
import MapKit

struct ContentView: View {
    @State private var selection: Selection?
    @State private var camera: MapCameraPosition = .region(MKCoordinateRegion(fitting: TripData.allCoordinates))

    var body: some View {
        ZStack {
            TripMap(selection: selection, camera: $camera)
                .ignoresSafeArea()
                .onTapGesture { clearSelection() }

            VStack(spacing: 0) {
                HeaderCard(selection: selection)
                Spacer()
                bottomCards
            }
            .padding(.horizontal, 12)
        }
    }

    private var bottomCards: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(Direction.allCases, id: \.self) { direction in
                    DirectionCard(direction: direction, selection: selection, onSelect: select)
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    private func select(_ newSelection: Selection, _ coordinates: [CLLocationCoordinate2D]) {
        if selection == newSelection {
            clearSelection()
            return
        }
        selection = newSelection
        withAnimation(.spring(duration: 0.7)) {
            camera = .region(MKCoordinateRegion(fitting: coordinates))
        }
    }

    private func clearSelection() {
        guard selection != nil else { return }
        selection = nil
        withAnimation(.spring(duration: 0.7)) {
            camera = .region(MKCoordinateRegion(fitting: TripData.allCoordinates))
        }
    }
}

// MARK: - Header

struct HeaderCard: View {
    let selection: Selection?

    /// Chips show trip totals, or one direction's numbers while it is focused.
    private var focusedDirection: Direction? {
        if case .direction(let direction) = selection { return direction }
        return nil
    }

    var body: some View {
        let trainsCount = focusedDirection.map { TripData.legs(for: $0).count } ?? TripData.legs.count
        let trainTime = focusedDirection.map { TripData.trainTime(for: $0) } ?? TripData.totalTrainTime
        let km = focusedDirection.map { TripData.km(for: $0) } ?? TripData.totalKm

        VStack(alignment: .leading, spacing: 10) {
            Text("🚴 Vätternrundan · 315 km · Sat 13 · 05:00")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.raceAccent)
                .padding(.horizontal, 11)
                .padding(.vertical, 4)
                .background(Color.raceAccent.opacity(0.12), in: .capsule)
                .overlay(Capsule().strokeBorder(Color.raceAccent.opacity(0.35), lineWidth: 0.5))

            Text("Nantes ⇄ Stockholm 🇸🇪")
                .font(.title2.weight(.bold))

            HStack(spacing: 6) {
                StatChip(bold: "\(trainsCount)", rest: " trains")
                StatChip(bold: formatDuration(trainTime), rest: " on rails")
                StatChip(bold: "≈ \(Int(km).formatted()) km", rest: "")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
        .animation(.easeInOut(duration: 0.2), value: focusedDirection)
    }
}

struct StatChip: View {
    let bold: String
    let rest: String

    var body: some View {
        Text("\(Text(bold).fontWeight(.bold))\(rest)")
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(.white.opacity(0.1), in: .capsule)
            .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
    }
}

struct StatBox: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.white.opacity(0.08), in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.14), lineWidth: 0.5))
    }
}

// MARK: - Direction card

struct DirectionCard: View {
    let direction: Direction
    let selection: Selection?
    let onSelect: (Selection, [CLLocationCoordinate2D]) -> Void

    private var accent: Color {
        direction == .outbound ? .outboundAccent : .returnAccent
    }

    private var isFocused: Bool { selection?.owningDirection == direction }
    private var isFaded: Bool { selection != nil && selection?.owningDirection != direction }
    private var showsStats: Bool { selection == .direction(direction) }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button {
                onSelect(.direction(direction), TripData.coordinates(for: direction))
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text(direction.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accent)
                    Spacer()
                    Text(formatDuration(TripData.doorToDoor(for: direction)))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 5)

            if showsStats {
                directionStats
                    .padding(.bottom, 6)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            ForEach(TripData.rows(for: direction)) { row in
                rowView(row)
            }

            arrivalRow
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
        .overlay {
            if isFocused {
                RoundedRectangle(cornerRadius: 28)
                    .strokeBorder(accent.opacity(0.6), lineWidth: 1.5)
            }
        }
        .opacity(isFaded ? 0.45 : 1)
        .animation(.easeInOut(duration: 0.25), value: selection)
    }

    private var directionStats: some View {
        let trainTime = TripData.trainTime(for: direction)
        let waiting = TripData.doorToDoor(for: direction) - trainTime
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
            StatBox(value: formatDuration(trainTime), label: "on trains")
            StatBox(value: formatDuration(waiting), label: "waiting")
            StatBox(value: "≈ \(Int(TripData.km(for: direction))) km", label: "distance")
            StatBox(value: euro(TripData.seatCost(for: direction)), label: "seats")
        }
    }

    @ViewBuilder
    private func rowView(_ row: TripRow) -> some View {
        switch row {
        case .leg(let leg):
            legRow(leg)
        case .layover(let minutes, let beforeLeg):
            layoverRow(minutes: minutes, beforeLeg: beforeLeg)
        case .bike:
            bikeRow
        }
    }

    private func legRow(_ leg: Leg) -> some View {
        let isSelected = selection == .leg(leg.id)
        return Button {
            onSelect(.leg(leg.id), leg.path)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(formatTime(leg.departure))
                        .font(.callout.weight(.bold))
                        .monospacedDigit()
                        .frame(width: 48, alignment: .leading)
                    Text("\(shortName(leg.from)) → \(shortName(leg.to))\(leg.crossesMidnight ? " 🌙" : "")")
                        .font(.callout)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(formatDuration(leg.duration))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                if isSelected {
                    Text("≈ \(Int(leg.distanceKm)) km · \(euro(leg.price)) · arrives \(formatTime(leg.arrival))\(leg.crossesMidnight ? " (+1)" : "")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 56)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(isSelected ? .white.opacity(0.16) : .clear, in: .rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func layoverRow(minutes: Int, beforeLeg: Leg) -> some View {
        let isSelected = selection == .layover(beforeLegId: beforeLeg.id)
        return Button {
            onSelect(.layover(beforeLegId: beforeLeg.id), [TripData.stations[beforeLeg.from]!])
        } label: {
            HStack(spacing: 8) {
                Text("⏱")
                    .font(.caption2)
                    .frame(width: 48, alignment: .leading)
                Text("\(formatDuration(TimeInterval(minutes * 60))) layover")
                    .font(.caption)
                Spacer()
            }
            .foregroundStyle(.secondary)
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background(isSelected ? .white.opacity(0.16) : .clear, in: .rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var bikeRow: some View {
        let isSelected = selection == .bike
        return Button {
            onSelect(.bike, TripData.bikePath)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("🚴")
                        .font(.caption)
                        .frame(width: 48, alignment: .leading)
                    Text("\(TripData.bikeFrom) → \(TripData.bikeTo)")
                        .font(.callout)
                    Spacer(minLength: 4)
                    Text("~\(formatDuration(Double(TripData.bikeRideMinutes) * 60))")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Text("+\(TripData.bikeSetupMinutes)m setup · ride \(formatTime(TripData.bikeDeparture)) → ~\(formatTime(TripData.bikeArrival)) · ≈ \(Int(TripData.bikeKm)) km @ \(Int(TripData.bikeSpeedKmh)) km/h · \(formatDuration(Double(TripData.bikeBufferMinutes) * 60)) buffer")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 56)
            }
            .foregroundStyle(Color.bikeAccent)
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(isSelected ? .white.opacity(0.16) : .clear, in: .rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var arrivalRow: some View {
        let lastLeg = TripData.legs(for: direction).last!
        return HStack(spacing: 8) {
            Text(formatTime(lastLeg.arrival))
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .frame(width: 48, alignment: .leading)
            Text("arrival \(shortName(lastLeg.to))")
                .font(.footnote)
            Spacer()
            Text("\(formatDuration(TripData.doorToDoor(for: direction))) door-to-door")
                .font(.caption2)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .padding(.top, 3)
    }
}

#Preview {
    ContentView()
}
