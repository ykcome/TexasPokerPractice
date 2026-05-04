import SwiftUI

struct EconomySheetView: View {
    let sheet: EconomySheet
    @ObservedObject var economyManager: EconomyManager
    @ObservedObject private var storeManager = StoreManager.shared
    
    @State private var showStaminaWarning = false
    
    var body: some View {
        let remaining = max(0, 3 - PlayerProfileManager.shared.profile.promoWatchCountToday)
        let currentStamina = PlayerProfileManager.shared.profile.stamina
        
        ScrollView {
            VStack(spacing: 16) {
                Text(sheet == .earnCoins ? String(localized: "免费领取体力值") : String(localized: "体力值不足"))
                    .font(.largeTitle.weight(.bold))
                
                Text(String(localized: "当前体力值：\(currentStamina)"))
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                Button {
                    if currentStamina > 0 {
                        showStaminaWarning = true
                        
                        // Optional: hide warning after 3 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            showStaminaWarning = false
                        }
                    } else {
                        showStaminaWarning = false
                        economyManager.claimFreeRelief()
                    }
                } label: {
                    Text(String(localized: "免费领取 \(economyManager.freeStaminaAmount) 体力值 (今日剩余 \(remaining) 次)"))
                        .font(.headline)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(remaining <= 0)
                
                if showStaminaWarning {
                    Text(String(localized: "只有在体力值为0时才可以免费领取"))
                        .font(.footnote)
                        .foregroundColor(.orange)
                }
                
                Button {
                    Task { await economyManager.purchaseCoffee() }
                } label: {
                    if storeManager.isPurchasing {
                        Text(String(localized: "处理中…"))
                            .font(.headline)
                            .padding(.vertical, 8)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                    } else if let p = storeManager.coffeeProduct {
                        Text(String(localized: "支持开发者 (\(p.displayPrice)) - 赠1000体力"))
                            .font(.headline)
                            .padding(.vertical, 8)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(String(localized: "支持开发者 - 赠1000体力"))
                            .font(.headline)
                            .padding(.vertical, 8)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(storeManager.isLoadingProducts || storeManager.isPurchasing)
                
                if let msg = storeManager.statusMessage {
                    Text(msg)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                if let err = storeManager.purchaseError {
                    Text(err)
                        .font(.body)
                        .foregroundColor(.red)
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text(String(localized: "重要申明"))
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "1. 本产品为纯粹的德州扑克教学与训练工具，体力值仅作为开启训练的门票消耗。"))
                        Text(String(localized: "2. 每天系统自动恢复至3点体力值，另外每天最多可额外免费领取9点（分3次，每次3点）。训练过程中的盈亏不影响体力值。"))
                        Text(String(localized: "3. 教学工具开发不易，自愿支持开发者一杯咖啡，将获赠1000点体力值以供长期训练，谢谢！"))
                    }
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.top, 12)
                .padding(.bottom, 20) // Add bottom padding to ensure content isn't cut off by safe area
            }
            .padding()
            .presentationDetents([.medium, .large])
        }
    }
}
