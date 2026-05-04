import Foundation

enum PromoResult: Equatable {
    case rewarded
    case closedNoReward
    case failed(String)
}

@MainActor
final class PromoManager {
    static let shared = PromoManager()

    private init() {}

    func showRewarded() async -> PromoResult {
        return .failed("视频加载失败，请稍后再试")
    }
}

