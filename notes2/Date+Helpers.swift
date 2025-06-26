import Foundation

extension Date {
    func formattedDate() -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        let day = calendar.component(.day, from: self)

        let suffix: String
        switch day {
        case 1, 21, 31: suffix = "st"
        case 2, 22: suffix = "nd"
        case 3, 23: suffix = "rd"
        default: suffix = "th"
        }

        if calendar.isDate(self, equalTo: Date(), toGranularity: .year) {
            // Same year, exclude year
            formatter.dateFormat = "d'\(suffix)' MMMM"
        } else {
            // Different year, include year
            formatter.dateFormat = "d'\(suffix)' MMMM yy"
        }
        return formatter.string(from: self)
    }

    func relativeDate() -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) {
            return "Today"
        }
        if calendar.isDateInYesterday(self) {
            return "Yesterday"
        }

        let now = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!

        if self >= startOfWeek {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: self)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return "Last \(formatter.string(from: self))"
        }
    }
}
