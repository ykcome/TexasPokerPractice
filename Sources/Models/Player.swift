import Foundation

// MARK: - Player

struct Player: Identifiable, Codable {
    let id: UUID
    var name: String
    var chips: Int
    var seatId: Int  // 固定座位号 (0-5)，整个SNG期间不可变
    var position: Position  // 相对位置，每手牌根据按钮位置动态计算
    var isActive: Bool
    var isAllIn: Bool
    var isFolded: Bool
    var holeCards: [Card]?
    var currentBet: Int       // 当前投入圈的投入金额（投入圈结束时清零）
    var totalInvested: Int   // 本手牌累计总投入（整局游戏不清零）
    var isHuman: Bool
    var aiDifficulty: AIDifficulty
    var isEliminated: Bool  // 标记玩家是否已淘汰，淘汰后不能复活
    var showHoleCards: Bool = false // 标记是否主动亮出底牌（例如All-in时）

    /// 相对位置枚举 - 每手牌根据按钮位置动态计算
    enum Position: Int, Codable, CaseIterable {
        case button = 0   // 庄家按钮
        case sb = 1        // 小底分
        case bb = 2        // 大底分
        case utg = 3       // UTG (枪口位)
        case mp = 4        // MP (中位)
        case co = 5        // CO (关位)

        var displayName: String {
            switch self {
            case .button: return "Button"
            case .sb: return String(localized: "SB")
            case .bb: return String(localized: "BB")
            case .utg: return "UTG"
            case .mp: return "MP"
            case .co: return "CO"
            }
        }

        /// 顺时针下一个位置
        var clockwiseNext: Position {
            switch self {
            case .button: return .sb
            case .sb: return .bb
            case .bb: return .utg
            case .utg: return .mp
            case .mp: return .co
            case .co: return .button
            }
        }

        /// 顺时针下一个位置的索引
        var clockwiseNextIndex: Int {
            (rawValue + 1) % 6
        }
    }

    enum AIDifficulty: String, Codable, CaseIterable {
        case easy = "简单"
        case medium = "中等"
        case hard = "困难"
        case loose = "松凶"

        var vpipRange: ClosedRange<Double> {
            switch self {
            case .easy: return 0.15...0.20
            case .medium: return 0.25...0.35
            case .hard: return 0.20...0.30
            case .loose: return 0.45...0.60   // 松凶：玩大多数手牌
            }
        }

        var aggressionFactor: Double {
            switch self {
            case .easy: return 0.5
            case .medium: return 0.9
            case .hard: return 1.3
            case .loose: return 1.5           // 松凶：极强的进攻性
            }
        }
    }

    init(
        id: UUID = UUID(),
        name: String,
        chips: Int = 1000,
        seatId: Int,  // 必填参数，固定座位号
        isHuman: Bool = false,
        aiDifficulty: AIDifficulty = .medium
    ) {
        self.id = id
        self.name = name
        self.chips = chips
        self.seatId = seatId
        self.position = .bb  // 临时值，会在每手牌开始时重新计算
        self.isActive = true
        self.isAllIn = false
        self.isFolded = false
        self.holeCards = nil
        self.currentBet = 0
        self.totalInvested = 0
        self.isHuman = isHuman
        self.aiDifficulty = aiDifficulty
        self.isEliminated = false
        self.showHoleCards = false
    }

    /// 便捷初始化器 - 保留向后兼容
    init(
        id: UUID = UUID(),
        name: String,
        chips: Int = 1000,
        position: Position,
        isHuman: Bool = false,
        aiDifficulty: AIDifficulty = .medium
    ) {
        self.id = id
        self.name = name
        self.chips = chips
        self.seatId = position.rawValue  // 使用 position.rawValue 作为 seatId
        self.position = position
        self.isActive = true
        self.isAllIn = false
        self.isFolded = false
        self.holeCards = nil
        self.currentBet = 0
        self.totalInvested = 0
        self.isHuman = isHuman
        self.aiDifficulty = aiDifficulty
        self.isEliminated = false
        self.showHoleCards = false
    }

    /// 淘汰玩家
    mutating func eliminate() {
        isEliminated = true
        isActive = false
        chips = 0
    }

    var isEliminatedComputed: Bool {
        isEliminated
    }

    var canBet: Bool {
        isActive && !isFolded && !isAllIn && chips > 0
    }

    mutating func resetForNewHand() {
        // 只有未被淘汰的玩家才能参与下一手牌
        isActive = !isEliminated && chips > 0
        isAllIn = false
        isFolded = false
        holeCards = nil
        currentBet = 0
        totalInvested = 0  // 每手牌重新计算总投入
        showHoleCards = false
    }
}

// MARK: - Player Action

enum PlayerAction: Equatable {
    case fold
    case check
    case call(amount: Int)
    case bet(amount: Int)
    case raise(amount: Int)
    case allIn(amount: Int)

    var displayName: String {
        switch self {
        case .fold: return "弃牌"
        case .check: return "过牌"
        case .call: return "跟注"
        case .bet: return "下注"
        case .raise: return "加注"
        case .allIn: return "全押"
        }
    }

    var amount: Int {
        switch self {
        case .call(let amount), .bet(let amount), .raise(let amount), .allIn(let amount):
            return amount
        default:
            return 0
        }
    }
}
