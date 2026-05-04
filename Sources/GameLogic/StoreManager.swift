import Foundation
import StoreKit

@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()
    
    @Published private(set) var coffeeProduct: Product?
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var statusMessage: String?
    @Published var purchaseError: String?
    @Published var purchaseSuccess: Bool = false
    
    private let coffeeProductID = "100000"
    private var updatesTask: Task<Void, Never>?
    
    private init() {
        updatesTask = listenForTransactions()
        Task {
            await loadProducts()
        }
    }
    
    deinit {
        updatesTask?.cancel()
    }
    
    func loadProducts() async {
        if isLoadingProducts { return }
        isLoadingProducts = true
        statusMessage = String(localized: "正在加载商品…")
        defer { isLoadingProducts = false }
        
        do {
            let products = try await Product.products(for: [coffeeProductID])
            coffeeProduct = products.first
            if coffeeProduct == nil {
                purchaseError = String(localized: "商品未找到，请检查 App Store Connect 配置")
            }
            statusMessage = nil
        } catch {
            purchaseError = String(localized: "商品加载失败：\(error.localizedDescription)")
            statusMessage = nil
        }
    }
    
    func purchaseCoffee() async {
        guard coffeeProduct != nil else {
            purchaseError = nil
            await loadProducts()
            if coffeeProduct == nil { 
                purchaseError = String(localized: "商品未找到，请检查 App Store Connect 配置")
                return 
            }
            return await purchaseCoffee()
        }
        isPurchasing = true
        purchaseSuccess = false
        purchaseError = nil
        statusMessage = String(localized: "正在发起购买…")
        defer { isPurchasing = false }
        
        do {
            guard let product = coffeeProduct else { return }
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                statusMessage = String(localized: "正在验证交易…")
                let transaction = try checkVerified(verification)
                    statusMessage = String(localized: "正在发放体力值…")
                await handleTransaction(transaction)
                statusMessage = String(localized: "正在完成交易…")
                await transaction.finish()
                purchaseSuccess = true
                statusMessage = nil
            case .userCancelled, .pending:
                if case .userCancelled = result {
                    statusMessage = String(localized: "已取消购买")
                } else {
                    statusMessage = String(localized: "购买待处理…")
                }
                break
            @unknown default:
                statusMessage = nil
                break
            }
        } catch {
            purchaseError = String(localized: "购买失败：\(error.localizedDescription)")
            statusMessage = nil
        }
    }
    
    func syncPurchases() async {
        purchaseError = nil
        statusMessage = String(localized: "正在同步购买…")
        do {
            try await AppStore.sync()
            statusMessage = nil
        } catch {
            purchaseError = String(localized: "同步失败：\(error.localizedDescription)")
            statusMessage = nil
        }
    }
    
    private func listenForTransactions() -> Task<Void, Never> {
        Task {
            for await result in Transaction.updates {
                do {
                    let transaction = try checkVerified(result)
                    await handleTransaction(transaction)
                    await transaction.finish()
                } catch {
                }
            }
        }
    }
    
    private func handleTransaction(_ transaction: Transaction) async {
        if transaction.productID == coffeeProductID {
            // Optionally handle purchase success if needed, e.g. logging.
            // buyCoffee no longer exists as it's a pure donation.
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
