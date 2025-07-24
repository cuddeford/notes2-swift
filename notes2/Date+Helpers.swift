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
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfDate = calendar.startOfDay(for: self)

        guard let daysDifference = calendar.dateComponents([.day], from: startOfDate, to: startOfToday).day else {
            return ""
        }

        switch daysDifference {
        case 0:
            return "Today"
        case 1:
            return "Yesterday"
        case 2..<7:
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: self)
        case 7..<14:
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return "Last \(formatter.string(from: self))"
        default:
            let years = calendar.dateComponents([.year], from: startOfDate, to: startOfToday).year ?? 0
            if years > 0 {
                return years == 1 ? "Last year" : "\(years) years ago"
            }

            let months = calendar.dateComponents([.month], from: startOfDate, to: startOfToday).month ?? 0
            if months > 0 {
                return months == 1 ? "Last month" : "\(months) months ago"
            }

            let weeks = daysDifference / 7
            if weeks >= 2 {
                return "\(weeks) weeks ago"
            }
            
            return ""
        }
    }
}