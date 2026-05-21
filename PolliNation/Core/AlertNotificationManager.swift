import Foundation
import UserNotifications

@MainActor
final class AlertNotificationManager: NSObject, ObservableObject {
    @Published var isAuthorized = false

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
        } catch {
            isAuthorized = false
        }
    }

    func notifyIfNeeded(for report: PollenReport) async {
        await NotificationScheduler.scheduleWarningIfNeeded(report: report)
        await refreshAuthorizationStatus()
    }
}

enum NotificationScheduler {
    static func scheduleWarningIfNeeded(report: PollenReport) async {
        guard let top = report.dominantMeasurement, top.severity.warningNeeded else { return }

        let dateKey = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: report.forecastDate))
        let key = "\(dateKey)-\(report.location.latitude.rounded())-\(report.location.longitude.rounded())-\(top.id)-\(top.index)"
        guard SharedStore.lastNotificationSent() != key else { return }

        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = "High \(top.displayName) pollen near \(report.location.name)"
        content.body = "\(top.category) level detected. Wear a mask and protective eyewear before going outside."
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(identifier: "pollination-\(key)", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
        SharedStore.markNotificationSent(key)
    }
}
