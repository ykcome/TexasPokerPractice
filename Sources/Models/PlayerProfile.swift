import Foundation

struct PlayerProfile: Codable {
    var customName: String?
    var customAvatarData: Data?
    var stamina: Int
    var lastStaminaResetDate: Date?
    
    var hasFeedbackApp: Bool
    var isPremium: Bool
    var promoWatchCountToday: Int
    var promoWatchDate: Date?
    var favoriteHandIds: [String] = []
    
    static let defaultProfile = PlayerProfile(
        customName: nil,
        customAvatarData: nil,
        stamina: 3,
        lastStaminaResetDate: Date(),
        hasFeedbackApp: false,
        isPremium: false,
        promoWatchCountToday: 0,
        promoWatchDate: nil,
        favoriteHandIds: []
    )
}

struct PlayerStats {
    let currentStamina: Int
    let totalGames: Int
    let firstPlaceCount: Int
    let itmRate: Double
}
