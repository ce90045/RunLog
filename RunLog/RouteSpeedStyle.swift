import SwiftUI

enum RouteSpeedStyle {
    /// 전체 평균과 비교해 구간의 GPS 속도를 색상으로 구분합니다.
    static func color(speedKmh: Double, averageKmh: Double) -> Color {
        guard averageKmh > 0 else { return .blue }
        if speedKmh < averageKmh * 0.8 { return .blue }
        if speedKmh > averageKmh * 1.2 { return .red }
        return .green
    }

    static func averageSpeed(of route: [RoutePoint]) -> Double {
        let speeds = route.map(\.speedKmh).filter { $0 > 0 }
        guard !speeds.isEmpty else { return 0 }
        return speeds.reduce(0, +) / Double(speeds.count)
    }
}
