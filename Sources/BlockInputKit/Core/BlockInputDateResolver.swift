import Foundation

enum BlockInputTemporalCategory: Equatable {
    case past
    case present
    case future
}

enum BlockInputDateDisplayStyle {
    case whenDate
    case deadline
}

struct BlockInputDateResolver {
    static func resolveDate(from string: String, relativeTo referenceDate: Date = Date()) -> Date? {
        let lower = string.lowercased().trimmingCharacters(in: .whitespaces)
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: referenceDate)

        switch lower {
        case "today", "tod":
            return dayStart
        case "tomorrow", "tom":
            return calendar.date(byAdding: .day, value: 1, to: dayStart)
        case "yesterday", "overdue":
            return calendar.date(byAdding: .day, value: -1, to: dayStart)
        case "next week", "next-week":
            return calendar.date(byAdding: .day, value: 7, to: dayStart)
        case "next month", "next-month":
            return calendar.date(byAdding: .month, value: 1, to: dayStart)
        default:
            break
        }

        let dayNames = [
            "sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4,
            "thursday": 5, "friday": 6, "saturday": 7
        ]
        if let targetWeekday = dayNames[lower] {
            let currentWeekday = calendar.component(.weekday, from: dayStart)
            var daysUntil = targetWeekday - currentWeekday
            if daysUntil <= 0 {
                daysUntil += 7
            }
            return calendar.date(byAdding: .day, value: daysUntil, to: dayStart)
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: lower) {
            return calendar.startOfDay(for: date)
        }

        return nil
    }

    static func friendlyDateString(
        from isoString: String,
        style: BlockInputDateDisplayStyle,
        relativeTo referenceDate: Date = Date()
    ) -> String? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: isoString) else { return nil }

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: referenceDate)
        let dateDay = calendar.startOfDay(for: date)

        let shortFormatter = DateFormatter()
        shortFormatter.locale = Locale.current
        shortFormatter.dateFormat = "EEE, MMM d"

        switch style {
        case .deadline:
            return shortFormatter.string(from: date)

        case .whenDate:
            if dateDay == dayStart {
                return "Today"
            }
            if dateDay == calendar.date(byAdding: .day, value: 1, to: dayStart) {
                return "Tomorrow"
            }

            let todayWeekInterval = calendar.dateInterval(of: .weekOfMonth, for: dayStart)
            let dateWeekInterval = calendar.dateInterval(of: .weekOfMonth, for: dateDay)

            if dateDay > dayStart,
               let todayWeek = todayWeekInterval, let dateWeek = dateWeekInterval,
               todayWeek.start == dateWeek.start {
                let dayFormatter = DateFormatter()
                dayFormatter.locale = Locale.current
                dayFormatter.dateFormat = "EEEE"
                return dayFormatter.string(from: date)
            }

            return shortFormatter.string(from: date)
        }
    }

    static func categorize(dateString: String, relativeTo referenceDate: Date = Date()) -> BlockInputTemporalCategory? {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: referenceDate)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else {
            return nil
        }
        let dateDay = calendar.startOfDay(for: date)

        if dateDay == dayStart {
            return .present
        } else if dateDay < dayStart {
            return .past
        } else {
            return .future
        }
    }
}

extension BlockInputDateResolver {
    static func isoDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
