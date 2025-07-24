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
        if calendar.isDateInToday(self) { return "Today" }
        if calendar.isDateInYesterday(self) { return "Yesterday" }

        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfDate = calendar.startOfDay(for: self)

        guard let daysDifference = calendar.dateComponents([.day], from: startOfDate, to: startOfToday).day else {
            return ""
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"

        if daysDifference > 1 && daysDifference < 7 {
            return formatter.string(from: self)
        } else if daysDifference >= 7 && daysDifference < 14 {
            return "Last \(formatter.string(from: self))"
        }

        return ""
    }
}
