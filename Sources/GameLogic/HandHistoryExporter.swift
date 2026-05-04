import Foundation

// MARK: - 牌谱导出模块
// Hand History Exporter for Texas Hold'em SNG

/// 动作类型枚举
enum HandActionType: String, Codable {
    case POST_ANTE = "POST_ANTE"
    case POST_SB = "POST_SB"
    case POST_BB = "POST_BB"
    case FOLD = "FOLD"
    case CHECK = "CHECK"
    case CALL = "CALL"
    case BET = "BET"
    case RAISE = "RAISE"
    case ALL_IN = "ALL_IN"
    case WIN = "WIN"
}

/// 单个行动记录
struct HandAction: Codable {
    let playerId: String
    let seat: Int
    let action: HandActionType
    let amount: Int           // 动作金额（差额）
    let totalInvested: Int     // 该玩家本局总投入
    var coachAdvice: CoachAdvice?
}

/// 投入轮记录
struct BettingRoundRecord: Codable {
    var phase: String         // preflop, flop, turn, river
    var round: Int
    var communityCards: [String]
    var actions: [HandAction]
}

/// 玩家初始状态
struct PlayerInitialState: Codable {
    let playerId: String
    let playerName: String?
    let seat: Int
    let initialChips: Int
    var holeCards: [String]?
    let position: String
    var isHuman: Bool?
}

/// 彩池记录
struct PotRecord: Codable {
    var amount: Int
    var eligiblePlayers: [String]  // 有资格竞争该池的玩家
    var winners: [String]
    var winAmount: Int
}

/// 边池记录
struct SidePotRecord: Codable {
    var amount: Int
    var eligiblePlayers: [String]
    var winners: [String]
    var winAmount: Int
}

/// 单个摊牌玩家记录
struct ShowdownPlayerRecord: Codable {
    let playerId: String
    let holeCards: [String]
    let handType: String
    let handName: String
    let bestHand: [String]
}

/// 结算结果
struct HandResult: Codable {
    let winnerId: String?
    let totalWin: Int
    let chipsAfter: [String: Int]  // 所有玩家局后积分 {playerId: chips}
}

/// 元数据
struct HandMetadata: Codable {
    let exportTimestamp: String
    let handDurationSeconds: Int
    let gameVersion: String
}

/// 完整牌谱数据结构
struct HandHistory: Codable, Identifiable {
    var id: String { handId }
    var handId: String
    var practiceType: String? // e.g. "6人 SNG 练习"
    var practiceFeedback: String? // 保存专项练习时的教练评语
    var sngId: String
    var timestamp: String
    var blindLevel: Int
    var sbAmount: Int
    var bbAmount: Int
    var anteAmount: Int
    var buttonPosition: Int
    var currency: String
    var players: [PlayerInitialState]
    var actionSequence: [BettingRoundRecord]
    var pots: PotsRecord?
    var showdown: [ShowdownPlayerRecord]?
    var result: HandResult?
    var metadata: HandMetadata?
    
    struct PotsRecord: Codable {
        var mainPot: PotRecord?
        var sidePots: [SidePotRecord]
    }
}

struct PotOutcome {
    let amount: Int
    let eligiblePlayerIds: [UUID]
    let winnerIds: [UUID]
}

// MARK: - 牌谱导出器
final class HandHistoryExporter {
    
    static let shared = HandHistoryExporter()
    
    private(set) var currentHandHistory: HandHistory?
    private var savedHistoryForCoach: HandHistory?
    private var currentRoundActions: [HandAction] = []
    private var currentRound: Int = 0
    private var handStartTime: Date?
    private var playerInitialChips: [String: Int] = [:]  // 记录玩家初始积分
    private var humanPlayerIds: Set<String> = []
    private var isRecordingEnabled: Bool = true
    
    private let exportDirectory: URL
    
    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        exportDirectory = documentsPath.appendingPathComponent("HandHistories", isDirectory: true)
        try? FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
    }
    
    func setRecordingEnabled(_ enabled: Bool) {
        isRecordingEnabled = enabled
    }
    
    // MARK: - 事件监听
    
    /// 开始记录新手牌
    func startNewHand(handId: String, sngId: String, practiceType: String?, blindLevel: Int, sb: Int, bb: Int, ante: Int, buttonPosition: Int, players: [Player]) {
        guard isRecordingEnabled else { return }
        // 如果有未导出的历史，先导出
        if currentHandHistory != nil {
            _ = exportAndReset()
        }
        
        handStartTime = Date()
        currentRound = 0
        currentRoundActions = []
        playerInitialChips = [:]
        humanPlayerIds = Set(players.filter { $0.isHuman }.map { $0.id.uuidString })
        
        let playerStates = players
            .sorted { $0.seatId < $1.seatId }
            .map { player in
            playerInitialChips[player.id.uuidString] = player.chips
            return PlayerInitialState(
                playerId: player.id.uuidString,
                playerName: player.name,
                seat: player.seatId,
                initialChips: player.chips,
                holeCards: nil,
                position: player.position.displayName,
                isHuman: player.isHuman
            )
        }
        
        currentHandHistory = HandHistory(
            handId: handId,
            practiceType: practiceType,
            practiceFeedback: nil,
            sngId: sngId,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            blindLevel: blindLevel,
            sbAmount: sb,
            bbAmount: bb,
            anteAmount: ante,
            buttonPosition: buttonPosition,
            currency: "CHIP",
            players: playerStates,
            actionSequence: [],
            pots: nil,
            showdown: nil,
            result: nil,
            metadata: nil
        )
        
    }
    
    /// 发手牌时更新玩家手牌
func updateHoleCards(players: [Player]) {
        guard isRecordingEnabled else { return }
        guard var history = currentHandHistory else { return }
        
        for player in players {
            if let holeCards = player.holeCards,
               let historyIndex = history.players.firstIndex(where: { $0.playerId == player.id.uuidString }) {
                let cardStrings = holeCards.map { "\($0.rank.symbol)\($0.suit.symbol)" }
                history.players[historyIndex].holeCards = cardStrings
            }
        }
        
        currentHandHistory = history
    }

    /// 记录投入轮开始
    func startBettingRound(phase: GamePhase, communityCards: [Card]) {
        guard isRecordingEnabled else { return }
        currentRound += 1
        currentRoundActions = []
        
        let phaseName: String
        switch phase {
        case .preflop: phaseName = "preflop"
        case .flop: phaseName = "flop"
        case .turn: phaseName = "turn"
        case .river: phaseName = "river"
        default: phaseName = "unknown"
        }
        
        let cardStrings = communityCards.map { "\($0.rank.symbol)\($0.suit.symbol)" }
        let roundRecord = BettingRoundRecord(phase: phaseName, round: currentRound, communityCards: cardStrings, actions: [])
        currentHandHistory?.actionSequence.append(roundRecord)
        
    }
    
    /// 记录玩家动作
    func recordAction(playerId: String, seat: Int, action: PlayerAction, totalInvested: Int) {
        guard isRecordingEnabled else { return }
        let actionType: HandActionType
        var amount: Int = 0
        
        switch action {
        case .fold:
            actionType = .FOLD
        case .check:
            actionType = .CHECK
        case .call(let callAmount):
            actionType = .CALL
            amount = callAmount
        case .bet(let betAmount):
            actionType = .BET
            amount = betAmount
        case .raise(let raiseAmount):
            actionType = .RAISE
            amount = raiseAmount
        case .allIn(let allInAmount):
            actionType = .ALL_IN
            amount = allInAmount
        }
        
        let handAction = HandAction(
            playerId: playerId,
            seat: seat,
            action: actionType,
            amount: amount,
            totalInvested: totalInvested,
            coachAdvice: nil
        )
        
        currentRoundActions.append(handAction)
        
        // 更新当前轮的记录
        if var sequence = currentHandHistory?.actionSequence, !sequence.isEmpty {
            sequence[sequence.count - 1].actions = currentRoundActions
            currentHandHistory?.actionSequence = sequence
        }
        
    }
    
    func recordAnte(playerId: String, seat: Int, amount: Int, totalInvested: Int) {
        guard isRecordingEnabled else { return }
        let handAction = HandAction(
            playerId: playerId,
            seat: seat,
            action: .POST_ANTE,
            amount: amount,
            totalInvested: totalInvested,
            coachAdvice: nil
        )
        currentRoundActions.append(handAction)
        
        if var sequence = currentHandHistory?.actionSequence, !sequence.isEmpty {
            sequence[sequence.count - 1].actions = currentRoundActions
            currentHandHistory?.actionSequence = sequence
        }
    }
    
    /// 记录小底分
    func recordSmallBlind(playerId: String, seat: Int, amount: Int, totalInvested: Int) {
        guard isRecordingEnabled else { return }
        let handAction = HandAction(
            playerId: playerId,
            seat: seat,
            action: .POST_SB,
            amount: amount,
            totalInvested: totalInvested,
            coachAdvice: nil
        )
        currentRoundActions.append(handAction)
        
        // 更新当前轮
        if var sequence = currentHandHistory?.actionSequence, !sequence.isEmpty {
            sequence[sequence.count - 1].actions = currentRoundActions
            currentHandHistory?.actionSequence = sequence
        }
    }
    
    /// 记录大底分
    func recordBigBlind(playerId: String, seat: Int, amount: Int, totalInvested: Int) {
        guard isRecordingEnabled else { return }
        let handAction = HandAction(
            playerId: playerId,
            seat: seat,
            action: .POST_BB,
            amount: amount,
            totalInvested: totalInvested,
            coachAdvice: nil
        )
        currentRoundActions.append(handAction)
        
        // 更新当前轮
        if var sequence = currentHandHistory?.actionSequence, !sequence.isEmpty {
            sequence[sequence.count - 1].actions = currentRoundActions
            currentHandHistory?.actionSequence = sequence
        }
    }
    
    // MARK: - 摊牌与结算
    
    /// 记录摊牌信息 - 包含所有亮牌玩家
    func recordShowdown(
        showdownPlayers: [(playerId: UUID, holeCards: [Card], hand: CardCombination)],
        players: [Player],
        winners: [UUID],
        mainPot: Int,
        sidePots: [Int]
    ) {
        guard var history = currentHandHistory else { return }
        
        // 构建所有摊牌玩家的记录
        var showdownRecords: [ShowdownPlayerRecord] = []
        for info in showdownPlayers {
            let holeCardStrings = info.holeCards.map { "\($0.rank.symbol)\($0.suit.symbol)" }
            let bestHandStrings = info.hand.cards.map { "\($0.rank.symbol)\($0.suit.symbol)" }
            
            let record = ShowdownPlayerRecord(
                playerId: info.playerId.uuidString,
                holeCards: holeCardStrings,
                handType: String(describing: info.hand.handType).uppercased().replacingOccurrences(of: " ", with: "_"),
                handName: info.hand.handType.displayName,
                bestHand: bestHandStrings
            )
            showdownRecords.append(record)
        }
        
        // 确定有资格参与主池的玩家（未弃牌且未全押出局的）
        let eligibleForMain = players.filter { !$0.isFolded }.map { $0.id.uuidString }
        
        // 主池记录
        let mainPotRecord = PotRecord(
            amount: mainPot,
            eligiblePlayers: eligibleForMain,
            winners: winners.map { $0.uuidString },
            winAmount: winners.isEmpty ? 0 : mainPot / winners.count
        )
        
        // 边池记录（仅当存在时才记录）
        var sidePotRecords: [SidePotRecord] = []
        for (index, sidePotAmount) in sidePots.enumerated() {
            // 有资格参与边池的玩家是那些投入超过主池最高押注的玩家
            let eligibleForSide = players.filter { $0.currentBet > 0 || $0.chips == 0 }.map { $0.id.uuidString }
            sidePotRecords.append(SidePotRecord(
                amount: sidePotAmount,
                eligiblePlayers: eligibleForSide,
                winners: winners.map { $0.uuidString },
                winAmount: winners.isEmpty ? 0 : sidePotAmount / winners.count
            ))
        }
        
        history.pots = HandHistory.PotsRecord(mainPot: mainPotRecord, sidePots: sidePotRecords)
        history.showdown = showdownRecords
        
        // 计算各玩家局后积分
        // 注意：players 参数已经是摊牌后的状态，player.chips 已经是最终积分
        var chipsAfter: [String: Int] = [:]
        for player in players {
            let playerIdStr = player.id.uuidString
            // 直接使用玩家当前积分（已经在showdown中更新）
            chipsAfter[playerIdStr] = player.chips
        }
        
        let winnerIdStr = winners.first?.uuidString
        let totalWin = winners.isEmpty ? 0 : mainPot / winners.count
        
        history.result = HandResult(
            winnerId: winnerIdStr,
            totalWin: totalWin,
            chipsAfter: chipsAfter
        )
        
        currentHandHistory = history
        
    }

    func recordPracticeHandEnd(playersAfter: [Player], practiceFeedback: String? = nil) {
        guard isRecordingEnabled else { return }
        guard var history = currentHandHistory else { return }
        
        history.practiceFeedback = practiceFeedback
        
        var chipsAfter: [String: Int] = [:]
        for player in playersAfter {
            chipsAfter[player.id.uuidString] = player.chips
        }
        
        history.result = HandResult(
            winnerId: nil,
            totalWin: 0,
            chipsAfter: chipsAfter
        )
        
        currentHandHistory = history
    }

    func recordHandEnd(
        showdownPlayers: [(playerId: UUID, holeCards: [Card], hand: CardCombination)],
        potOutcomes: [PotOutcome],
        payouts: [UUID: Int],
        playersAfter: [Player]
    ) {
        guard isRecordingEnabled else { return }
        guard var history = currentHandHistory else { return }

        var showdownRecords: [ShowdownPlayerRecord] = []
        for info in showdownPlayers {
            let holeCardStrings = info.holeCards.map { "\($0.rank.symbol)\($0.suit.symbol)" }
            let bestHandStrings = info.hand.cards.map { "\($0.rank.symbol)\($0.suit.symbol)" }
            let record = ShowdownPlayerRecord(
                playerId: info.playerId.uuidString,
                holeCards: holeCardStrings,
                handType: String(describing: info.hand.handType).uppercased().replacingOccurrences(of: " ", with: "_"),
                handName: info.hand.handType.displayName,
                bestHand: bestHandStrings
            )
            showdownRecords.append(record)
        }

        var mainPot: PotRecord?
        var sidePots: [SidePotRecord] = []
        for (idx, outcome) in potOutcomes.enumerated() {
            if idx == 0 {
                mainPot = PotRecord(
                    amount: outcome.amount,
                    eligiblePlayers: outcome.eligiblePlayerIds.map { $0.uuidString },
                    winners: outcome.winnerIds.map { $0.uuidString },
                    winAmount: outcome.winnerIds.isEmpty ? 0 : outcome.amount / outcome.winnerIds.count
                )
            } else {
                sidePots.append(SidePotRecord(
                    amount: outcome.amount,
                    eligiblePlayers: outcome.eligiblePlayerIds.map { $0.uuidString },
                    winners: outcome.winnerIds.map { $0.uuidString },
                    winAmount: outcome.winnerIds.isEmpty ? 0 : outcome.amount / outcome.winnerIds.count
                ))
            }
        }

        history.pots = HandHistory.PotsRecord(mainPot: mainPot, sidePots: sidePots)
        history.showdown = showdownRecords.isEmpty ? nil : showdownRecords

        var chipsAfter: [String: Int] = [:]
        for player in playersAfter {
            chipsAfter[player.id.uuidString] = player.chips
        }

        let paidPlayers = payouts.filter { $0.value > 0 }
        let winnerId: String? = paidPlayers.count == 1 ? paidPlayers.first?.key.uuidString : nil
        let totalWin: Int
        if let winnerIdStr = winnerId, let uuid = UUID(uuidString: winnerIdStr) {
            totalWin = payouts[uuid] ?? 0
        } else {
            totalWin = paidPlayers.values.reduce(0, +)
        }

        history.result = HandResult(
            winnerId: winnerId,
            totalWin: totalWin,
            chipsAfter: chipsAfter
        )

        currentHandHistory = history
    }
    
    /// 导出牌谱到文件
    func exportHandHistory() -> URL? {
        guard var history = currentHandHistory else {
            return nil
        }
        
        attachCoachAdviceIfNeeded(history: &history)
        
        // 更新当前持有的 history 以便外部可以访问 coachAdvice
        currentHandHistory = history
        
        // 计算对局时长
        let duration = handStartTime.map { Int(Date().timeIntervalSince($0)) } ?? 0
        
        // 更新元数据
        history.metadata = HandMetadata(
            exportTimestamp: ISO8601DateFormatter().string(from: Date()),
            handDurationSeconds: duration,
            gameVersion: "1.0.0"
        )
        
        // 生成文件名: handhistory_[sng_id]_[hand_id].json
        let sanitizedHandId = history.handId.replacingOccurrences(of: "-", with: "_")
        let fileName = "handhistory_\(history.sngId)_\(sanitizedHandId).json"
        let fileURL = exportDirectory.appendingPathComponent(fileName)
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(history)
            try jsonData.write(to: fileURL)
            
            return fileURL
        } catch {
            return nil
        }
    }
    
    func saveCurrentHand() {
        guard isRecordingEnabled else { return }
        guard var history = currentHandHistory else { return }
        attachCoachAdviceIfNeeded(history: &history)
        currentHandHistory = history
        self.savedHistoryForCoach = history
        _ = exportHandHistory()
    }
    
    /// 导出并重置
    func exportAndReset() -> URL? {
        saveCurrentHand()
        
        // 我们不再重复调用 exportHandHistory()，因为 saveCurrentHand() 已经调用过一次了。
        // 不过由于历史原因，这里可以简单地返回最后生成的文件URL，如果没有就返回 nil。
        let url = exportDirectory.appendingPathComponent("handhistory_\(currentHandHistory?.sngId ?? "")_\(currentHandHistory?.handId ?? "").json") // 这里只是占位，因为实际文件名有随机数
        
        currentHandHistory = nil
        
        currentRoundActions = []
        currentRound = 0
        handStartTime = nil
        playerInitialChips = [:]
        humanPlayerIds = []
        return url
    }

    private func attachCoachAdviceIfNeeded(history: inout HandHistory) {
        // 如果 humanPlayerIds 为空，说明这是一份从 JSON 加载进来的历史牌谱，或者是早期的牌谱
        // 在牌谱回放时，我们需要用名字来判定哪些是 human
        let isReplay = humanPlayerIds.isEmpty
        
        for roundIdx in history.actionSequence.indices {
            let round = history.actionSequence[roundIdx]
            for actionIdx in round.actions.indices {
                let action = history.actionSequence[roundIdx].actions[actionIdx]
                
                let isHuman: Bool
                if isReplay {
                    // 因为这里不在 MainActor 上，无法安全访问 PlayerProfileManager.shared.profile.customName
                    // 我们放宽匹配条件：只要名字里包含“玩家”，或者ID有特征，或者直接匹配上一个本地已知玩家。
                    // 为了最大兼容老数据，如果找不到任何明显的特征，就把主视角的玩家当做人类（一般是 Seat0 或者是第一个 player）。
                    isHuman = action.playerId == "human" || action.playerId == "HUMAN" || history.players.first(where: { $0.playerId == action.playerId })?.playerName == "玩家" || history.players.first(where: { $0.playerId == action.playerId })?.isHuman == true
                } else {
                    isHuman = humanPlayerIds.contains(action.playerId)
                }
                
                if !isHuman {
                    continue
                }
                
                if action.coachAdvice != nil {
                    continue
                }
                if action.action == .POST_ANTE || action.action == .POST_SB || action.action == .POST_BB || action.action == .WIN {
                    continue
                }
                
                let pState = history.players.first(where: { $0.playerId == action.playerId })
                let initial = pState?.initialChips ?? (playerInitialChips[action.playerId] ?? 0)
                // 即使 hand 未结束（result == nil），也可以用初始筹码作为占位，以便分析动作
                let final = history.result?.chipsAfter[action.playerId] ?? initial
                let profit = final - initial
                
                // 放宽大额亏损判定：损失超过 10 个大盲即可被视为严重亏损
                let isHugeLoss = profit < -(history.bbAmount * 10)
                
                let hole = pState?.holeCards ?? history.showdown?.first(where: { $0.playerId == action.playerId })?.holeCards
                let advice = PokerCoachEngine.shared.evaluateFromHistory(
                    action: action,
                    round: round,
                    playerHoleCards: hole,
                    isHugeLoss: isHugeLoss,
                    history: history
                )
                
                print("💡 HandHistoryExporter attached advice: \(advice.tag) for action: \(action.action) amount: \(action.amount) phase: \(round.phase)")
                
                if advice.tag != .none {
                    history.actionSequence[roundIdx].actions[actionIdx].coachAdvice = advice
                }
            }
        }
    }
    
    /// 获取导出目录
    func getExportDirectory() -> URL {
        return exportDirectory
    }
    
    /// 提取当前手牌的教练点评（所有非none的建议组合）
    func getCurrentHandCoachComments() -> String? {
        // 如果 currentHandHistory 为空，尝试找一下内存里存的最后一把（比如跳过时触发了 exportAndReset）
        guard var history = currentHandHistory ?? savedHistoryForCoach else { return nil }
        
        attachCoachAdviceIfNeeded(history: &history)
        
        // 只有当 currentHandHistory 有值时才写回去，避免破坏 export 后的清理状态
        if currentHandHistory != nil {
            currentHandHistory = history
        } else {
            savedHistoryForCoach = history
        }
        
        var comments: [String] = []
        
        // **新增**：如果这是一场专项练习（存在 practiceFeedback），将它作为头条教练点评加入
        if let pf = history.practiceFeedback {
            comments.append("💡 \(String(localized: "教练点评"))\n\(String(localized: LocalizedStringResource(stringLiteral: pf)))")
        }
        
        for round in history.actionSequence {
            for action in round.actions {
                if let advice = action.coachAdvice, advice.tag != .none {
                    // 放宽过滤条件：即便是有 coachAdvice，只要是 none 就不显示。
                    // 但是因为我们之前生成了可能导致 none 的 advice，这里确保只显示真正的建议
                    let localizedComment = CoachCommentary.getLocalizedComment(from: advice.comment)
                    
                    // 获取动作阶段、玩家动作和金额等信息，让点评更有上下文
                    let phaseName = round.phase
                    let actionDesc: String
                    switch action.action {
                    case .FOLD: actionDesc = String(localized: "弃牌")
                    case .CHECK: actionDesc = String(localized: "过牌")
                    case .CALL: actionDesc = "\(String(localized: "跟注")) \(action.amount)"
                    case .BET: actionDesc = "\(String(localized: "下注")) \(action.amount)"
                    case .RAISE: actionDesc = String(format: String(localized: "加注到 %lld"), Int64(action.amount))
                    case .ALL_IN: actionDesc = "\(String(localized: "全押")) \(action.amount)"
                    default: actionDesc = ""
                    }
                    
                    if actionDesc != "" {
                        comments.append("[\(phaseName)] \(actionDesc)\n💡 \(advice.tag.localizedName)\n\(localizedComment)")
                    }
                }
            }
        }
        
        if comments.isEmpty {
            return String(localized: "这手牌打得不错，没有什么明显的问题。")
        } else {
            return comments.joined(separator: "\n\n")
        }
    }
    
    /// 获取所有牌谱文件
    func getAllHandHistoryFiles() -> [URL] {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: exportDirectory, includingPropertiesForKeys: nil)
            return files.filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
        } catch {
            return []
        }
    }
    
    /// 加载所有牌谱数据（用于主页列表）
    func loadAllHandHistories() -> [HandHistory] {
        let urls = getAllHandHistoryFiles()
        var histories: [String: HandHistory] = [:]
        let decoder = JSONDecoder()
        
        for url in urls {
            if let data = try? Data(contentsOf: url),
               let history = try? decoder.decode(HandHistory.self, from: data) {
                // 去重：如果存在多个文件保存了同一个 handId，我们只保留最新的那一个（比如包含了完整结算结果的）
                if let existing = histories[history.handId] {
                    // 如果新的包含了 result 而旧的没有，或者新的更新，则替换
                    if history.result != nil || (existing.result == nil && history.timestamp > existing.timestamp) {
                        histories[history.handId] = history
                    }
                } else {
                    histories[history.handId] = history
                }
            }
        }
        
        // 按时间倒序排列
        return Array(histories.values).sorted { $0.timestamp > $1.timestamp }
    }
}
