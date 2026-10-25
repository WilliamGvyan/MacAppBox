import Foundation

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
let now = Date(timeIntervalSince1970: 1_792_771_200 + 12 * 60 * 60)

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("验证失败：\(message)\n", stderr)
        exit(1)
    }
}

let sameDayDates = (0 ..< 6).map {
    now.addingTimeInterval(-Double($0) * 60)
}
let briefUse = LaunchStat(
    count: 6,
    lastLaunched: now,
    firstLaunched: sameDayDates.last,
    launchDates: sameDayDates,
    activeDayKeys: ["2026-10-24"]
)
let briefRecommendation = briefUse.recommendation(at: now, calendar: calendar)
require(briefRecommendation.historyCount == 6, "历史次数应完整保留")
require(briefRecommendation.activeDayCount == 1, "同一天多次启动只算一个活跃日")
require(!briefRecommendation.isEligible, "同一天连续打开不应进入常用推荐")

let threeDayDates = [0, 1, 2].map {
    calendar.date(byAdding: .day, value: -$0, to: now)!
}
let threeDayUse = LaunchStat(
    count: 3,
    lastLaunched: now,
    firstLaunched: threeDayDates.last,
    launchDates: threeDayDates,
    activeDayKeys: ["2026-10-22", "2026-10-23", "2026-10-24"]
)
require(
    threeDayUse.recommendation(at: now, calendar: calendar).isEligible,
    "跨三个活跃日应进入常用推荐"
)

let previousDay = calendar.date(byAdding: .day, value: -1, to: now)!
let establishedUse = LaunchStat(
    count: 8,
    lastLaunched: now,
    firstLaunched: previousDay,
    launchDates: Array(repeating: previousDay, count: 4)
        + Array(repeating: now, count: 4),
    activeDayKeys: ["2026-10-23", "2026-10-24"]
)
require(
    establishedUse.recommendation(at: now, calendar: calendar).isEligible,
    "跨两天且累计八次应进入常用推荐"
)

let legacyDate = calendar.date(byAdding: .day, value: -10, to: now)!
let legacyUse = LaunchStat(count: 5, lastLaunched: legacyDate)
let recordedUse = legacyUse.recordingLaunch(at: now, calendar: calendar)
require(recordedUse.count == 6, "旧统计次数应继续累加")
require(recordedUse.launchDates?.count == 2, "旧统计应保留最近一次已有证据")
require(recordedUse.activeDayKeys?.count == 2, "新启动应记录独立活跃日")

let recentRecommendation = LaunchStat(
    count: 12,
    lastLaunched: previousDay,
    firstLaunched: previousDay,
    launchDates: Array(repeating: previousDay, count: 12),
    activeDayKeys: ["2026-10-23"]
).recommendation(at: now, calendar: calendar)
let staleDate = calendar.date(byAdding: .day, value: -120, to: now)!
let staleRecommendation = LaunchStat(
    count: 12,
    lastLaunched: staleDate,
    firstLaunched: staleDate,
    launchDates: Array(repeating: staleDate, count: 12),
    activeDayKeys: ["2026-06-26"]
).recommendation(at: now, calendar: calendar)
require(
    recentRecommendation.score > staleRecommendation.score,
    "近期活跃的历史记录应获得更高推荐分"
)

print("常用推荐历史评分验证通过：同一天连续启动、跨日使用、旧数据迁移与时间衰减均符合预期。")
