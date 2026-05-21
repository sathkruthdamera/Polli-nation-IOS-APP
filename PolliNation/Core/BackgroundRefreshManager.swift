import Foundation
import BackgroundTasks
import WidgetKit

enum BackgroundRefreshManager {
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: AppConstants.backgroundRefreshTaskID, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            handle(task: task)
        }
    }

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: AppConstants.backgroundRefreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60 * 4)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(task: BGAppRefreshTask) {
        schedule()
        let refreshTask = Task {
            guard let location = SharedStore.loadLocation() else {
                task.setTaskCompleted(success: false)
                return
            }
            do {
                let report = try await PollenService().fetchPollen(for: location)
                SharedStore.save(report: report)
                await NotificationScheduler.scheduleWarningIfNeeded(report: report)
                WidgetCenter.shared.reloadAllTimelines()
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
        task.expirationHandler = { refreshTask.cancel() }
    }
}
