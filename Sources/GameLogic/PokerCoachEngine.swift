import Foundation
import SwiftUI

// MARK: - 动作特征结构体
struct ActionContext {
    let handStrength: HandStrengthCategory
    let actionType: HandActionType
    let betRatio: Float            // 投入占总分比例 (对于bet和raise)
    let potOdds: Float             // 回报率
    let equity: Float              // 胜率
    let isPreflopAggressor: Bool   // 是否翻前激进者 (用于C-Invest判断)
    let phase: String              // 阶段
}

// 牌力分级枚举
enum HandStrengthCategory {
    case air        // 空气牌
    case draw       // 听牌 (同花听/顺子听)
    case weakPair   // 弱对 (底对/中对)
    case topPair    // 顶对
    case strong     // 强牌 (两对/三条)
    case nuts       // 坚果/极强牌 (顺子/同花/葫芦及以上)
    
    var isStrong: Bool {
        return self == .topPair || self == .strong || self == .nuts
    }
}


// MARK: - 评价建议
struct CoachAdvice: Codable, Equatable {
    let tag: PlayTag
    let comment: String
}

struct CoachContext {
    let position: String
    let stackBB: Double
    let playersRemaining: Int
}

// MARK: - 评价标签枚举
enum PlayTag: String, Codable {
    case none = "none"
    case badCall = "badCall"
    case passiveValue = "passiveValue"
    case smallBetNuts = "smallBetNuts"
    case standardCBet = "standardCBet"
    case goodFold = "goodFold"
    case bluffOpportunity = "bluffOpportunity"
    case tooTight = "tooTight"
    case badBeat = "badBeat"
    case goodValueBet = "goodValueBet"
    case looseCall = "looseCall"
    case goodRaise = "goodRaise"
    case badFold = "badFold"
    
    var localizedName: String {
        switch self {
        case .none: return String(localized: "无明显标签")
        case .badCall: return String(localized: "负EV跟注/全押")
        case .passiveValue: return String(localized: "强牌被动")
        case .smallBetNuts: return String(localized: "强牌投入偏小")
        case .standardCBet: return String(localized: "标准持续施压")
        case .goodFold: return String(localized: "好弃牌")
        case .bluffOpportunity: return String(localized: "好的诈唬时机")
        case .tooTight: return String(localized: "打得太紧")
        case .badBeat: return String(localized: "Bad Beat (运气极差)")
        case .goodValueBet: return String(localized: "漂亮的价值下注")
        case .looseCall: return String(localized: "过于松的跟注")
        case .goodRaise: return String(localized: "出色的加注")
        case .badFold: return String(localized: "不该弃牌的强牌")
        }
    }
}

// MARK: - 规则引擎：提取标签
class PokerCoachEngine {
    
    static let shared = PokerCoachEngine()
    
    func evaluate(context: ActionContext) -> PlayTag {
        // 规则1：负EV跟注（听牌或空气，胜率明显低于回报率，且动作是跟注或全押）
        if context.actionType == .CALL || context.actionType == .ALL_IN {
            if context.handStrength == .draw || context.handStrength == .air {
                // 放宽容错空间，让错误点评更容易触发
                if context.equity < context.potOdds - 0.02 {
                    return .badCall
                }
            }
        }
        
        // 规则1.5：瞎全押 (空气牌/弱牌胜率极低时直接全押，大概率是乱推)
        if context.actionType == .ALL_IN && (context.handStrength == .air || context.handStrength == .weakPair) && context.equity < 0.35 && context.phase == "preflop" {
            // 放宽限制，即使是 short stack，空气全押也是不好的
            return .badCall // 借用 badCall 标签，展示红色警告
        }
        
        // 规则1.6：乱跟注 (翻前拿很差的牌跟注加注/全押)
        if context.actionType == .CALL && (context.handStrength == .air || context.handStrength == .weakPair) && context.equity < 0.35 && context.phase == "preflop" {
            // 如果只有非常小的底池赔率（比如平跟盲注），可以容忍
            if context.potOdds > 0.15 {
                return .badCall
            }
        }
        
        // 规则2：强牌被动 (击中好牌但只过牌或平跟)
        if context.handStrength.isStrong || context.handStrength == .nuts {
            if context.actionType == .CHECK || context.actionType == .CALL {
                // 如果是翻牌或转牌阶段，或者在翻前拿到了极强牌，只平跟也是被动
                // 特例：如果是 preflop，我们允许 .strong（比如 QQ/JJ）平跟（有时是合理的防守），但如果是 .nuts (KK/AA)，平跟就算被动
                if context.phase == "flop" || context.phase == "turn" || (context.phase == "preflop" && context.handStrength == .nuts) {
                    return .passiveValue
                }
            }
        }
        
        // 规则3：坚果投入太小 (拿到超强牌，主动投入但投入额不足总分40%)
        if context.handStrength == .nuts && (context.actionType == .BET || context.actionType == .RAISE) {
            if context.betRatio > 0 && context.betRatio < 0.4 {
                return .smallBetNuts
            }
        }
        
        // 规则4：标准持续投入 (翻前激进者，在翻牌圈主动投入)
        if context.phase == "flop" && context.isPreflopAggressor && context.actionType == .BET {
            if context.betRatio >= 0.33 && context.betRatio <= 0.75 {
                return .standardCBet
            }
        }
        
        // 规则5：好弃牌 (胜率极低时面对投入果断弃牌)
        if context.actionType == .FOLD {
            if context.equity < 0.25 {
                return .goodFold
            }
        }
        
        // 规则6：诈唬时机 (河牌空气牌，投入较大)
        if context.phase == "river" && context.handStrength == .air {
            if context.actionType == .BET || context.actionType == .RAISE {
                if context.betRatio >= 0.6 {
                    return .bluffOpportunity
                }
            }
        }
        
        // 规则7：价值下注 (有强牌主动下注)
        if context.handStrength.isStrong && (context.actionType == .BET || context.actionType == .RAISE) {
            if context.betRatio >= 0.4 {
                return .goodValueBet
            }
        }
        
        // 规则8：松的跟注 (胜率不高但非空气牌时仍跟注较多)
        if context.actionType == .CALL && context.handStrength == .weakPair {
            if context.potOdds > 0.4 {
                return .looseCall
            }
        }
        
        // 规则9：翻前好的加注 (翻前用强牌加注)
        if context.phase == "preflop" && (context.handStrength.isStrong || context.handStrength == .nuts) && context.actionType == .RAISE {
            return .goodRaise
        }
        
        // 规则10：错误弃牌 (放弃强牌或有很好赔率的听牌)
        if context.actionType == .FOLD {
            if context.handStrength.isStrong || context.handStrength == .nuts {
                return .badFold
            } else if context.handStrength == .draw && context.equity > context.potOdds + 0.1 {
                return .badFold
            }
        }
        
        return .none
    }
    
    // 简化的评估辅助方法，用于无详细AI计算数据的场景（牌谱回放时）
    // 依赖于牌面发牌和摊牌结果推测
    func evaluateFromHistory(action: HandAction, round: BettingRoundRecord, playerHoleCards: [String]?, isHugeLoss: Bool = false, history: HandHistory? = nil) -> CoachAdvice {
        // 在没有完整蒙特卡洛胜率和对手范围计算的纯前端回放中，我们做一些简化推测
        
        let phase = round.phase
        let act = action.action
        
        // 如果我们不知道玩家底牌，无法评价
        guard let holeCardsStr = playerHoleCards, holeCardsStr.count == 2 else {
            return CoachAdvice(tag: .none, comment: "")
        }
        
        // 尝试解析字符串底牌为Card对象 (如 "A♠")
        let hCards = holeCardsStr.compactMap { parseCardString($0) }
        guard hCards.count == 2 else { return CoachAdvice(tag: .none, comment: "") }
        
        let commCards = round.communityCards.compactMap { parseCardString($0) }
        
        // 粗略评估牌力
        let strength = guessHandStrength(holeCards: hCards, communityCards: commCards)
        
        // 计算粗略的 betRatio
        // 由于我们在回放时没有实时的 pot 大小，只能大概估算（这需要从上一轮和当前轮动作累加得出）
        // 这里做一个非常粗略的简化，实际应用中可以传入准确的pot大小
        let estimatedPot = max(100, action.totalInvested * 2) // 极大简化
        let betRatio = Float(action.amount) / Float(estimatedPot)
        
        // --- 特殊处理无脑 All-in 的情况 ---
        // 在牌谱中，如果遇到玩家在翻牌前无脑 All-in（比如总分只有几十，直接推几千），或者拿着很差的牌（比如空气/弱对）硬接全押
        // 为了让教练系统能在这种情况亮起灯泡，我们放宽某些条件的阈值。
        
        var equity = guessEquity(strength: strength)
        // 如果翻牌前没发公牌，拿很差的牌全押/跟注全押，强行调低胜率让他触发 badCall 或 类似警告
        if commCards.isEmpty && (strength == .air || strength == .weakPair) && (act == .ALL_IN || act == .CALL) {
            // 只有当这是很大的跟注或加注时才惩罚，小盲注平跟不惩罚
            if action.amount > (history?.bbAmount ?? 20) {
                equity = 0.05
            }
        }
        
        let context = ActionContext(
            handStrength: strength,
            actionType: act,
            betRatio: betRatio,
            potOdds: 0.3, // 简化默认值
            equity: equity,
            isPreflopAggressor: false, // 简化，除非我们遍历整个 actionSequence
            phase: phase
        )
        
        var resultTag = evaluate(context: context)
        
        // 兜底逻辑：如果玩家拿着纯空气牌（如 72o, 94o）在翻前直接 All-in 或跟注 All-in，这绝对是个负 EV 的操作，强行打上 badCall 标签
        if commCards.isEmpty && (strength == .air || strength == .weakPair) && (act == .ALL_IN || act == .CALL) {
            if action.amount > (history?.bbAmount ?? 20) * 2 {
                resultTag = .badCall
            }
        }
        
        print("💡 Coach Engine Evaluated Action: \(action.playerId) \(act) amount:\(action.amount) phase:\(phase)")
        print("   HoleCards: \(hCards.map { "\($0.rank)\($0.suit)" }), CommCards: \(commCards.map { "\($0.rank)\($0.suit)" })")
        print("   Strength: \(strength), Equity: \(equity), BetRatio: \(betRatio)")
        print("   Result Tag: \(resultTag)")
        
        // 针对输大钱的“Bad Beat”兜底慰藉
        if isHugeLoss && resultTag == .none && strength.isStrong && phase == "river" {
            // 如果玩家在河牌输了很多积分，且他的牌确实是一手好牌（如顶对/两对+），
            // 且之前的规则没给他打标签，我们给他一个 Bad Beat 安慰。
            resultTag = .badBeat
        }
        
        var coachContext: CoachContext? = nil
        if let hist = history {
            let bb = Double(max(1, hist.bbAmount))
            let pState = hist.players.first(where: { $0.playerId == action.playerId })
            let stackBB = Double(pState?.initialChips ?? 1000) / bb
            let pos = pState?.position ?? String(localized: "未知")
            let remain = hist.players.count
            coachContext = CoachContext(position: pos, stackBB: stackBB, playersRemaining: remain)
        }
        
        let comment = CoachCommentary.generateComment(for: resultTag, context: coachContext)
        return CoachAdvice(tag: resultTag, comment: comment)
    }
    
    // 工具方法：根据两张底牌和公牌，计算最终牌型的名字 (如 "两对", "同花")
    func getHandName(holeCards: [String], communityCards: [String]) -> String? {
        let hCards = holeCards.compactMap { parseCardString($0) }
        let cCards = communityCards.compactMap { parseCardString($0) }
        guard hCards.count == 2 else { return nil }
        
        let combo = HandEvaluator.shared.evaluateBestHand(holeCards: hCards, communityCards: cCards)
        return combo.handType.displayName
    }
    
    private func parseCardString(_ str: String) -> Card? {
        guard str.count == 2 else { return nil }
        let rankChar = String(str.first!)
        let suitChar = String(str.last!)
        
        var rank: Card.Rank?
        switch rankChar {
        case "2": rank = .two; case "3": rank = .three; case "4": rank = .four
        case "5": rank = .five; case "6": rank = .six; case "7": rank = .seven
        case "8": rank = .eight; case "9": rank = .nine; case "T": rank = .ten
        case "J": rank = .jack; case "Q": rank = .queen; case "K": rank = .king
        case "A": rank = .ace
        default: break
        }
        
        var suit: Card.Suit?
        switch suitChar {
        case "♣": suit = .clubs; case "♦": suit = .diamonds
        case "♥": suit = .hearts; case "♠": suit = .spades
        default: break
        }
        
        if let r = rank, let s = suit {
            return Card(rank: r, suit: s)
        }
        return nil
    }
    
    private func guessHandStrength(holeCards: [Card], communityCards: [Card]) -> HandStrengthCategory {
        if communityCards.isEmpty {
            // 翻前简单判断
            let r1 = holeCards[0].numericValue
            let r2 = holeCards[1].numericValue
            if r1 == r2 {
                return r1 >= 10 ? (r1 >= 13 ? .nuts : .strong) : .weakPair
            }
            if r1 >= 10 && r2 >= 10 {
                // 两张大于等于10的高张，算作有一定潜力
                return .draw
            }
            if (r1 >= 10 || r2 >= 10) && holeCards[0].suit == holeCards[1].suit {
                // 单高张同色，也算有一定的 draw 潜力，不完全是空气
                return .draw
            }
            // 否则就当空气处理（容易被教练判定为乱玩）
            return .air
        }
        
        let combo = HandEvaluator.shared.evaluateBestHand(holeCards: holeCards, communityCards: communityCards)
        
        switch combo.handType {
        case .highCard:
            // 检查是否有听牌潜力
            let all = holeCards + communityCards
            let suits = Dictionary(grouping: all, by: { $0.suit }).mapValues { $0.count }
            if suits.values.contains(where: { $0 == 4 }) {
                return .draw
            }
            return .air
        case .onePair:
            // 检查是不是顶对
            let boardRanks = communityCards.map { $0.numericValue }.sorted(by: >)
            let highestBoardRank = boardRanks.first ?? 0
            let myRanks = holeCards.map { $0.numericValue }
            
            if myRanks.contains(highestBoardRank) {
                return .topPair
            }
            
            // 口袋对子是否大于牌面最大牌
            if holeCards[0].numericValue == holeCards[1].numericValue && holeCards[0].numericValue > highestBoardRank {
                return .topPair // Overpair
            }
            
            return .weakPair
        case .twoPair, .threeOfAKind:
            return .strong
        case .straight, .flush, .fullHouse, .fourOfAKind, .straightFlush, .royalFlush:
            return .nuts
        }
    }
    
    private func guessEquity(strength: HandStrengthCategory) -> Float {
        switch strength {
        case .air: return 0.1
        case .draw: return 0.25
        case .weakPair: return 0.35
        case .topPair: return 0.65
        case .strong: return 0.85
        case .nuts: return 0.95
        }
    }
}

// MARK: - 评语库与生成器
class CoachCommentary {
    static let comments: [PlayTag: [String]] = [
        .badCall: [
            "在这个回报率下跟注或全押是不划算的。长期来看这是负EV的决定。\nCalling or shoving with these pot odds is unprofitable. It's a negative EV decision in the long run.",
            "追牌需要考虑回报率。这里的赔率不足以支撑你的听牌或弱牌，果断弃牌才是正解。\nPot odds matter when drawing. The odds here don't justify calling with a draw or weak hand; folding is the right play.",
            "手牌胜率太低了，这种回报率下强行入池就是在白白送积分。\nYour hand equity is too low. Forcing a call with these pot odds is just giving away chips."
        ],
        .passiveValue: [
            "你击中了强牌，但过于保守。尝试加注来保护你的总分并实现价值最大化。\nYou hit a strong hand but played too passively. Try raising to protect your hand and maximize value.",
            "拿到好牌就要主动出击！过牌跟注容易让听牌便宜过关。\nTake the initiative with a good hand! Check-calling often lets draws see cheap cards.",
            "这里可以考虑打得更有侵略性一些，不要错失榨取价值的机会。\nConsider playing more aggressively here to avoid missing out on extracting value."
        ],
        .smallBetNuts: [
            "强牌投入偏小！这个面上对手很可能愿意跟更多积分。\nSizing is too small with a very strong hand. On this board, opponents may call a larger sizing.",
            "投入偏小，下次可以尝试接近满池或3/4池的投入尺度来提升收益。\nSizing is too small. Consider a larger chip-in size (pot or 3/4 pot) next time to improve results.",
            "你拿着非常强的牌，不必害怕加大投入尺度；小优势长期累积会很可观。\nYou hold a monster. Don’t be afraid to use a larger sizing—small edges add up over time."
        ],
        .standardCBet: [
            "翻牌面的持续施压非常标准，给对手施加了足够的压力。\nStandard continuation play on the flop, applying good pressure to the opponent.",
            "漂亮的持续施压！利用翻前的主动权拿下了总分。\nNice continuation play—using preflop initiative to take down the pot.",
            "持续施压的尺度掌握得很好，保持了对总分的控制权。\nGood sizing on your continuation play, maintaining control of the pot."
        ],
        .goodFold: [
            "好弃牌！懂得在落后时及时止损是赢家的必备素质。\nGood fold! Knowing when to cut losses while behind is essential for a winning player.",
            "非常理智的弃牌，这个面的赔率已经不适合继续玩下去了。\nVery sensible fold. The pot odds on this board no longer justify continuing.",
            "避开了一个潜在的陷阱，省下的积分同样是一种优势。\nAvoided a potential trap. Chips saved are chips gained."
        ],
        .bluffOpportunity: [
            "勇敢的诈唬！在合适的时机施加极大的压力，逼迫对手弃掉中等牌力的牌。\nBrave bluff! Applying extreme pressure at the right time to force folds from medium-strength hands.",
            "很好的极化策略：要么是极强牌，要么是诈唬，让对手非常难受。\nGreat polarized sizing—either very strong or a bluff—putting the opponent in a very tough spot."
        ],
        .tooTight: [
            "打得太紧了，好牌也要敢于出手积累优势。\nPlaying too tight. You must be willing to build the pot with strong hands.",
            "在这个位置放弃强牌有点可惜了。\nIt's a bit of a pity to fold such a strong hand in this position."
        ],
        .badBeat: [
            "这就是扑克，你做出了正确的决定，但运气站在了对手那边。\nThat's poker. You made the right decision, but luck favored your opponent.",
            "Bad Beat！你的牌明明领先，却在河牌被反超，不要让情绪影响下一手牌。\nBad Beat! You were clearly ahead but got outdrawn on the river. Don't let it tilt your next hand.",
            "别灰心，从长期概率来看，只要坚持做正EV的决策，你终将获胜。\nDon't be discouraged. In the long run, consistently making +EV decisions will make you a winner."
        ],
        .goodValueBet: [
            "教科书般的价值下注！拿到好牌就该这样榨取对手。\nTextbook value bet! This is exactly how you extract chips with a strong hand.",
            "很棒的尺度，这种下注能让比你弱的牌心甘情愿买单。\nGreat sizing. This bet gets weaker hands to pay you off willingly."
        ],
        .looseCall: [
            "这个跟注太松了，手牌偏弱而且赔率也不合适。\nThis call is too loose. Your hand is weak and the pot odds don't justify it.",
            "拿着边缘牌强行跟注，很容易在后续发牌中陷入被动。\nForcing a call with a marginal hand often leads to difficult situations on later streets."
        ],
        .goodRaise: [
            "非常有侵略性的加注，既能建立底池，又能拿回主动权。\nVery aggressive raise. It builds the pot and takes the initiative.",
            "拿到好牌果断加注，这是德州扑克赢利的核心。\nRaising solidly with premium hands is the core of winning poker."
        ],
        .badFold: [
            "太保守了！你放弃了非常有胜率的一手牌。\nToo conservative! You folded a hand with a very high chance of winning.",
            "即使面对压力，这手牌的赔率也足够你继续玩下去，弃牌属于负EV。\nEven facing pressure, the pot odds justified continuing. Folding here is negative EV."
        ]
    ]
    
    static func generateComment(for tag: PlayTag, context: CoachContext?) -> String {
        if tag == .none { return "" }
        
        let dualComment = comments[tag]?.randomElement() ?? ""
        
        guard let ctx = context else { return dualComment }
        
        let isShortStack = ctx.stackBB <= 10
        let isBubble = ctx.playersRemaining == 3
        let isHU = ctx.playersRemaining == 2
        
        var icmMsg = ""
        
        if isBubble {
            icmMsg = "【ICM提示】目前正处于SNG 策略模拟器的泡沫期(3人)，积分的生存价值远大于积分的赢取价值，建议打得更紧一些，尤其是面对大积分玩家时。\n[ICM] You are on the SNG Strategy Simulator bubble (3 players). Survival is key. Tighten up, especially against the chip leader."
        } else if isHU {
            icmMsg = "【单挑提示】进入Heads-Up阶段，牌值大幅缩水，任何对子或两张高牌都值得激进游戏。\n[Heads-Up] In HU play, hand values shift. Any pair or two broadway cards should be played aggressively."
        } else if isShortStack {
            let bbStr = String(format: "%.1f", ctx.stackBB)
            icmMsg = "【短筹提示】你目前的积分深度(\(bbStr)BB)已进入All-in/Fold阶段，寻找机会直接全押而不是平跟。\n[Short Stack] With \(bbStr) BBs, you are in the All-in/Fold zone. Look for shove spots instead of calling."
        } else if ctx.playersRemaining <= 6 {
            let pos = ctx.position
            icmMsg = "【位置提示】你在 \(pos) 位置。在 SNG 策略模拟器前期，深积分可以多打位置优势，避免在不利位置过度投入。\n[Position] You are in the \(pos) position. In early SNG Strategy Simulator stages, leverage position and avoid inflating total points out of position."
        }
        
        if !icmMsg.isEmpty {
            return "\(dualComment)\n\n\(icmMsg)"
        }
        
        return dualComment
    }
    
    static func getLocalizedComment(from dualComment: String) -> String {
        let isChinese = Locale.current.identifier.hasPrefix("zh") || (Bundle.main.preferredLocalizations.first?.hasPrefix("zh") == true)
        
        let blocks = dualComment.components(separatedBy: "\n\n")
        var localizedBlocks: [String] = []
        
        for block in blocks {
            let parts = block.components(separatedBy: "\n")
            if parts.count >= 2 {
                if isChinese {
                    localizedBlocks.append(parts[0])
                } else {
                    localizedBlocks.append(parts.dropFirst().joined(separator: "\n"))
                }
            } else {
                localizedBlocks.append(block)
            }
        }
        
        return localizedBlocks.joined(separator: "\n\n")
    }
    
    static func getColor(for tag: PlayTag) -> String {
        switch tag {
        case .goodFold, .standardCBet, .bluffOpportunity, .goodValueBet, .goodRaise:
            return "green"
        case .badCall, .tooTight, .looseCall, .badFold:
            return "red"
        case .passiveValue, .smallBetNuts:
            return "orange"
        case .badBeat:
            return "gray"
        default:
            return "gray"
        }
    }
}
