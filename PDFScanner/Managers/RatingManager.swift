import SwiftUI
import Combine

enum RatingSource {
    case active  // User clicked "Rate Us"
    case passive // Auto-triggered
}

class RatingManager: ObservableObject {
    static let shared = RatingManager()
    
    @Published var showRatingPopup = false
    @Published var currentSource: RatingSource = .passive
    
    private let kLastRatingVersion = "last_rating_version"
    private let kLastRatingDate = "last_rating_date"
    private let kLaunchCount = "app_launch_count"
    
    private init() {}
    
    /// 增加启动次数
    func incrementLaunchCount() {
        let count = UserDefaults.standard.integer(forKey: kLaunchCount)
        UserDefaults.standard.set(count + 1, forKey: kLaunchCount)
    }
    
    /// 主动触发：用户点击设置页按钮
    func showRating() {
        currentSource = .active
        showRatingPopup = true
    }
    
    /// 被动触发：尝试显示评分弹窗（带频率限制）
    func tryShowRating() {
        // 调试模式下可能需要暂时关闭或放宽限制，但在生产环境中应严格执行
        
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let lastVersion = UserDefaults.standard.string(forKey: kLastRatingVersion)
        
        // 1. 如果当前版本已经评过分，不再弹
        if currentVersion == lastVersion {
            return
        }
        
        // 2. 检查时间间隔（例如 7 天内不重复弹）
        if let lastDate = UserDefaults.standard.object(forKey: kLastRatingDate) as? Date {
            let interval = Date().timeIntervalSince(lastDate)
            if interval < 7 * 24 * 3600 { // 7 days
                return
            }
        }
        
        // 3. 检查启动次数（至少第 3 次启动才弹）
        let count = UserDefaults.standard.integer(forKey: kLaunchCount)
        if count < 3 {
            return
        }
        
        // 4. 满足所有条件，显示弹窗（100% 弹出，无随机性）
        currentSource = .passive
        showRatingPopup = true
    }
    
    /// 记录评分行为（用户点了 4-5 星）
    func markRated() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        UserDefaults.standard.set(currentVersion, forKey: kLastRatingVersion)
        UserDefaults.standard.set(Date(), forKey: kLastRatingDate)
    }
    
    /// 记录稍后提醒（只更新时间，不更新版本）
    func markLater() {
        UserDefaults.standard.set(Date(), forKey: kLastRatingDate)
    }
}
