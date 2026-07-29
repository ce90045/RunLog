import SwiftUI
import MapKit

struct WorkoutHistoryView: View {
    @ObservedObject private var history: WorkoutHistoryStore

    init(history: WorkoutHistoryStore) {
        _history = ObservedObject(wrappedValue: history)
    }

    var body: some View {
        Group {
            if history.records.isEmpty {
                ContentUnavailableView("저장된 운동이 없습니다", systemImage: "figure.walk", description: Text("운동을 종료하면 경로와 기록이 여기에 저장됩니다."))
            } else {
                List(history.records) { record in
                    NavigationLink(value: record) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(record.activityName).font(.headline)
                            Text(record.startDate, format: .dateTime.year().month().day().hour().minute())
                                .font(.subheadline).foregroundStyle(.secondary)
                            Text(String(format: "%.2f km · %.1f km/h", record.distanceMeters / 1_000, record.averageSpeedKmh))
                                .font(.subheadline)
                        }
                    }
                }
                .navigationDestination(for: WorkoutRecord.self) { record in
                    WorkoutDetailView(record: record)
                }
            }
        }
        .navigationTitle("운동 기록")
    }
}

extension WorkoutRecord: Hashable {
    static func == (lhs: WorkoutRecord, rhs: WorkoutRecord) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct WorkoutDetailView: View {
    let record: WorkoutRecord
    @State private var position: MapCameraPosition

    init(record: WorkoutRecord) {
        self.record = record
        let coordinates = record.route.map(\.coordinate)
        if let region = Self.region(for: coordinates) {
            _position = State(initialValue: .region(region))
        } else {
            _position = State(initialValue: .automatic)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Map(position: $position) {
                    ForEach(Array(record.route.indices.dropFirst()), id: \.self) { index in
                        let point = record.route[index]
                        MapPolyline(coordinates: [record.route[index - 1].coordinate, point.coordinate])
                            .stroke(RouteSpeedStyle.color(speedKmh: point.speedKmh, averageKmh: record.averageSpeedKmh), lineWidth: 5)
                    }
                    if let first = record.route.first {
                        Marker("시작", coordinate: first.coordinate).tint(.green)
                    }
                    if let last = record.route.last {
                        Marker("종료", coordinate: last.coordinate).tint(.red)
                    }
                }
                .frame(height: 330)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(alignment: .bottomLeading) {
                    RouteSpeedLegend().padding(10)
                }

                HStack {
                    detailMetric("거리", String(format: "%.2f km", record.distanceMeters / 1_000))
                    detailMetric("평균 속도", String(format: "%.1f km/h", record.averageSpeedKmh))
                    detailMetric("운동 시간", durationText(record.activeDuration))
                }
            }
            .padding()
        }
        .navigationTitle(record.activityName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detailMetric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 5) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold)).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func durationText(_ duration: TimeInterval) -> String {
        String(format: "%02d:%02d:%02d", Int(duration) / 3600, Int(duration) / 60 % 60, Int(duration) % 60)
    }

    private static func region(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
        guard let first = coordinates.first else { return nil }
        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        let minLat = latitudes.min() ?? first.latitude
        let maxLat = latitudes.max() ?? first.latitude
        let minLon = longitudes.min() ?? first.longitude
        let maxLon = longitudes.max() ?? first.longitude
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(latitudeDelta: max((maxLat - minLat) * 1.4, 0.01), longitudeDelta: max((maxLon - minLon) * 1.4, 0.01))
        )
    }
}
