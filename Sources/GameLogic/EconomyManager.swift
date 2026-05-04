import Foundation
import StoreKit
import UIKit

enum EconomySheet: Identifiable, Equatable {
    case feedback
    case promoOrPremium
    case earnCoins

    var id: String {
        switch self {
        case .feedback: return "feedback"
        case .promoOrPremium: return "promoOrPremium"
        case .earnCoins: return "earnCoins"
        }
    }
}

@MainActor
final class EconomyManager: ObservableObject {
    static let shared = EconomyManager()

    @Published var activeSheet: EconomySheet?
    @Published var toastMessage: String?

    let staminaCost: Int = 1
    let freeStaminaAmount: Int = 3

    private var pendingStart: (() -> Void)?

    private init() {}

    // Removed startTournament
    
    func startPractice(isFree: Bool = false, action: @escaping () -> Void) {
        if isFree {
            action()
        } else {
            pendingStart = action
            attemptStart()
        }
    }

    func restartTournament(gameManager: GameManager) {
        pendingStart = { [weak gameManager] in
            gameManager?.restartTournament()
        }
        attemptStart()
    }

    func onTournamentFinished(tournamentId: UUID, playerId: UUID, rank: Int) {
        // SNG 输赢不再奖励体力值（回归教育工具属性）
        let reward = 0
        PlayerProfileManager.shared.addSNGRecord(tournamentId: tournamentId, playerId: playerId, rank: rank, buyIn: staminaCost, reward: reward)
    }

    func presentEarnCoins() {
        activeSheet = .earnCoins
    }

    func claimFreeRelief() {
        let p = PlayerProfileManager.shared.profile
        
        if p.promoWatchCountToday >= 3 {
            toastMessage = String(localized: "今日免费领取次数已达上限")
            return
        }

        if !p.hasFeedbackApp {
            requestAppReview()
        }

        PlayerProfileManager.shared.addStamina(freeStaminaAmount)
        PlayerProfileManager.shared.incrementPromoWatchCount()
        toastMessage = String(localized: "已领取\(freeStaminaAmount)体力值")
        activeSheet = nil
        resumeIfPossible()
    }

    func requestAppReview() {
        DispatchQueue.main.async {
            guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
                PlayerProfileManager.shared.markAsFeedbacked()
                return
            }
            SKStoreReviewController.requestReview(in: scene)
            PlayerProfileManager.shared.markAsFeedbacked()
        }
    }

    func watchPromo() async {
        let result = await PromoManager.shared.showRewarded()
        switch result {
        case .rewarded:
            PlayerProfileManager.shared.addStamina(freeStaminaAmount)
            PlayerProfileManager.shared.incrementPromoWatchCount()
            toastMessage = String(localized: "已获得\(freeStaminaAmount)体力值")
            activeSheet = nil
            resumeIfPossible()
        case .closedNoReward:
            break
        case .failed(let message):
            toastMessage = message
        }
    }

    func purchaseCoffee() async {
        await StoreManager.shared.purchaseCoffee()
        if StoreManager.shared.purchaseSuccess {
            PlayerProfileManager.shared.addStamina(1000)
            toastMessage = String(localized: "感谢支持！已获得1000点体力值")
            activeSheet = nil
            resumeIfPossible()
        }
    }

    func clearToast() {
        toastMessage = nil
    }

    private func attemptStart() {
        if PlayerProfileManager.shared.spendStamina(staminaCost) {
            let start = pendingStart
            pendingStart = nil
            activeSheet = nil
            start?()
            return
        }
        
        let p = PlayerProfileManager.shared.profile
        if p.promoWatchCountToday >= 3 {
            toastMessage = String(localized: "体力值不足，明天可以继续领体力值")
            pendingStart = nil
        } else {
            presentRelief()
        }
    }

    private func resumeIfPossible() {
        if PlayerProfileManager.shared.profile.stamina >= staminaCost, pendingStart != nil {
            attemptStart()
        }
    }

    private func presentRelief() {
        let p = PlayerProfileManager.shared.profile
        if !p.hasFeedbackApp {
            activeSheet = .feedback
        } else {
            activeSheet = .promoOrPremium
        }
    }
}
