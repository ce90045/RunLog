import Foundation
import CoreLocation

enum WorkoutStatus: Equatable {
    case idle
    case recording
    case paused
    case autoHeld
    case completed

    var displayName: String {
        switch self {
        case .idle, .completed: return "운동 시작"
        case .recording: return "운동 종료"
        case .paused: return "일시정지 중"
        case .autoHeld: return "자동 홀딩"
        }
    }
}

struct RoutePoint: Codable, Identifiable {
    let latitude: CLLocationDegrees
    let longitude: CLLocationDegrees
    let speedKmh: Double

    var id: String { "\(latitude),\(longitude)" }
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }

    init(_ location: CLLocation) {
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        speedKmh = max(0, location.speed * 3.6)
    }

    private enum CodingKeys: String, CodingKey { case latitude, longitude, speedKmh }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        latitude = try container.decode(CLLocationDegrees.self, forKey: .latitude)
        longitude = try container.decode(CLLocationDegrees.self, forKey: .longitude)
        speedKmh = try container.decodeIfPresent(Double.self, forKey: .speedKmh) ?? 0
    }
}

struct WorkoutSummary {
    let startDate: Date
    let endDate: Date
    let distanceMeters: CLLocationDistance
    let activeDuration: TimeInterval
    let averageSpeedKmh: Double
    let maximumSpeedKmh: Double
    let route: [RoutePoint]

    var activityName: String { averageSpeedKmh <= 7 ? "걷기 운동" : "자전거 운동" }
}

struct WorkoutRecord: Codable, Identifiable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let distanceMeters: CLLocationDistance
    let activeDuration: TimeInterval
    let averageSpeedKmh: Double
    let maximumSpeedKmh: Double
    let route: [RoutePoint]

    init(summary: WorkoutSummary) {
        id = UUID()
        startDate = summary.startDate
        endDate = summary.endDate
        distanceMeters = summary.distanceMeters
        activeDuration = summary.activeDuration
        averageSpeedKmh = summary.averageSpeedKmh
        maximumSpeedKmh = summary.maximumSpeedKmh
        route = summary.route
    }

    var activityName: String { averageSpeedKmh <= 7 ? "걷기 운동" : "자전거 운동" }
}
