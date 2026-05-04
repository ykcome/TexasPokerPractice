import Foundation
import Combine

@MainActor
final class PlayerProfileManager: ObservableObject {
    static let shared = PlayerProfileManager()
    
    @Published private(set) var profile: PlayerProfile
    
    private let profileKey = "PlayerProfileDataV2" // Changed key to reset old data
    
    private init() {
        if let data = UserDefaults.standard.data(forKey: profileKey),
           let savedProfile = try? JSONDecoder().decode(PlayerProfile.self, from: data) {
            profile = savedProfile
        } else {
            profile = PlayerProfile.defaultProfile
            saveProfile()
        }

        resetDailyStaminaIfNeeded()
        checkAndResetDailyPromo()
    }
    
    private func saveProfile() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: profileKey)
        }
    }
    
    private func resetDailyStaminaIfNeeded() {
        let calendar = Calendar.current
        let today = Date()
        if let lastDate = profile.lastStaminaResetDate, calendar.isDate(lastDate, inSameDayAs: today) {
            return
        }
        profile.stamina = 3
        profile.lastStaminaResetDate = today
        saveProfile()
    }
    
    func checkAndResetDailyPromo() {
        let calendar = Calendar.current
        let today = Date()
        
        if let lastDate = profile.promoWatchDate, !calendar.isDate(lastDate, inSameDayAs: today) {
            profile.promoWatchCountToday = 0
            profile.promoWatchDate = today
            saveProfile()
        }
    }
    
    func addStamina(_ amount: Int) {
        guard amount > 0 else { return }
        profile.stamina += amount
        saveProfile()
    }
    
    func spendStamina(_ amount: Int) -> Bool {
        guard amount > 0 else { return true }
        if profile.stamina >= amount {
            profile.stamina -= amount
            saveProfile()
            return true
        }
        return false
    }
    
    func updateCustomName(_ name: String?) {
        profile.customName = name
        saveProfile()
    }
    
    func updateCustomAvatar(_ data: Data?) {
        profile.customAvatarData = data
        saveProfile()
    }
    
    func markAsFeedbacked() {
        profile.hasFeedbackApp = true
        saveProfile()
    }
    
    func incrementPromoWatchCount() {
        let calendar = Calendar.current
        let today = Date()
        
        if let lastDate = profile.promoWatchDate, calendar.isDate(lastDate, inSameDayAs: today) {
            profile.promoWatchCountToday += 1
        } else {
            profile.promoWatchCountToday = 1
        }
        profile.promoWatchDate = today
        saveProfile()
    }
    
    func addSNGRecord(tournamentId: UUID, playerId: UUID, rank: Int, buyIn: Int, reward: Int) {
        // No longer using SNGRecord. Hand history acts as the source of truth.
        saveProfile()
    }

    func isFavorite(handId: String) -> Bool {
        profile.favoriteHandIds.contains(handId)
    }

    func toggleFavorite(handId: String) {
        if let idx = profile.favoriteHandIds.firstIndex(of: handId) {
            profile.favoriteHandIds.remove(at: idx)
        } else {
            profile.favoriteHandIds.append(handId)
        }
        saveProfile()
    }
    
    var stats: PlayerStats {
        return PlayerStats(
            currentStamina: profile.stamina,
            totalGames: 0,
            firstPlaceCount: 0,
            itmRate: 0.0
        )
    }
}
