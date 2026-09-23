import Foundation

enum CheckInWindowResolver {
    static func closest(
        to date: Date,
        settings: AppSettings,
        calendar: Calendar = .current
    ) -> CheckInWindow {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let currentMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)

        return CheckInWindow.allCases.min { lhs, rhs in
            let lhsHour = settings.checkInHours[lhs] ?? lhs.defaultHour
            let rhsHour = settings.checkInHours[rhs] ?? rhs.defaultHour
            let lhsDistance = circularMinuteDistance(from: currentMinutes, to: lhsHour * 60)
            let rhsDistance = circularMinuteDistance(from: currentMinutes, to: rhsHour * 60)

            if lhsDistance == rhsDistance {
                return lhsHour < rhsHour
            }
            return lhsDistance < rhsDistance
        } ?? .morning
    }

    private static func circularMinuteDistance(from start: Int, to end: Int) -> Int {
        let directDistance = abs(start - end)
        return min(directDistance, 24 * 60 - directDistance)
    }
}
