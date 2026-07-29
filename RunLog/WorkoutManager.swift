import Foundation
import CoreLocation
import Combine

@MainActor
final class WorkoutManager: NSObject, ObservableObject {
    @Published private(set) var status: WorkoutStatus = .idle
    @Published private(set) var distanceMeters: CLLocationDistance = 0
    @Published private(set) var maximumSpeedMps: Double = 0
    @Published private(set) var activeDuration: TimeInterval = 0
    @Published private(set) var startDate: Date?
    @Published private(set) var lastSummary: WorkoutSummary?
    @Published private(set) var route: [RoutePoint] = []
    @Published var authorizationMessage: String?

    private let locationManager = CLLocationManager()
    private var lastLocation: CLLocation?
    private var lastMovingLocation: CLLocation?
    private var nonMovingSince: Date?
    private var ticker: AnyCancellable?
    private var lastTick = Date()
    private var pausedAt: Date?
    private var shouldStartAfterAuthorization = false
    let history = WorkoutHistoryStore()

    var averageSpeedKmh: Double {
        guard activeDuration > 0 else { return 0 }
        return distanceMeters / activeDuration * 3.6
    }
    var maximumSpeedKmh: Double { maximumSpeedMps * 3.6 }
    var paceSecondsPerKm: Double? {
        guard distanceMeters > 1 else { return nil }
        return activeDuration / (distanceMeters / 1_000)
    }
    var elapsedText: String { Self.timeFormatter.string(from: activeDuration) ?? "00:00" }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.activityType = .fitness
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    func startOrFinish() {
        switch status {
        case .idle, .completed: start()
        case .recording, .paused, .autoHeld: finish()
        }
    }

    func pauseOrResume() {
        switch status {
        case .recording, .autoHeld:
            status = .paused
            pausedAt = Date()
        case .paused:
            status = .recording
            pausedAt = nil
            lastLocation = nil
            lastMovingLocation = nil
            nonMovingSince = nil
        default: break
        }
    }

    private func start() {
        guard ensureLocationPermission() else { return }
        distanceMeters = 0
        maximumSpeedMps = 0
        activeDuration = 0
        startDate = Date()
        lastLocation = nil
        lastMovingLocation = nil
        nonMovingSince = nil
        lastSummary = nil
        route = []
        status = .recording
        lastTick = Date()
        locationManager.startUpdatingLocation()
        ticker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in self?.tick(now) }
    }

    private func finish() {
        guard let startDate else { return }
        let endDate = Date()
        let summary = WorkoutSummary(startDate: startDate, endDate: endDate, distanceMeters: distanceMeters, activeDuration: activeDuration, averageSpeedKmh: averageSpeedKmh, maximumSpeedKmh: maximumSpeedKmh, route: route)
        lastSummary = summary
        history.save(WorkoutRecord(summary: summary))
        ticker?.cancel()
        locationManager.stopUpdatingLocation()
        status = .completed
        Task { await HealthKitManager.shared.save(summary: summary) }
    }

    private func tick(_ now: Date) {
        let delta = now.timeIntervalSince(lastTick)
        lastTick = now
        if status == .recording { activeDuration += delta }
    }

    private func ensureLocationPermission() -> Bool {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: return true
        case .notDetermined:
            shouldStartAfterAuthorization = true
            locationManager.requestAlwaysAuthorization()
            return false
        default:
            authorizationMessage = "설정에서 위치 접근을 '항상 허용'으로 변경해 주세요."
            return false
        }
    }

    private static let timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
}

extension WorkoutManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
            authorizationMessage = nil
            if shouldStartAfterAuthorization {
                shouldStartAfterAuthorization = false
                start()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations where location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= 50 {
            process(location)
        }
    }

    private func process(_ location: CLLocation) {
        defer { lastLocation = location }
        if lastLocation == nil, status == .recording {
            route.append(RoutePoint(location))
        }
        guard let previous = lastLocation else { return }
        let segment = location.distance(from: previous)
        let reportedSpeed = max(0, location.speed)
        let isMoving = segment >= 1.5 || reportedSpeed >= 0.5

        if status == .autoHeld {
            if let heldPoint = lastMovingLocation, location.distance(from: heldPoint) >= 10 {
                status = .recording
                nonMovingSince = nil
                lastLocation = location
                lastMovingLocation = location
                route.append(RoutePoint(location))
            }
            return
        }
        guard status == .recording else { return }

        let lastRouteLocation = route.last.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
        if (lastRouteLocation?.distance(from: location) ?? Double.greatestFiniteMagnitude) >= 3 {
            route.append(RoutePoint(location))
        }

        if isMoving {
            distanceMeters += segment
            maximumSpeedMps = max(maximumSpeedMps, reportedSpeed, segment / max(location.timestamp.timeIntervalSince(previous.timestamp), 0.1))
            lastMovingLocation = location
            nonMovingSince = nil
        } else if nonMovingSince == nil {
            nonMovingSince = location.timestamp
        } else if let nonMovingSince, location.timestamp.timeIntervalSince(nonMovingSince) >= 5 {
            lastMovingLocation = lastMovingLocation ?? previous
            status = .autoHeld
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        authorizationMessage = "위치를 가져올 수 없습니다. GPS 신호를 확인해 주세요."
    }
}
