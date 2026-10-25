import Foundation

struct LaunchRecommendation: Equatable {
    let score: Double
    let historyCount: Int
    let activeDayCount: Int
    let recentCount: Int
    let lastLaunched: Date

    var isEligible: Bool {
        let repeatedAcrossDays = activeDayCount >= 3 && historyCount >= 3
        let establishedAcrossDays = activeDayCount >= 2 && historyCount >= 8
        return repeatedAcrossDays || establishedAcrossDays
    }
}

extension LaunchStat {
    static let launchHistoryLimit = 200

    func recommendation(
        at now: Date = Date(),
        calendar: Calendar = .current
    ) -> LaunchRecommendation {
        let knownDates = (launchDates ?? []).filter { $0 <= now }
        let knownDayKeys = Set(activeDayKeys ?? []).union(
            knownDates.map { Self.dayKey(for: $0, calendar: calendar) }
        )
        let historyCount = max(count, knownDates.count, knownDayKeys.count)
        let recentCutoff = calendar.date(byAdding: .day, value: -30, to: now)
            ?? now.addingTimeInterval(-30 * 86_400)
        let recentCount = knownDates.filter { $0 >= recentCutoff }.count
        let latestDate = max(lastLaunched, knownDates.max() ?? .distantPast)
        let ageInDays = max(0, now.timeIntervalSince(latestDate) / 86_400)
        let recencyBoost = 3 * exp(-ageInDays / 21)
        let score = log1p(Double(historyCount)) * 1.6
            + log1p(Double(recentCount)) * 2.2
            + Double(min(knownDayKeys.count, 30)) * 0.7
            + recencyBoost

        return LaunchRecommendation(
            score: score,
            historyCount: historyCount,
            activeDayCount: knownDayKeys.count,
            recentCount: recentCount,
            lastLaunched: latestDate
        )
    }

    func recordingLaunch(
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> LaunchStat {
        var dates = launchDates ?? []
        if launchDates == nil, count > 0 {
            dates.append(lastLaunched)
        }
        dates = Array((dates + [date]).suffix(Self.launchHistoryLimit))

        var dayKeys = Set(activeDayKeys ?? [])
        if activeDayKeys == nil, count > 0 {
            dayKeys.insert(Self.dayKey(for: lastLaunched, calendar: calendar))
        }
        dayKeys.insert(Self.dayKey(for: date, calendar: calendar))

        return LaunchStat(
            count: count + 1,
            lastLaunched: date,
            firstLaunched: firstLaunched ?? (count > 0 ? lastLaunched : date),
            launchDates: dates,
            activeDayKeys: dayKeys.sorted()
        )
    }

    private static func dayKey(
        for date: Date,
        calendar: Calendar
    ) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}
