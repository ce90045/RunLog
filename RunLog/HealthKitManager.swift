import Foundation
import HealthKit

@MainActor
final class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    @Published private(set) var isAuthorized = false
    @Published var errorMessage: String?

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "이 기기에서는 건강 앱을 사용할 수 없습니다."
            return
        }

        let types: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute()
        ]
        do {
            try await healthStore.requestAuthorization(toShare: types, read: types)
            isAuthorized = true
        } catch {
            errorMessage = "건강 앱 권한을 허용해 주세요."
        }
    }

    func save(summary: WorkoutSummary) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let activity: HKWorkoutActivityType = summary.averageSpeedKmh <= 7 ? .walking : .cycling
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activity
        configuration.locationType = .outdoor

        do {
            let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())
            try await builder.beginCollection(withStart: summary.startDate)
            let distance = HKQuantity(unit: .meter(), doubleValue: summary.distanceMeters)
            let distanceType: HKQuantityTypeIdentifier = activity == .walking ? .distanceWalkingRunning : .distanceCycling
            guard let quantityType = HKQuantityType.quantityType(forIdentifier: distanceType) else { return }
            try await builder.add([HKQuantitySample(type: quantityType, quantity: distance, start: summary.startDate, end: summary.endDate)])
            try await builder.endCollection(withEnd: summary.endDate)
            _ = try await builder.finishWorkout()
        } catch {
            errorMessage = "건강 앱에 운동 기록을 저장하지 못했습니다."
        }
    }
}
