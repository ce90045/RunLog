import SwiftUI
import MapKit

struct ContentView: View {
    @EnvironmentObject private var workout: WorkoutManager
    @StateObject private var health = HealthKitManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    statusBadge
                    mainMetric
                    if workout.status == .recording || workout.status == .paused || workout.status == .autoHeld {
                        LiveRouteMap(route: workout.route)
                            .frame(height: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    metrics
                    controls
                    Text("5초 동안 움직임이 없으면 자동 홀딩됩니다. 10m 이상 이동하면 자동으로 재개됩니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if let message = workout.authorizationMessage ?? health.errorMessage {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(24)
            }
            .navigationTitle("운동 기록")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        WorkoutHistoryView(history: workout.history)
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .accessibilityLabel("운동 기록 보기")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("건강 앱 연결") { Task { await health.requestAuthorization() } }
                        .font(.subheadline)
                }
            }
        }
    }

    private var statusBadge: some View {
        Text(statusText)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(statusColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(statusColor.opacity(0.14), in: Capsule())
    }

    private var mainMetric: some View {
        VStack(spacing: 6) {
            Text(String(format: "%.2f", workout.distanceMeters / 1_000))
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text("킬로미터")
                .foregroundStyle(.secondary)
        }
    }

    private var metrics: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricCard(title: "운동 시간", value: workout.elapsedText, unit: "")
            MetricCard(title: "평균 속도", value: String(format: "%.1f", workout.averageSpeedKmh), unit: "km/h")
            MetricCard(title: "최고 속도", value: String(format: "%.1f", workout.maximumSpeedKmh), unit: "km/h")
            MetricCard(title: "km당 랩타임", value: paceText, unit: "/km")
        }
    }

    private var controls: some View {
        HStack(spacing: 14) {
            Button(action: workout.startOrFinish) {
                Label(workout.status == .recording || workout.status == .paused || workout.status == .autoHeld ? "운동 종료" : "운동 시작", systemImage: workout.status == .recording || workout.status == .paused || workout.status == .autoHeld ? "stop.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(workout.status == .recording || workout.status == .paused || workout.status == .autoHeld ? .red : .blue)

            if workout.status == .recording || workout.status == .paused || workout.status == .autoHeld {
                Button(action: workout.pauseOrResume) {
                    Label(workout.status == .paused ? "재시작" : "일시정지", systemImage: workout.status == .paused ? "play.fill" : "pause.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .controlSize(.large)
    }

    private var paceText: String {
        guard let pace = workout.paceSecondsPerKm else { return "--:--" }
        return String(format: "%02d:%02d", Int(pace) / 60, Int(pace) % 60)
    }

    private var statusText: String {
        switch workout.status {
        case .idle: return "준비됨"
        case .recording: return "기록 중"
        case .paused: return "수동 일시정지"
        case .autoHeld: return "자동 홀딩"
        case .completed: return "기록 완료 · \(workout.lastSummary?.activityName ?? "운동")"
        }
    }

    private var statusColor: Color {
        switch workout.status {
        case .recording: return .green
        case .autoHeld: return .orange
        case .paused: return .yellow
        default: return .blue
        }
    }
}

private struct LiveRouteMap: View {
    let route: [RoutePoint]
    @State private var position: MapCameraPosition = .userLocation(followsHeading: false, fallback: .automatic)

    var body: some View {
        Map(position: $position) {
            UserAnnotation()
            let averageSpeed = RouteSpeedStyle.averageSpeed(of: route)
            ForEach(Array(route.indices.dropFirst()), id: \.self) { index in
                let point = route[index]
                MapPolyline(coordinates: [route[index - 1].coordinate, point.coordinate])
                    .stroke(RouteSpeedStyle.color(speedKmh: point.speedKmh, averageKmh: averageSpeed), lineWidth: 5)
            }
            if let first = route.first {
                Marker("시작", coordinate: first.coordinate).tint(.green)
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .onChange(of: route.count) { _, _ in
            guard let last = route.last else { return }
            position = .region(MKCoordinateRegion(
                center: last.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
            ))
        }
        .overlay(alignment: .bottomLeading) {
            RouteSpeedLegend()
                .padding(10)
        }
    }
}

struct RouteSpeedLegend: View {
    var body: some View {
        HStack(spacing: 9) {
            legendItem(.blue, "느림")
            legendItem(.green, "평균")
            legendItem(.red, "빠름")
        }
        .font(.caption2.weight(.medium))
        .padding(8)
        .background(.regularMaterial, in: Capsule())
    }

    private func legendItem(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(.title2.weight(.bold)).monospacedDigit()
                if !unit.isEmpty { Text(unit).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    ContentView().environmentObject(WorkoutManager())
}
