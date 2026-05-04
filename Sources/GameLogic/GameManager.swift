import Foundation
import Combine
import Foundation

enum PracticeMode: String {
    case sng6Max = "6人 SNG 练习"
    case hu = "1v1 HU 练习"
    case threeBet = "3Bet 练习"
    case pushFold = "Push/Fold 练习"
    case steal = "Steal 偷盲练习"
    case defend = "Defend 防守盲注"
    
    var localizedName: String {
        return String(localized: String.LocalizationValue(self.rawValue))
    }
}

@MainActor
final class GameManager: ObservableObject {

    // MARK: - Published State

    @Published private(set) var tournamentState: TournamentState
    @Published private(set) var gameState: GameState
    @Published private(set) var lastAction: PlayerAction?
    @Published private(set) var gameMessage: String = ""
    @Published var actionTimer: TimeInterval = 30.0
    @Published var isTimerRunning: Bool = false
    @Published var currentMode: PracticeMode = .sng6Max
    @Published var practiceFeedback: String?
    @Published var lastPracticeFeedback: String?
    /// 每个玩家行动后展示延迟（秒），便于观察
    @Published var displayDelaySeconds: TimeInterval = 2.0

    // MARK: - Dependencies

    private let evaluator = HandEvaluator.shared
    private let bettingManager = BettingManager.shared
    private var timerCancellable: AnyCancellable?

    // MARK: - Callbacks

    var onHandComplete: (([UUID]) -> Void)?
    var onTournamentComplete: ((UUID?) -> Void)?

    /// 标记当前手牌是否已结束（用于控制自动继续）
    @Published var isHandFinished = false
    
    /// 标记是否正在跳过当前手牌（快进）
    @Published var isFastForwarding = false
    
    /// 是否在快进结束后自动开启下一局
    @Published var shouldAutoStartNextHand = false
    
    // 防止重复提交动作的标记
    private var isProcessingAction = false

    private var didRecordHumanTournamentResult = false

    private var currentHandToken = UUID()
    private var currentAITurnToken: UUID?
    private var aiDelayTask: Task<Void, Never>?
    private var tournamentInitialTotalChips: Int = 0
    private let clockwiseSeatCycle: [Int] = [4, 5, 2, 1, 0, 3]
    
    // Replay state
    private var savedReplayGameState: GameState?
    private var savedReplayTournamentState: TournamentState?

    // MARK: - Initialization

    @MainActor
    private static func createPlayers() -> [Player] {
        let customName = PlayerProfileManager.shared.profile.customName ?? String(localized: "Player")
        return [
            Player(name: String(localized: "Jack"), seatId: 0, isHuman: false, aiDifficulty: .easy),
            Player(name: String(localized: "Rain"), seatId: 1, isHuman: false, aiDifficulty: .medium),
            Player(name: String(localized: "Coco"), seatId: 2, isHuman: false, aiDifficulty: .hard),
            Player(name: String(localized: "Zhe"), seatId: 3, isHuman: false, aiDifficulty: .medium),
            Player(name: customName, seatId: 4, isHuman: true, aiDifficulty: .medium),
            Player(name: String(localized: "Lan"), seatId: 5, isHuman: false, aiDifficulty: .loose)
        ]
    }
    
    @MainActor
    init() {
        let aiPlayers = Self.createPlayers()

        self.tournamentState = TournamentState(players: aiPlayers)
        self.tournamentInitialTotalChips = aiPlayers.reduce(0) { $0 + $1.chips }
        // 按钮初始在座位1（在TournamentState init中已设置）

        // 创建GameState，使用所有玩家
        self.gameState = GameState(players: aiPlayers)
    }

    // MARK: - Game Flow

    func startPracticeMode(_ mode: PracticeMode) {
        HandHistoryExporter.shared.setRecordingEnabled(true)
        self.replayPlaylist = []
        self.currentReplayIndex = -1
        
        self.currentMode = mode
        
        timerCancellable?.cancel()
        isTimerRunning = false
        actionTimer = 30.0
        isHandFinished = false
        currentHandToken = UUID()
        currentAITurnToken = nil
        aiDelayTask?.cancel()
        aiDelayTask = nil
        lastAction = nil
        
        if HandHistoryExporter.shared.currentHandHistory != nil {
            _ = HandHistoryExporter.shared.exportAndReset()
        }
        
        let players: [Player]
        let customName = PlayerProfileManager.shared.profile.customName ?? String(localized: "Player")
        
        if mode == .hu || mode == .threeBet {
            players = [
                Player(name: String(localized: "Coco"), chips: 2000, seatId: 2, isHuman: false, aiDifficulty: .hard),
                Player(name: customName, chips: 2000, seatId: 4, isHuman: true, aiDifficulty: .medium)
            ]
        } else {
            players = Self.createPlayers()
        }
        
        tournamentState = TournamentState(players: players)
        tournamentInitialTotalChips = players.reduce(0) { $0 + $1.chips }
        
        if mode == .hu {
            tournamentState.blindSchedule = [
                TournamentState.BlindLevel(level: 1, sb: 50, bb: 100, ante: 0, durationMinutes: 10)
            ]
        } else if mode == .threeBet || mode == .pushFold || mode == .steal || mode == .defend {
            tournamentState.blindSchedule = [
                TournamentState.BlindLevel(level: 1, sb: 10, bb: 20, ante: 0, durationMinutes: 10)
            ]
        }
        
        // Randomize button seat for 3Bet
        if mode == .threeBet {
            tournamentState.buttonSeat = Int.random(in: 0..<players.count)
        }
        
        gameState = GameState(players: players)
        tournamentState.tournamentId = UUID()
        didRecordHumanTournamentResult = false
        tournamentState.isFinished = false
        gameMessage = String(localized: "练习开始！")
        
        AIAgent.shared.resetForNewTournament()
        startNewHand()
    }
    
    func startPracticeReplay(from history: HandHistory, playlist: [HandHistory] = [], index: Int = -1) {
        self.replayPlaylist = playlist
        self.currentReplayIndex = index
        
        let mode = PracticeMode(rawValue: history.practiceType ?? "") ?? .sng6Max
        self.currentMode = mode
        
        timerCancellable?.cancel()
        isTimerRunning = false
        actionTimer = 30.0
        isHandFinished = false
        currentHandToken = UUID()
        currentAITurnToken = nil
        aiDelayTask?.cancel()
        aiDelayTask = nil
        lastAction = nil
        practiceFeedback = nil
        lastPracticeFeedback = nil
        shouldAutoStartNextHand = false
        isFastForwarding = false
        
        if HandHistoryExporter.shared.currentHandHistory != nil {
            _ = HandHistoryExporter.shared.exportAndReset()
        }
        HandHistoryExporter.shared.setRecordingEnabled(false)
        
        let customName = PlayerProfileManager.shared.profile.customName ?? String(localized: "Player")
        var players: [Player] = []
        for p in history.players {
            let isHuman = p.isHuman == true || p.playerId == "human" || p.playerId == "HUMAN" || p.playerName == "玩家" || p.playerName == customName
            let id = UUID(uuidString: p.playerId) ?? UUID()
            let name = isHuman ? customName : (p.playerName ?? "AI")
            players.append(Player(id: id, name: name, chips: p.initialChips, seatId: p.seat, isHuman: isHuman, aiDifficulty: .medium))
        }
        players.sort { $0.seatId < $1.seatId }
        
        tournamentState = TournamentState(players: players)
        tournamentInitialTotalChips = players.reduce(0) { $0 + $1.chips }
        tournamentState.tournamentId = UUID()
        didRecordHumanTournamentResult = false
        tournamentState.isFinished = false
        tournamentState.buttonSeat = history.buttonPosition
        tournamentState.currentLevel = history.blindLevel
        tournamentState.blindSchedule = [
            TournamentState.BlindLevel(level: history.blindLevel, sb: history.sbAmount, bb: history.bbAmount, ante: history.anteAmount, durationMinutes: 10)
        ]
        
        gameState = GameState(players: players, sbAmount: history.sbAmount, bbAmount: history.bbAmount, anteAmount: history.anteAmount)
        gameState.buttonPosition = history.buttonPosition
        gameState.resetForNewHand()
        gameState.deck = makeReplayDeck(for: history, playerOrder: gameState.players)
        
        calculatePositions()
        
        // Ensure phase is correct before saving the replay state
        gameState.phase = .preflop
        
        // Save the state BEFORE we post blinds/antes and deal cards
        // So that when we replay, we can restore to exactly this clean preflop state
        savedReplayGameState = gameState
        savedReplayTournamentState = tournamentState
        
        setupHandHistory()
        
        recordPhaseStartForHH(phase: .preflop)
        postAntes()
        postBlinds()
        dealHoleCards()
        updateHoleCardsForHH()
        
        gameMessage = String(localized: "发牌中...")
        startBettingRound()
    }

    // MARK: - Playlist Replay State
    var replayPlaylist: [HandHistory] = []
    var currentReplayIndex: Int = -1
    
    var isReplayingPlaylist: Bool {
        return !replayPlaylist.isEmpty && currentReplayIndex >= 0
    }
    
    func playNextInPlaylist() {
        guard !replayPlaylist.isEmpty else { return }
        if currentReplayIndex + 1 < replayPlaylist.count {
            let nextIndex = currentReplayIndex + 1
            startPracticeReplay(from: replayPlaylist[nextIndex], playlist: replayPlaylist, index: nextIndex)
        } else {
            // Restart playlist
            startPracticeReplay(from: replayPlaylist[0], playlist: replayPlaylist, index: 0)
        }
    }

    // SNG 配置保存，用于重新开始
    private var lastSngAiCount: Int = 5
    private var lastSngHumanChips: Int = 1000
    private var lastSngAiChips: Int = 1000
    private var lastSngStartingLevel: Int = 0

    func startSNGTraining(aiCount: Int, humanChips: Int, aiChips: Int, startingLevel: Int) {
        HandHistoryExporter.shared.setRecordingEnabled(true)
        self.replayPlaylist = []
        self.currentReplayIndex = -1
        
        self.currentMode = .sng6Max
        self.lastSngAiCount = aiCount
        self.lastSngHumanChips = humanChips
        self.lastSngAiChips = aiChips
        self.lastSngStartingLevel = startingLevel
        
        timerCancellable?.cancel()
        isTimerRunning = false
        actionTimer = 30.0
        isHandFinished = false
        currentHandToken = UUID()
        currentAITurnToken = nil
        aiDelayTask?.cancel()
        aiDelayTask = nil
        lastAction = nil
        
        if HandHistoryExporter.shared.currentHandHistory != nil {
            _ = HandHistoryExporter.shared.exportAndReset()
        }
        
        let customName = PlayerProfileManager.shared.profile.customName ?? String(localized: "Player")
        var players: [Player] = []
        
        let allAIs = [
            Player(name: String(localized: "Jack"), chips: aiChips, seatId: 0, isHuman: false, aiDifficulty: .easy),
            Player(name: String(localized: "Rain"), chips: aiChips, seatId: 1, isHuman: false, aiDifficulty: .medium),
            Player(name: String(localized: "Coco"), chips: aiChips, seatId: 2, isHuman: false, aiDifficulty: .hard),
            Player(name: String(localized: "Zhe"), chips: aiChips, seatId: 3, isHuman: false, aiDifficulty: .medium),
            Player(name: String(localized: "Lan"), chips: aiChips, seatId: 5, isHuman: false, aiDifficulty: .loose)
        ]
        
        for i in 0..<aiCount {
            players.append(allAIs[i])
        }
        
        players.append(Player(name: customName, chips: humanChips, seatId: 4, isHuman: true, aiDifficulty: .medium))
        
        // Sort by seatId to keep order correct
        players.sort { $0.seatId < $1.seatId }
        
        tournamentState = TournamentState(players: players)
        tournamentInitialTotalChips = players.reduce(0) { $0 + $1.chips }
        
        let schedule = TournamentState.defaultBlindSchedule
        let levelIdx = min(max(0, startingLevel), schedule.count - 1)
        tournamentState.currentLevel = schedule[levelIdx].level
        
        gameState = GameState(players: players)
        tournamentState.tournamentId = UUID()
        didRecordHumanTournamentResult = false
        tournamentState.isFinished = false
        gameMessage = String(localized: "练习开始！")
        
        AIAgent.shared.resetForNewTournament()
        startNewHand()
    }

    private func makeReplayDeck(for history: HandHistory, playerOrder: [Player]) -> Deck {
        var forced: [Card] = []
        for p in playerOrder.sorted(by: { $0.seatId < $1.seatId }) {
            if let h = history.players.first(where: { $0.seat == p.seatId })?.holeCards, h.count >= 2 {
                if let c1 = parseCard(h[0]), let c2 = parseCard(h[1]) {
                    forced.append(c1)
                    forced.append(c2)
                }
            }
        }
        
        var boardStrings: [String] = []
        for r in history.actionSequence {
            if r.communityCards.count > boardStrings.count {
                boardStrings = r.communityCards
            }
        }
        for s in boardStrings {
            if let c = parseCard(s) {
                forced.append(c)
            }
        }
        
        var deck = Deck()
        let forcedSet = Set(forced)
        deck.cards.removeAll { forcedSet.contains($0) }
        deck.cards.shuffle()
        deck.cards = forced + deck.cards
        return deck
    }
    
    private func parseCard(_ s: String) -> Card? {
        guard let r = s.first, let su = s.last else { return nil }
        
        let rank: Card.Rank?
        switch r {
        case "2": rank = .two
        case "3": rank = .three
        case "4": rank = .four
        case "5": rank = .five
        case "6": rank = .six
        case "7": rank = .seven
        case "8": rank = .eight
        case "9": rank = .nine
        case "T": rank = .ten
        case "J": rank = .jack
        case "Q": rank = .queen
        case "K": rank = .king
        case "A": rank = .ace
        default: rank = nil
        }
        
        let suit: Card.Suit?
        switch su {
        case "♣": suit = .clubs
        case "♦": suit = .diamonds
        case "♥": suit = .hearts
        case "♠": suit = .spades
        default: suit = nil
        }
        
        guard let rank, let suit else { return nil }
        return Card(rank: rank, suit: suit)
    }

    func restartTournament() {
        if currentMode == .sng6Max {
            startSNGTraining(aiCount: lastSngAiCount, humanChips: lastSngHumanChips, aiChips: lastSngAiChips, startingLevel: lastSngStartingLevel)
        } else {
            startPracticeMode(currentMode)
        }
    }

    // MARK: - 底分级别管理

    /// 检查并推进底分级别
    /// - 每手牌开始时调用，检查是否应该升级底分
    private func checkAndAdvanceBlindLevel() {
        let timeUntilNext = tournamentState.timeUntilNextLevel

        if timeUntilNext <= 0 {
            // 时间到了，升级底分
            let oldLevel = tournamentState.currentLevel
            tournamentState.advanceLevel()
            let newLevel = tournamentState.currentLevel

            if newLevel > oldLevel {
                gameMessage = String(
                    format: String(localized: "底分升级！级别 %lld: %lld/%lld"),
                    Int64(newLevel),
                    Int64(tournamentState.currentBlindLevel.sb),
                    Int64(tournamentState.currentBlindLevel.bb)
                )
            }
        }
    }

    // MARK: - 核心函数：NextActiveSeat 辅助函数

    /// 找到当前座位顺时针方向的下一个活跃玩家座位
    /// - Parameter from: 当前座位号
    /// - Returns: 下一个活跃玩家的座位号，若无则返回nil
    private func nextActiveSeat(from: Int) -> Int? {
        let seatCount = 6
        guard let startIndex = clockwiseSeatCycle.firstIndex(of: from) else { return nil }

        var offset = 1
        while offset <= seatCount {
            let seat = clockwiseSeatCycle[(startIndex + offset) % seatCount]
            if let player = tournamentState.players.first(where: { $0.seatId == seat }),
               !player.isEliminated && player.chips > 0 {
                return seat
            }
            offset += 1
        }
        return nil
    }

    /// 找到当前座位顺时针方向的下一个活跃玩家（用于位置计算）
    private func findNextActivePlayer(from seat: Int) -> Player? {
        guard let nextSeat = nextActiveSeat(from: seat) else { return nil }
        return tournamentState.players.first { $0.seatId == nextSeat }
    }

    // MARK: - 核心函数：按钮移动

    /// 将庄家按钮按顺时针移动到下一个活跃玩家
    /// - 规则：从当前buttonSeat开始，顺时针寻找下一个未淘汰且积分>0的玩家
    /// - 参数 seatCount: 桌子总座位数 (6)
    private func moveButtonClockwise(seatCount: Int = 6) {
        let currentButton = tournamentState.buttonSeat
        guard let startIndex = clockwiseSeatCycle.firstIndex(of: currentButton) else {
            return
        }

        var offset = 1
        while offset <= seatCount {
            let seat = clockwiseSeatCycle[(startIndex + offset) % seatCount]
            if let player = tournamentState.players.first(where: { $0.seatId == seat }),
               !player.isEliminated && player.chips > 0 {
                tournamentState.buttonSeat = seat
                return
            }
            offset += 1
        }

        // 没有找到合适的玩家（不应该发生）
    }

    // MARK: - 核心函数：位置计算

    /// 根据当前按钮位置和活跃玩家数量，动态计算所有玩家的相对位置
    /// 使用 NextActiveSeat 顺时针查找，严格按照位置映射规则
    /// - 6人局: Button → SB → BB → UTG → MP → CO
    /// - 5人局: Button → SB → BB → MP → CO (无UTG)
    /// - 4人局: Button → SB → BB → CO (无UTG, MP)
    /// - 3人局: Button → SB → BB (无MP, CO, UTG)
    /// - 2人局: Button/SB → BB
    private func calculatePositions() {
        let buttonSeat = tournamentState.buttonSeat
        let count = tournamentState.players.filter { !$0.isEliminated && $0.chips > 0 }.count

        guard count >= 2 else {
            return
        }

        // 首先找到所有活跃玩家及其座位
        let activePlayerList = tournamentState.players.filter { !$0.isEliminated && $0.chips > 0 }

        // 位置映射字典: positionName -> seatId
        var positionMap: [String: Int] = [:]

        if count == 2 {
            positionMap["BTN"] = buttonSeat
            positionMap["SB"] = buttonSeat
            if let bbSeat = nextActiveSeat(from: buttonSeat) {
                positionMap["BB"] = bbSeat
            }
        } else {
            positionMap["BTN"] = buttonSeat

            if let sbSeat = nextActiveSeat(from: buttonSeat) {
                positionMap["SB"] = sbSeat
                if let bbSeat = nextActiveSeat(from: sbSeat) {
                    positionMap["BB"] = bbSeat

                    if count >= 4, let utgSeat = nextActiveSeat(from: bbSeat) {
                        positionMap["UTG"] = utgSeat

                        if count == 5, let coSeat = nextActiveSeat(from: utgSeat) {
                            positionMap["CO"] = coSeat
                        } else if count >= 6, let mpSeat = nextActiveSeat(from: utgSeat) {
                            positionMap["MP"] = mpSeat
                            if let coSeat = nextActiveSeat(from: mpSeat) {
                                positionMap["CO"] = coSeat
                            }
                        }
                    }
                }
            }
        }

        // 调试输出
        for (pos, seat) in positionMap.sorted(by: { $0.value < $1.value }) {
        }

        // 将位置映射应用到玩家对象
        // 同时更新 tournamentState 和 gameState 中的玩家
        for (posName, seatId) in positionMap {
            let position: Player.Position
            switch posName {
            case "BTN": position = .button
            case "SB": position = .sb
            case "BB": position = .bb
            case "UTG": position = .utg
            case "MP": position = .mp
            case "CO": position = .co
            default: continue
            }

            // 更新 tournamentState 中的玩家
            if let idx = tournamentState.players.firstIndex(where: { $0.seatId == seatId }) {
                tournamentState.players[idx].position = position
            }

            // 更新 gameState 中的玩家
            if let idx = gameState.players.firstIndex(where: { $0.seatId == seatId }) {
                gameState.players[idx].position = position
            }

            if let player = activePlayerList.first(where: { $0.seatId == seatId }) {
            }
        }

    }

    // MARK: - 核心函数：行动顺序

    private func isPlayableInHand(seatId: Int) -> Bool {
        guard let p = tournamentState.players.first(where: { $0.seatId == seatId }) else { return false }
        return !p.isEliminated && p.isActive && p.chips > 0 && !p.isFolded
    }

    private func orderedPlayableSeatsStarting(after seatId: Int) -> [Int] {
        guard let startIndex = clockwiseSeatCycle.firstIndex(of: seatId) else { return [] }
        var order: [Int] = []
        for offset in 1...clockwiseSeatCycle.count {
            let seat = clockwiseSeatCycle[(startIndex + offset) % clockwiseSeatCycle.count]
            if isPlayableInHand(seatId: seat) {
                order.append(seat)
            }
        }
        return order
    }

    /// 获取翻牌前的行动顺序
    /// 规则:
    /// - 6人局: UTG → MP → CO → BTN → SB → BB (BB最后)
    /// - 5人局: MP → CO → BTN → SB → BB (无UTG)
    /// - 4人局: CO → BTN → SB → BB (无UTG, MP)
    /// - 3人局: SB → BB → BTN (无MP, CO, UTG; 注意3人局BTN不先行动)
    /// - 2人局: BTN → BB (BTN兼SB)
    /// 获取翻牌前的行动顺序
    /// 规则: 从UTG位置开始，顺时针经过MP→CO→BTN→SB，最后BB最后
    /// 注意: 动态构建，只包含活跃（未淘汰、有积分、未弃牌）的玩家
    private func getPreFlopActionOrder() -> [Int] {
        let activePlayers = tournamentState.players.filter { !$0.isEliminated && $0.isActive && $0.chips > 0 && !$0.isFolded }
        let count = activePlayers.count

        guard count >= 2 else { return [] }

        guard let bbSeat = activePlayers.first(where: { $0.position == .bb })?.seatId else { return [] }
        let btnSeat = tournamentState.buttonSeat

        if count == 2 {
            let otherSeat = activePlayers.first { $0.seatId != btnSeat }?.seatId
            let order = otherSeat != nil ? [btnSeat, otherSeat!] : [btnSeat]
            return order
        }

        var order = orderedPlayableSeatsStarting(after: bbSeat)
        return order
    }

    /// 获取翻牌后的行动顺序
    /// 规则: SB先行动，然后BB，然后顺时针经过UTG→MP→CO，最后BTN最后
    /// 注意: 动态构建，只包含活跃（未淘汰、有积分、未弃牌）的玩家
    private func getPostFlopActionOrder() -> [Int] {
        let activePlayers = tournamentState.players.filter { !$0.isEliminated && $0.isActive && $0.chips > 0 && !$0.isFolded }
        let count = activePlayers.count

        guard count >= 2 else { return [] }

        let btnSeat = tournamentState.buttonSeat
        let order = orderedPlayableSeatsStarting(after: btnSeat)
        return order
    }

    // MARK: - 开始新手牌

    func startNewHand() {
        // 重置手牌结束标记
        isHandFinished = false
        isFastForwarding = false
        shouldAutoStartNextHand = false
        lastPracticeFeedback = nil
        currentHandToken = UUID()
        currentAITurnToken = nil
        aiDelayTask?.cancel()
        aiDelayTask = nil

        // 导出任何未导出的手牌历史
        // 注意：不在这里调用 exportAndReset，而是让 startNewHand 内部处理
        // 这样可以避免重复生成牌谱文件

        // 检查并推进底分级别
        checkAndAdvanceBlindLevel()

        let blinds = tournamentState.currentBlindLevel

        if currentMode == .threeBet || currentMode == .pushFold || currentMode == .steal || currentMode == .defend {
            for i in 0..<tournamentState.players.count {
                if currentMode == .pushFold {
                    tournamentState.players[i].chips = Int.random(in: 8...15) * blinds.bb
                } else {
                    tournamentState.players[i].chips = 1000
                }
                tournamentState.players[i].isEliminated = false
            }
        }

        for i in 0..<tournamentState.players.count {
            tournamentState.players[i].resetForNewHand()
        }

        // 重置gameState，使用所有未淘汰的玩家
        let activePlayers = tournamentState.players
            .filter { !$0.isEliminated && $0.chips > 0 }
            .sorted { $0.seatId < $1.seatId }

        guard activePlayers.count >= 2 else {
            if activePlayers.count == 1 {
                endTournament()
            }
            return
        }
        
        // 移动按钮到下一个活跃玩家（仅在真正开始新手牌时才移动）
        if currentMode == .threeBet {
            let aiSeat = activePlayers.first(where: { !$0.isHuman })?.seatId ?? 2
            tournamentState.buttonSeat = aiSeat
        } else if currentMode == .pushFold {
            tournamentState.buttonSeat = clockwiseSeatCycle.randomElement()!
        } else if currentMode == .steal {
            // Human is on BTN or SB
            let humanSeat = activePlayers.first(where: { $0.isHuman })?.seatId ?? 4
            let isBtn = Bool.random()
            if isBtn {
                tournamentState.buttonSeat = humanSeat
            } else {
                // human is SB, so button is the seat before human
                let reverseCycle = clockwiseSeatCycle.reversed().map { $0 }
                let humanIdx = reverseCycle.firstIndex(of: humanSeat) ?? 0
                tournamentState.buttonSeat = reverseCycle[(humanIdx + 1) % reverseCycle.count]
            }
        } else if currentMode == .defend {
            // Human is on BB
            let humanSeat = activePlayers.first(where: { $0.isHuman })?.seatId ?? 4
            let reverseCycle = clockwiseSeatCycle.reversed().map { $0 }
            let humanIdx = reverseCycle.firstIndex(of: humanSeat) ?? 0
            let sb = reverseCycle[(humanIdx + 1) % reverseCycle.count]
            tournamentState.buttonSeat = reverseCycle[(humanIdx + 2) % reverseCycle.count]
        } else {
            moveButtonClockwise()
        }

        // 创建GameState
        gameState = GameState(
            players: activePlayers,
            sbAmount: blinds.sb,
            bbAmount: blinds.bb,
            anteAmount: blinds.ante
        )

        // 设置按钮位置
        // 按钮已经在 startNewHand() 顶部移动，这里同步到 gameState
        gameState.buttonPosition = tournamentState.buttonSeat

        // 重置牌桌
        gameState.deck.shuffle()
        gameState.resetForNewHand()

        // 计算相对位置（Button, SB, BB, UTG, MP, CO）
        // calculatePositions() 会同时更新 tournamentState 和 gameState 中的玩家位置
        calculatePositions()

        // 重置彩池
        gameState.pot = 0

        // 设置手牌历史
        setupHandHistory()

        // 记录preflop阶段
        gameState.phase = .preflop
        
        // Save the state right before antes, blinds, and hole cards are drawn,
        // but after deck is shuffled, players are setup, and button is positioned.
        savedReplayGameState = gameState
        savedReplayTournamentState = tournamentState
        
        recordPhaseStartForHH(phase: .preflop)

        postAntes()

        // 收取底分
        postBlinds()

        // 发手牌
        dealHoleCards()
        updateHoleCardsForHH()

        gameMessage = String(localized: "发牌中...")

        // 开始投入轮
        startBettingRound()
    }

    func replayCurrentHand() {
        guard let savedGS = savedReplayGameState, let savedTS = savedReplayTournamentState else { return }
        
        // Reset state managers
        isHandFinished = false
        isFastForwarding = false
        shouldAutoStartNextHand = false
        currentHandToken = UUID()
        currentAITurnToken = nil
        aiDelayTask?.cancel()
        aiDelayTask = nil
        
        // Cancel any existing timer task
        timerCancellable?.cancel()
        isTimerRunning = false
        actionTimer = 30.0
        
        // Export any incomplete hand history from previous run
        if HandHistoryExporter.shared.currentHandHistory != nil {
            _ = HandHistoryExporter.shared.exportAndReset()
        }
        
        // Restore states (create deep copies to avoid mutating the saved state during replay)
        self.tournamentState = TournamentState(players: savedTS.players)
        self.tournamentState.tournamentId = savedTS.tournamentId
        self.tournamentState.buttonSeat = savedTS.buttonSeat
        self.tournamentState.currentLevel = savedTS.currentLevel
        self.tournamentState.blindSchedule = savedTS.blindSchedule
        
        self.gameState = GameState(players: savedGS.players, sbAmount: savedGS.sbAmount, bbAmount: savedGS.bbAmount, anteAmount: savedGS.anteAmount)
        self.gameState.buttonPosition = savedGS.buttonPosition
        self.gameState.deck = savedGS.deck
        
        // Reset pot and player states
        self.gameState.pot = 0
        self.gameState.communityCards = []
        self.gameState.mainPot = 0
        self.gameState.sidePots = []
        self.gameState.currentPlayerIndex = 0
        self.gameState.bettingRound = 0
        self.gameState.actionOrder = []
        self.gameState.currentActionIndex = nil
        self.gameState.actionHistory = []
        self.gameState.lastRaiseAmount = self.gameState.bbAmount
        self.gameState.isAllInRunout = false
        
        for i in 0..<self.gameState.players.count {
            self.gameState.players[i].totalInvested = 0
            self.gameState.players[i].isFolded = false
            self.gameState.players[i].isAllIn = false
            self.gameState.players[i].holeCards = []
        }
        for i in 0..<self.tournamentState.players.count {
            self.tournamentState.players[i].totalInvested = 0
            self.tournamentState.players[i].isFolded = false
            self.tournamentState.players[i].isAllIn = false
        }
        
        calculatePositions()
        
        // Setup hand history again
        setupHandHistory()
        
        // Ensure phase is correct
        gameState.phase = .preflop
        recordPhaseStartForHH(phase: .preflop)
        
        postAntes()
        postBlinds()
        dealHoleCards()
        updateHoleCardsForHH()
        
        gameMessage = String(localized: "发牌中...")
        startBettingRound()
    }
    
    // MARK: - 收取底分

    private func postAntes() {
        let anteAmount = gameState.anteAmount
        guard anteAmount > 0 else { return }

        for player in gameState.players {
            guard let tIdx = tournamentState.players.firstIndex(where: { $0.seatId == player.seatId }) else { continue }

            let amount = min(anteAmount, tournamentState.players[tIdx].chips)
            guard amount > 0 else { continue }

            tournamentState.players[tIdx].chips -= amount
            tournamentState.players[tIdx].totalInvested += amount
            if tournamentState.players[tIdx].chips == 0 {
                tournamentState.players[tIdx].isAllIn = true
            }

            if let gIdx = gameState.players.firstIndex(where: { $0.seatId == player.seatId }) {
                gameState.players[gIdx].chips = tournamentState.players[tIdx].chips
                gameState.players[gIdx].totalInvested = tournamentState.players[tIdx].totalInvested
                if gameState.players[gIdx].chips == 0 {
                    gameState.players[gIdx].isAllIn = true
                }
                gameState.pot += amount
            }

            HandHistoryExporter.shared.recordAnte(
                playerId: tournamentState.players[tIdx].id.uuidString,
                seat: tournamentState.players[tIdx].seatId,
                amount: amount,
                totalInvested: tournamentState.players[tIdx].totalInvested
            )
        }
    }

    private func postBlinds() {
        let buttonSeat = tournamentState.buttonSeat

        // 获取活跃玩家（用于确定SB/BB位置）
        let activePlayers = tournamentState.players
            .filter { !$0.isEliminated && $0.chips > 0 }
            .sorted { $0.seatId < $1.seatId }

        guard activePlayers.count >= 2 else { return }

        // 确定SB和BB座位
        let sbSeat: Int
        let bbSeat: Int

        if activePlayers.count == 2 {
            // 2人局：按钮同时是SB，BB是另一方
            sbSeat = buttonSeat
            bbSeat = activePlayers.first { $0.seatId != buttonSeat }?.seatId ?? (buttonSeat + 1) % 6
        } else {
            // 正常局：找SB和BB位置
            sbSeat = activePlayers.first { $0.position == .sb }?.seatId ?? -1
            bbSeat = activePlayers.first { $0.position == .bb }?.seatId ?? -1
        }

        // 收取SB
        if sbSeat >= 0 {
            if let idx = tournamentState.players.firstIndex(where: { $0.seatId == sbSeat }) {
                let sbAmount = min(gameState.sbAmount, tournamentState.players[idx].chips)
                tournamentState.players[idx].chips -= sbAmount
                tournamentState.players[idx].currentBet = sbAmount
                tournamentState.players[idx].totalInvested += sbAmount
                if tournamentState.players[idx].chips == 0 {
                    tournamentState.players[idx].isAllIn = true
                }

                // 同时更新gameState
                if let gameIdx = gameState.players.firstIndex(where: { $0.seatId == sbSeat }) {
                    gameState.players[gameIdx].chips = tournamentState.players[idx].chips
                    gameState.players[gameIdx].currentBet = sbAmount
                    gameState.players[gameIdx].totalInvested += sbAmount
                    if gameState.players[gameIdx].chips == 0 {
                        gameState.players[gameIdx].isAllIn = true
                    }
                    gameState.pot += sbAmount
                }

                // 记录手牌历史
                HandHistoryExporter.shared.recordSmallBlind(
                    playerId: tournamentState.players[idx].id.uuidString,
                    seat: sbSeat,
                    amount: sbAmount,
                    totalInvested: tournamentState.players[idx].totalInvested
                )

            }
        }

        // 收取BB
        if bbSeat >= 0 {
            if let idx = tournamentState.players.firstIndex(where: { $0.seatId == bbSeat }) {
                let bbAmount = min(gameState.bbAmount, tournamentState.players[idx].chips)
                tournamentState.players[idx].chips -= bbAmount
                tournamentState.players[idx].currentBet = bbAmount
                tournamentState.players[idx].totalInvested += bbAmount
                if tournamentState.players[idx].chips == 0 {
                    tournamentState.players[idx].isAllIn = true
                }

                // 同时更新gameState
                if let gameIdx = gameState.players.firstIndex(where: { $0.seatId == bbSeat }) {
                    gameState.players[gameIdx].chips = tournamentState.players[idx].chips
                    gameState.players[gameIdx].currentBet = bbAmount
                    gameState.players[gameIdx].totalInvested += bbAmount
                    if gameState.players[gameIdx].chips == 0 {
                        gameState.players[gameIdx].isAllIn = true
                    }
                    gameState.pot += bbAmount
                }

                // 记录手牌历史
                HandHistoryExporter.shared.recordBigBlind(
                    playerId: tournamentState.players[idx].id.uuidString,
                    seat: bbSeat,
                    amount: bbAmount,
                    totalInvested: tournamentState.players[idx].totalInvested
                )

            }
        }

        // potAmount 是多余的，gameState.pot 已经在上面直接累加了
    }

    // MARK: - 发牌

    private func dealHoleCards() {
        let activePlayers = gameState.players.filter { $0.isActive && !$0.isFolded }

        for player in activePlayers {
            if let idx = gameState.players.firstIndex(where: { $0.seatId == player.seatId }) {
                var cards: [Card] = []
                for _ in 0..<2 {
                    if let card = gameState.deck.draw() {
                        cards.append(card)
                    }
                }
                gameState.players[idx].holeCards = cards
            }
        }
        
        HandHistoryExporter.shared.updateHoleCards(players: gameState.players)
    }

    // MARK: - 投入轮

    private func startBettingRound() {
        if runoutAndShowdownIfAllIn() {
            return
        }

        gameState.bettingRound += 1
        isTimerRunning = true
        actionTimer = 30.0

        // 重置投入轮追踪
        bettingManager.resetBettingRoundTracking()

        // 确定行动顺序
        let actionOrder: [Int]
        if gameState.phase == .preflop {
            actionOrder = getPreFlopActionOrder()
        } else {
            actionOrder = getPostFlopActionOrder()
        }

        gameState.actionOrder = actionOrder

        let firstActionIdx = actionOrder.firstIndex { seat in
            guard let p = gameState.players.first(where: { $0.seatId == seat }) else { return false }
            return p.isActive && !p.isFolded && !p.isAllIn
        }

        if let firstActionIdx {
            let firstSeat = actionOrder[firstActionIdx]
            if let firstIdx = gameState.players.firstIndex(where: { $0.seatId == firstSeat }) {
                gameState.currentPlayerIndex = firstIdx
                gameState.currentActionIndex = firstActionIdx
            } else {
                advancePhase()
                return
            }
        } else {
            advancePhase()
            return
        }

        // Apply fast-forwarding for practice modes to skip AI pre-human action delays
        if gameState.phase == .preflop && (currentMode == .steal || currentMode == .threeBet || currentMode == .defend) {
            isFastForwarding = true
        }

        let currentPlayer = gameState.currentPlayer
        if let currentPlayer {
            if currentPlayer.isHuman {
                let highestBet = gameState.players.map { $0.currentBet }.max() ?? 0
                let amountToCall = max(0, highestBet - currentPlayer.currentBet)
                gameMessage = amountToCall > 0 ? String(localized: "轮到你（需跟注 \(amountToCall)）") : String(localized: "轮到你")
            } else {
                gameMessage = String(format: String(localized: "%@ 思考中..."), currentPlayer.name)
            }
        } else {
            gameMessage = ""
        }


        // 如果是AI，触发AI决策
        if let player = currentPlayer, !player.isHuman {
            let token = currentHandToken
            aiDelayTask?.cancel()
            aiDelayTask = Task { @MainActor [weak self] in
                guard let self = self else { return }
                if !self.isFastForwarding {
                    try? await Task.sleep(nanoseconds: UInt64(self.displayDelaySeconds * 1_000_000_000))
                }
                guard !Task.isCancelled else { return }
                guard self.currentHandToken == token, !self.isHandFinished, !self.tournamentState.isFinished else { return }
                
                // Double check it's still this AI's turn
                guard let currentP = self.gameState.currentPlayer, currentP.seatId == player.seatId else { return }
                
                self.processAITurn()
            }
        }
    }

    // MARK: - 玩家动作

    func playerAction(_ action: PlayerAction, forPlayerId expectedPlayerId: UUID? = nil) {
        // 再次检查：确保当前玩家仍然可以行动（可能被之前的 Task 跳过弃牌了）
        guard var currentPlayer = gameState.currentPlayer else {
            return
        }

        // 防止重复提交动作的标记（仅针对人类玩家）
        if currentPlayer.isHuman {
            guard !isProcessingAction else { return }
            isProcessingAction = true
            
            // 确保在任何返回路径中释放标记，但延迟一点时间防止动画过渡期间再次触发
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.isProcessingAction = false
            }
        }
        
        // 防止快速连续点击导致代替其他玩家行动
        if let expectedId = expectedPlayerId, currentPlayer.id != expectedId {
            return
        }

        // 跳过已弃牌或已全押的玩家（可能是之前的异步 Task 延迟导致的）
        if currentPlayer.isFolded || currentPlayer.isAllIn || !currentPlayer.isActive {
            // 直接进入下一个玩家
            advanceToNextPlayer()
            return
        }

        // 验证 tournamentState 中的积分
        if let tPlayer = tournamentState.players.first(where: { $0.seatId == currentPlayer.seatId }) {
        }

        // 记录投入前的最高投入额（用于计算加注增量）
        let previousHighestBet = gameState.players.map { $0.currentBet }.max() ?? 0

        let result = bettingManager.processAction(
            action: action,
            for: &currentPlayer,
            gameState: &gameState
        )


        // 写回玩家到 gameState
        if let idx = gameState.players.firstIndex(where: { $0.seatId == currentPlayer.seatId }) {
            gameState.players[idx] = currentPlayer
        }
        
        // 同步更新 tournamentState（用于行动顺序计算）
        if let tIdx = tournamentState.players.firstIndex(where: { $0.seatId == currentPlayer.seatId }) {
            tournamentState.players[tIdx] = currentPlayer
        }

        // 记录动作
        let finalActionToRecord: PlayerAction
        if result.success {
            // Check if the action was actually an all-in due to insufficient chips
            if currentPlayer.isAllIn {
                // 如果当前投入总额等同于刚才计算后的 amount，或者 currentPlayer 的筹码为 0，这实际上是一次 All-In
                finalActionToRecord = .allIn(amount: currentPlayer.currentBet)
            } else {
                finalActionToRecord = action
            }
            
            recordPlayerActionForHH(action: finalActionToRecord, player: currentPlayer, totalInvested: currentPlayer.totalInvested)
            // 更新 UI 消息，显示动作结果（加注增量=新投入额-前一次最高投入额）
            gameMessage = actionResultMessage(finalActionToRecord, playerName: currentPlayer.name, amount: currentPlayer.currentBet, previousHighestBet: previousHighestBet)
        } else {
            finalActionToRecord = action
        }

        lastAction = result.success ? finalActionToRecord : action
        gameState.actionHistory.append(
            GameState.ActionRecord(playerId: currentPlayer.id, action: lastAction!, phase: gameState.phase, bettingRound: gameState.bettingRound, timestamp: Date())
        )

        if !result.success {
            gameMessage = String(localized: "无效动作")
            if let currentPlayer = gameState.currentPlayer, !currentPlayer.isHuman {
                let highestBet = gameState.players.map { $0.currentBet }.max() ?? 0
                let validActions = bettingManager.getValidActions(
                    for: currentPlayer,
                    highestBet: highestBet,
                    lastRaiseAmount: gameState.lastRaiseAmount,
                    phase: gameState.phase,
                    minBet: gameState.bbAmount,
                    sbAmount: gameState.sbAmount,
                    bbAmount: gameState.bbAmount,
                    isFirstBettor: highestBet == 0
                )
                let fallback: PlayerAction
                if validActions.canCheck {
                    fallback = .check
                } else if validActions.canCall {
                    fallback = .call(amount: validActions.callAmount)
                } else {
                    fallback = .allIn(amount: validActions.allInAmount)
                }
                let token = currentHandToken
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    guard self.currentHandToken == token, !self.isHandFinished, !self.tournamentState.isFinished else { return }
                    self.playerAction(fallback)
                }
            }
            return
        }
        
        if currentMode == .threeBet && currentPlayer.isHuman {
            // End hand immediately for 3Bet practice
            evaluate3BetPractice(action: finalActionToRecord, player: currentPlayer)
            return
        } else if currentMode == .pushFold && currentPlayer.isHuman {
            evaluatePushFoldPractice(action: finalActionToRecord, player: currentPlayer)
            return
        } else if currentMode == .steal && currentPlayer.isHuman {
            evaluateStealPractice(action: finalActionToRecord, player: currentPlayer)
            return
        } else if currentMode == .defend && currentPlayer.isHuman {
            evaluateDefendPractice(action: finalActionToRecord, player: currentPlayer)
            return
        }

        if endHandIfOnlyOnePlayerRemaining() {
            return
        }

        // Restore fast-forwarding off if it's a practice mode and human just acted (though we return above, just to be safe) or if we reach here and human is up next
        // Handled in advanceToNextPlayer actually

        // 检查是否投入轮结束
        let highestBet = gameState.players.map { $0.currentBet }.max() ?? 0

        // 记录一下当前的 currentPlayerIndex，因为在 Task 外部我们把它置为 -1 防止双击
        // 但 isBettingRoundComplete 和后续计算还需要知道当前行动完的是谁
        let actingPlayerIndex = gameState.currentPlayerIndex
        
        // 防止等待期间二次点击
        gameState.currentPlayerIndex = -1 
        
        // 如果是人类玩家行动，我们用一个 Task 稍微等待一下再推进游戏，以便让玩家能看清自己的动作结果
        let isHuman = currentPlayer.isHuman
        let token = currentHandToken
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            if isHuman && !self.isFastForwarding {
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 停留1.5秒
            }
            
            guard self.currentHandToken == token, !self.isHandFinished, !self.tournamentState.isFinished else { return }
            
            // 恢复索引，供后续计算
            self.gameState.currentPlayerIndex = actingPlayerIndex
            
            if self.bettingManager.isBettingRoundComplete(
                players: self.gameState.players,
                highestBet: highestBet,
                currentPlayerIndex: self.gameState.currentPlayerIndex
            ) {
                if self.runoutAndShowdownIfAllIn() {
                    return
                }
                self.advancePhase()
            } else {
                self.advanceToNextPlayer()
            }
        }
    }

    private func evaluate3BetPractice(action: PlayerAction, player: Player) {
        isTimerRunning = false
        gameState.currentPlayerIndex = -1
        isHandFinished = true
        
        let holeCards = player.holeCards ?? []
        let rank1 = holeCards.first?.numericValue ?? 0
        let rank2 = holeCards.last?.numericValue ?? 0
        let isSuited = holeCards.count == 2 && holeCards.first?.suit == holeCards.last?.suit
        let isPair = holeCards.count == 2 && rank1 == rank2
        let maxRank = max(rank1, rank2)
        let minRank = min(rank1, rank2)
        
        // Define premium hands for 3Bet
        let isPremium = (maxRank >= 10 && minRank >= 10) || (isPair && maxRank >= 8) || (maxRank >= 14 && minRank >= 9 && isSuited)
        
        var feedbackOptions: [String] = []
        switch action {
        case .raise, .allIn:
            if isPremium {
                feedbackOptions = [
                    String(localized: "漂亮的 3Bet！你拿到了优质手牌，进行 3Bet 获取价值并夺取主动权是非常正确的决定。"),
                    String(localized: "面对前位加注，拿到强牌果断 3Bet 是正确的，不要给对手看便宜翻牌的机会。"),
                    String(localized: "很好的 3Bet 尺度！你利用优质手牌建立了足够的底池并隔离了对手。")
                ]
            } else {
                feedbackOptions = [
                    String(localized: "你的 3Bet 过于激进。手牌不够强时，面对前位加注进行 3Bet 容易陷入被动或损失筹码。"),
                    String(localized: "翻前面对 4-bet 弃牌过频，或者用边缘牌 3-bet 都是负 EV 行为，请收紧你的范围。"),
                    String(localized: "新手期不要盲目模仿顶尖高手的漂移或诈唬打法，用边缘牌 3-bet 容易失控。")
                ]
            }
        case .call:
            if isPremium {
                var callOptions: [String] = []
                callOptions.append(String(localized: "手牌很强，只选择跟注过于被动了。这里应该 3Bet 来压榨价值并夺取主动权。"))
                callOptions.append(String(localized: "拿到强牌时翻前仅平跟，未能通过 3-bet 隔离成单挑底池，会导致多人池胜率下降。"))
                if isPair && maxRank >= 13 {
                    callOptions.append(String(localized: "拿到 KK/AA 过于保守，实际上翻前你应该更激进地进行加注或反加。"))
                }
                feedbackOptions = callOptions
            } else if isSuited || (maxRank == minRank && maxRank >= 5) || (maxRank >= 10 && minRank >= 9) {
                var acceptableOptions: [String] = []
                acceptableOptions.append(String(localized: "跟注是可以接受的。手牌有一定可玩性，但不值得 3Bet 冒险。"))
                if isSuited {
                    acceptableOptions.append(String(localized: "同花大牌在有利位置可以跟注或 3-bet，但要注意控制翻后的底池大小。"))
                }
                if isPair {
                    acceptableOptions.append(String(localized: "拿到中等对子跟注寻求暗三条是可以的，但要注意筹码深度是否提供足够的隐含赔率。"))
                }
                feedbackOptions = acceptableOptions
            } else {
                feedbackOptions = [
                    String(localized: "手牌偏弱，这里跟注前位加注会让你在翻后面临困难，建议弃牌。"),
                    String(localized: "前位入池标准太低，应只玩顶级手牌避免后续位置带来的决策压力。"),
                    String(localized: "翻前入池范围太宽，建议新手先采用 ABC 打法，专注 99-AA 及 AK/AQ/AJ。")
                ]
            }
        case .fold:
            if isPremium {
                feedbackOptions = [
                    String(localized: "太紧了！你放弃了一手优质牌，这里绝对应该 3Bet。"),
                    String(localized: "面对加注弃牌过频，未能利用你的强牌范围捍卫底池。"),
                    String(localized: "打法过于保守，放弃了巨大的价值获取机会，这在长期是不可持续的。")
                ]
            } else {
                var options: [String] = []
                options.append(String(localized: "好弃牌！面对前位加注，边缘牌和垃圾牌果断弃掉是赢家的素养。"))
                options.append(String(localized: "正确的弃牌，避免了在不利位置用弱牌对抗紧凶玩家的加注。"))
                options.append(String(localized: "保持耐心是德扑的核心，过滤掉弱牌是迈向盈利的第一步。"))
                feedbackOptions = options
            }
        case .bet, .check:
            feedbackOptions = [String(localized: "无效动作")]
        }
        
        self.practiceFeedback = feedbackOptions.randomElement() ?? ""
        self.lastPracticeFeedback = self.practiceFeedback
        self.gameMessage = String(localized: "练习结束")
        HandHistoryExporter.shared.recordPracticeHandEnd(playersAfter: gameState.players, practiceFeedback: self.practiceFeedback)
    }

    private func evaluatePushFoldPractice(action: PlayerAction, player: Player) {
        isTimerRunning = false
        gameState.currentPlayerIndex = -1
        isHandFinished = true
        
        let bbAmount = gameState.bbAmount
        // Player might have already committed some chips (e.g. SB or BB), so add currentBet to get their total starting chips for this hand
        let totalChips = player.chips + player.currentBet
        let playerBBs = totalChips / bbAmount
        let holeCards = player.holeCards ?? []
        let rank1 = holeCards.first?.numericValue ?? 0
        let rank2 = holeCards.last?.numericValue ?? 0
        let isSuited = holeCards.count == 2 && holeCards.first?.suit == holeCards.last?.suit
        let isPair = holeCards.count == 2 && rank1 == rank2
        let maxRank = max(rank1, rank2)
        let minRank = min(rank1, rank2)
        
        let isStrong = maxRank >= 13 || (isPair && maxRank >= 6) || (maxRank >= 10 && minRank >= 10 && isSuited)
        let isPlayable = isStrong || (maxRank >= 10 && minRank >= 9) || isPair || isSuited
        
        var feedbackOptions: [String] = []
        switch action {
        case .allIn, .raise:
            if isPlayable {
                feedbackOptions = [
                    String(format: String(localized: "漂亮的 Push！在 %lldBB 的深度，拿到有胜率的手牌全押施压是正确的。"), playerBBs),
                    String(localized: "在短码阶段拿到可玩性手牌果断全押，可以最大化弃牌率（Fold Equity）。"),
                    String(localized: "非常坚决的 Push。处于短码时，避免被动跟注，主动出击是最好的防守。")
                ]
            } else {
                var options: [String] = []
                options.append(String(localized: "这个全押有点松。虽然筹码不多，但这手牌赢率太低，建议等待更好的时机。"))
                options.append(String(localized: "全下尺度计算虽然简单，但要结合起手牌质量，这手牌不值得拼命。"))
                if maxRank <= 9 {
                    options.append(String(localized: "缺乏位置意识，在不利位置用垃圾牌盲目全下，被跟注的风险极高。"))
                }
                feedbackOptions = options
            }
        case .call:
            feedbackOptions = [
                String(localized: "在短码阶段，只跟注是不好的策略。你应该全押(Push)或者弃牌(Fold)来最大化你的弃牌率。"),
                String(localized: "筹码深度不够时仍盲目跟注，不仅没有弃牌率，翻后也很难操作。"),
                String(localized: "短码时不要用跟注消耗自己所剩无几的筹码，请采用 Push/Fold 策略。")
            ]
        case .fold:
            if isStrong {
                feedbackOptions = [
                    String(format: String(localized: "太保守了！在 %lldBB 的深度，这手牌绝对值得全押一搏。"), playerBBs),
                    String(localized: "这手牌即使被跟注也有很好的胜率，此时弃牌属于负 EV 行为。"),
                    String(localized: "拿到优质手牌过于保守，没有把握住筹码翻倍的绝佳机会。")
                ]
            } else {
                feedbackOptions = [
                    String(localized: "好弃牌。保留短码等待更好的起手牌。"),
                    String(localized: "面对不利局势果断弃牌，在短码阶段每一分筹码都很宝贵。"),
                    String(localized: "理智的弃牌。牌力太弱时不要被短码焦虑冲昏头脑强行全下。")
                ]
            }
        case .bet, .check:
            feedbackOptions = [String(localized: "无效动作")]
        }
        
        self.practiceFeedback = feedbackOptions.randomElement() ?? ""
        self.lastPracticeFeedback = self.practiceFeedback
        self.gameMessage = String(localized: "练习结束")
        HandHistoryExporter.shared.recordPracticeHandEnd(playersAfter: gameState.players, practiceFeedback: self.practiceFeedback)
    }

    private func evaluateStealPractice(action: PlayerAction, player: Player) {
        isTimerRunning = false
        gameState.currentPlayerIndex = -1
        isHandFinished = true
        
        let holeCards = player.holeCards ?? []
        let rank1 = holeCards.first?.numericValue ?? 0
        let rank2 = holeCards.last?.numericValue ?? 0
        let isSuited = holeCards.count == 2 && holeCards.first?.suit == holeCards.last?.suit
        let isPair = holeCards.count == 2 && rank1 == rank2
        let maxRank = max(rank1, rank2)
        let minRank = min(rank1, rank2)
        
        let isStealable = isSuited || (maxRank >= 9) || isPair || (maxRank >= 7 && maxRank - minRank <= 1)
        let isPremium = (maxRank >= 13 && minRank >= 10) || (isPair && maxRank >= 9)
        let isTrash = maxRank <= 8 && !isSuited && !isPair && (maxRank - minRank >= 2)
        
        var feedbackOptions: [String] = []
        switch action {
        case .raise, .allIn:
            if isPremium {
                var raiseOptions: [String] = []
                raiseOptions.append(String(localized: "标准的价值加注。你在偷盲位拿到强牌，加注理所应当。"))
                if maxRank >= 10 {
                    raiseOptions.append(String(localized: "非常棒的施压！用大牌偷盲，被跟注后在翻后也有极大优势。"))
                }
                raiseOptions.append(String(localized: "优质牌加注，这才是德扑盈利的根本，保持这样的打法。"))
                feedbackOptions = raiseOptions
            } else if isStealable {
                feedbackOptions = [
                    String(localized: "很好的偷盲加注！在偷盲位置，用宽范围施压是极佳的策略。"),
                    String(localized: "面对大盲注，用可玩性强的手牌进行偷盲是非常标准的打法。"),
                    String(localized: "正确的隔离策略。利用位置优势，迫使盲注玩家放弃他们的底池权益。")
                ]
            } else {
                var callOptions: [String] = []
                callOptions.append(String(localized: "偷盲位不能掩盖手牌过弱的事实，遇到大盲位 3-bet 你将毫无还手之力。"))
                if isTrash {
                    callOptions.append(String(localized: "你的偷盲范围太宽了。用毫无联系的垃圾牌加注很容易被反击。"))
                    callOptions.append(String(localized: "用垃圾牌偷盲一旦被跟注，翻后处于不利位置的决策将极为困难。"))
                } else if maxRank <= 9 {
                    callOptions.append(String(localized: "这手牌牌力偏弱，即使在偷盲位也建议弃牌。"))
                }
                feedbackOptions = callOptions
            }
        case .call:
            if isPremium {
                var callOptions: [String] = []
                callOptions.append(String(localized: "手牌这么强，你应该加注建立底池。"))
                if isPair && maxRank >= 13 {
                    callOptions.append(String(localized: "拿到 AA/KK 时翻前仅平跟，未能通过 3-bet 隔离，多人池胜率会大幅下降。"))
                }
                callOptions.append(String(localized: "盲注位跟注过于被动，你放弃了翻前夺取主动权并赢下盲注的最好机会。"))
                feedbackOptions = callOptions
            } else {
                var callOptions: [String] = []
                callOptions.append(String(localized: "跛入（Limp）不是好习惯。如果要打这手牌，你应该加注来偷盲。"))
                callOptions.append(String(localized: "平跟等于把主动权拱手让给大盲，极易被大盲玩家反打。"))
                if isPair || isSuited {
                    callOptions.append(String(localized: "小对子或同花连张如果在有利位置，要么加注偷盲，要么弃牌，平跟是下策。"))
                }
                feedbackOptions = callOptions
            }
        case .fold:
            if isStealable {
                var foldOptions: [String] = []
                foldOptions.append(String(localized: "你放弃了偷盲的机会！你应该用这手牌加注向盲注施压。"))
                foldOptions.append(String(localized: "你损失了盲注的死钱价值。德扑中很大一部分利润来自于偷盲和施压。"))
                if isPair || isSuited {
                    foldOptions.append(String(localized: "过于保守！在偷盲位应该放宽同花连张或小对子的入池范围。"))
                }
                feedbackOptions = foldOptions
            } else if isTrash {
                var options: [String] = []
                options.append(String(localized: "正确的弃牌。牌太差不值得偷盲。"))
                options.append(String(localized: "很好的纪律性。不强行偷盲，避免了被紧凶玩家剥削。"))
                options.append(String(localized: "即便在偷盲位，也没有必要强行用垃圾牌入池。明智的选择。"))
                feedbackOptions = options
            } else {
                var options: [String] = []
                options.append(String(localized: "不错的弃牌。面对激进的盲注玩家，放弃边缘牌是合理的。"))
                options.append(String(localized: "保守但安全的打法。在偷盲位也可以选择性放弃较弱的手牌。"))
                feedbackOptions = options
            }
        case .bet, .check:
            feedbackOptions = [String(localized: "无效动作")]
        }
        
        self.practiceFeedback = feedbackOptions.randomElement() ?? ""
        self.lastPracticeFeedback = self.practiceFeedback
        self.gameMessage = String(localized: "练习结束")
        HandHistoryExporter.shared.recordPracticeHandEnd(playersAfter: gameState.players, practiceFeedback: self.practiceFeedback)
    }

    private func evaluateDefendPractice(action: PlayerAction, player: Player) {
        isTimerRunning = false
        gameState.currentPlayerIndex = -1
        isHandFinished = true
        
        let holeCards = player.holeCards ?? []
        let rank1 = holeCards.first?.numericValue ?? 0
        let rank2 = holeCards.last?.numericValue ?? 0
        let isSuited = holeCards.count == 2 && holeCards.first?.suit == holeCards.last?.suit
        let isPair = holeCards.count == 2 && rank1 == rank2
        let maxRank = max(rank1, rank2)
        let minRank = min(rank1, rank2)
        
        let isPremium = (maxRank >= 13 && minRank >= 10) || (isPair && maxRank >= 9)
        let isPlayable = isSuited || (maxRank >= 10) || isPair || (maxRank >= 8 && minRank >= 7)
        
        var feedbackOptions: [String] = []
        switch action {
        case .raise:
            if isPremium {
                feedbackOptions = [
                    String(localized: "非常棒的 3Bet！面对偷盲，用强牌反击获取价值。"),
                    String(localized: "完美！拿到顶级手牌不仅要防守，更要 3Bet 扩大底池让对手付出代价。"),
                    String(localized: "很好的防守反击。让偷盲者陷入困境，这才是盲注防守的核心。")
                ]
            } else if isPlayable {
                var bluffOptions: [String] = []
                bluffOptions.append(String(localized: "不错的 3Bet 诈唬。面对频繁偷盲的对手，用这手牌反击可以赢下底池。"))
                if maxRank >= 13 {
                    bluffOptions.append(String(localized: "利用阻断牌（如含A/K的牌）在大盲位进行 3-bet，能给宽范围偷盲者极大的弃牌压力。"))
                }
                bluffOptions.append(String(localized: "这种半诈唬加注很好。就算被跟注，翻后你依然有不错的操作空间和胜率。"))
                feedbackOptions = bluffOptions
            } else {
                var callOptions: [String] = []
                callOptions.append(String(localized: "大盲位拿到弱牌盲目反加是资金粉碎机。防守要有度，不要变成情绪化玩家。"))
                callOptions.append(String(localized: "缺乏逻辑支撑的 3-bet，对手如果 4-bet 你只能弃牌，白白损失大量筹码。"))
                if maxRank <= 9 {
                    callOptions.append(String(localized: "你的反击太激进了。用垃圾牌 3Bet 风险过大。"))
                }
                feedbackOptions = callOptions
            }
        case .allIn:
            if isPremium {
                feedbackOptions = [
                    String(localized: "用顶级强牌直接全下！这是非常激进但也非常有效的价值榨取。"),
                    String(localized: "非常暴力的反击！用强牌全下可以立刻给对手施加极大的压力。")
                ]
            } else if isPlayable {
                feedbackOptions = [
                    String(localized: "用中等牌力或同花连张全下作为半诈唬，具有一定的弃牌率，但风险较高。"),
                    String(localized: "激进的防守策略！这手牌有一定的胜率，全下可以最大化你的弃牌率。")
                ]
            } else {
                feedbackOptions = [
                    String(localized: "太疯狂了！用弱牌在盲注位全下是极其危险的。"),
                    String(localized: "毫无逻辑的全下。面对加注，用弱牌直接拼命会导致快速破产。")
                ]
            }
        case .call:
            if isPremium {
                var callOptions: [String] = []
                callOptions.append(String(localized: "这手牌你应该 3Bet 获取价值，而不是只跟注。"))
                if isPair {
                    callOptions.append(String(localized: "用 AA/KK 在大盲位只跟注，给了加注玩家太好的隐含赔率去击中两对或三条。"))
                }
                callOptions.append(String(localized: "盲注位防守强牌过于被动。慢打强牌时机不对，翻后在不利位置会很难受。"))
                feedbackOptions = callOptions
            } else if isPlayable {
                var playableCallOptions: [String] = []
                playableCallOptions.append(String(localized: "标准的防守跟注。你在大盲位有很好的赔率，看看翻牌是可以的。"))
                if isSuited {
                    playableCallOptions.append(String(localized: "大盲位有防守折扣，用同花连张或中等牌力跟注看翻牌是正 EV 的打法。"))
                }
                playableCallOptions.append(String(localized: "理智的跟注防守。但要注意，翻后如果没有击中强牌，不要盲目纠缠。"))
                feedbackOptions = playableCallOptions
            } else {
                feedbackOptions = [
                    String(localized: "这手牌太差了，即使有底池赔率也不建议跟注。"),
                    String(localized: "拿到小牌且非同色，即便赔率再好也不应跟注。防守范围太宽容易导致翻后破产。"),
                    String(localized: "位置劣势下拿到垃圾牌，过牌或轻易跟注属于典型的“跟注站”行为。")
                ]
            }
        case .fold:
            if isPremium {
                feedbackOptions = [
                    String(localized: "重大失误！你放弃了一手顶级牌。"),
                    String(localized: "面对松凶玩家的偷盲加注弃掉了坚果牌，这是对筹码的严重浪费！"),
                    String(localized: "大盲位面对加注弃牌过多，完全没有捍卫你的强牌范围。")
                ]
            } else if isPlayable {
                feedbackOptions = [
                    String(localized: "你防守得太紧了。大盲位有很好的赔率，这手牌值得跟注或 3Bet。"),
                    String(localized: "大盲位防守范围太窄，面对后位加注弃牌过多，损失了防守价值。"),
                    String(localized: "在极佳的底池赔率下弃掉了一手有潜力的好牌，太可惜了。")
                ]
            } else {
                var options: [String] = []
                options.append(String(localized: "即使在大盲位，不抵抗也是一种防守策略，保留筹码去打更优质的手牌。"))
                options.append(String(localized: "很好，没有因为舍不得已经投入的大盲注而陷入“沉没成本”陷阱。"))
                if maxRank <= 9 {
                    options.append(String(localized: "正确的弃牌。面对加注，果断放弃垃圾牌。"))
                }
                feedbackOptions = options
            }
        case .bet, .check:
            feedbackOptions = [String(localized: "无效动作")]
        }
        
        self.practiceFeedback = feedbackOptions.randomElement() ?? ""
        self.lastPracticeFeedback = self.practiceFeedback
        self.gameMessage = String(localized: "练习结束")
        HandHistoryExporter.shared.recordPracticeHandEnd(playersAfter: gameState.players, practiceFeedback: self.practiceFeedback)
    }

    private func endHandIfOnlyOnePlayerRemaining() -> Bool {
        let remaining = gameState.players.filter { $0.isActive && !$0.isFolded }
        guard remaining.count == 1 else { return false }
        guard let winner = remaining.first else { return false }

        isTimerRunning = false
        gameState.currentPlayerIndex = -1 // 立即重置，防止在此期间二次点击

        let pot = gameState.pot
        let token = currentHandToken
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            if !self.isFastForwarding {
                // 等待一下，让玩家能看清最后一名对手的动作（例如“弃牌”）
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
            guard self.currentHandToken == token, !self.tournamentState.isFinished else { return }

            if pot > 0, let idx = self.gameState.players.firstIndex(where: { $0.id == winner.id }) {
                let beforeChips = self.gameState.players[idx].chips
                self.gameState.players[idx].chips += pot
                if let tIdx = self.tournamentState.players.firstIndex(where: { $0.id == winner.id }) {
                    self.tournamentState.players[tIdx].chips = self.gameState.players[idx].chips
                }
            }

            self.gameMessage = String(localized: "赢家: \(winner.name) +\(pot)")

            let potOutcomes = [
                PotOutcome(amount: pot, eligiblePlayerIds: [winner.id], winnerIds: [winner.id])
            ]
            let payouts: [UUID: Int] = [winner.id: pot]

            AIAgent.shared.recordHandResult(players: self.gameState.players, payouts: payouts, bbAmount: self.gameState.bbAmount, gameState: self.gameState)

            self.finalizeHandForHH(showdownPlayers: [], potOutcomes: potOutcomes, payouts: payouts)
            self.onHandComplete?([winner.id])

            self.checkEliminations()
            self.isHandFinished = true
            self.gameState.currentPlayerIndex = -1
    
            let hasActiveHuman = self.tournamentState.players.contains { $0.isHuman && !$0.isEliminated && $0.chips > 0 }
            let activePlayersCount = self.tournamentState.players.filter { $0.isActive && !$0.isEliminated }.count
            
            // 移除所有自动跳过逻辑，让其停留在结果画面
            if !hasActiveHuman && !self.tournamentState.isFinished {
                let token = currentHandToken
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    guard self.currentHandToken == token, !self.tournamentState.isFinished else { return }
                    self.endTournament()
                }
                return
            }
        }

        return true
    }

    private func resetStreetBets() {
        for i in 0..<gameState.players.count {
            gameState.players[i].currentBet = 0
        }
    }

    private func runoutAndShowdownIfAllIn() -> Bool {
        if gameState.phase == .showdown || gameState.phase == .finished {
            return false
        }

        let remaining = gameState.players.filter { $0.isActive && !$0.isFolded }
        guard remaining.count >= 2 else { return false }

        let highestBet = gameState.players.map { $0.currentBet }.max() ?? 0
        let remainingNonAllIn = remaining.filter { !$0.isAllIn }

        if !remaining.allSatisfy({ $0.isAllIn }) {
            guard remainingNonAllIn.count == 1 else { return false }
            guard remainingNonAllIn.allSatisfy({ $0.currentBet == highestBet }) else { return false }
        }

        // 所有人都 All-in 或者只有一个人未 All-in 但已经 call 满，此时进入 Runout 并立刻亮底牌
        isTimerRunning = false
        gameState.isAllInRunout = true
        
        for i in 0..<gameState.players.count {
            if !gameState.players[i].isFolded && gameState.players[i].isActive {
                gameState.players[i].showHoleCards = true
                if let tIdx = tournamentState.players.firstIndex(where: { $0.id == gameState.players[i].id }) {
                    tournamentState.players[tIdx].showHoleCards = true
                }
            }
        }
        
        let token = currentHandToken
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            // 延迟一下，让玩家能看清最后一名对手的动作（例如“全押”或“跟注”）
            if !self.isFastForwarding {
                try? await Task.sleep(nanoseconds: UInt64(self.displayDelaySeconds * 1_000_000_000))
            }
            guard self.currentHandToken == token, !self.tournamentState.isFinished else { return }

            if self.gameState.communityCards.count < 3 {
                self.gameState.phase = .flop
                self.resetStreetBets()
                self.dealCommunityCards(count: 3)
                self.recordPhaseStartForHH(phase: .flop)
                if !self.isFastForwarding {
                    try? await Task.sleep(nanoseconds: UInt64(self.displayDelaySeconds * 1_000_000_000))
                }
            }
            guard self.currentHandToken == token, !self.tournamentState.isFinished else { return }

            if self.gameState.communityCards.count == 3 {
                self.gameState.phase = .turn
                self.resetStreetBets()
                self.dealCommunityCards(count: 1)
                self.recordPhaseStartForHH(phase: .turn)
                if !self.isFastForwarding {
                    try? await Task.sleep(nanoseconds: UInt64(self.displayDelaySeconds * 1_000_000_000))
                }
            }
            guard self.currentHandToken == token, !self.tournamentState.isFinished else { return }

            if self.gameState.communityCards.count == 4 {
                self.gameState.phase = .river
                self.resetStreetBets()
                self.dealCommunityCards(count: 1)
                self.recordPhaseStartForHH(phase: .river)
                if !self.isFastForwarding {
                    try? await Task.sleep(nanoseconds: UInt64(self.displayDelaySeconds * 1_000_000_000))
                }
            }
            guard self.currentHandToken == token, !self.tournamentState.isFinished else { return }

            self.showdown()
        }

        return true
    }

    private func advanceToNextPlayer() {
        // 使用保存的行动顺序
        guard var currentIdx = gameState.currentActionIndex else {
            advancePhase()
            return
        }

        let actionOrder = gameState.actionOrder
        guard !actionOrder.isEmpty else {
            advancePhase()
            return
        }

        var nextIdx = currentIdx
        var attempts = 0

        // 找到下一个未弃牌的玩家
        while attempts < actionOrder.count {
            nextIdx = (nextIdx + 1) % actionOrder.count
            let nextSeat = actionOrder[nextIdx]
            if let player = gameState.players.first(where: { $0.seatId == nextSeat }),
               !player.isFolded && player.isActive && !player.isAllIn {
                gameState.currentActionIndex = nextIdx
                if let playerIdx = gameState.players.firstIndex(where: { $0.seatId == nextSeat }) {
                    gameState.currentPlayerIndex = playerIdx
                }
                if player.isHuman {
                    // Restore fast-forwarding off if it's a practice mode and human is up
                    if currentMode == .steal || currentMode == .threeBet || currentMode == .defend {
                        isFastForwarding = false
                    }
                    let highestBet = gameState.players.map { $0.currentBet }.max() ?? 0
                    let amountToCall = max(0, highestBet - player.currentBet)
                    gameMessage = amountToCall > 0 ? String(localized: "轮到你（需跟注 \(amountToCall)）") : String(localized: "轮到你")
                } else {
                    gameMessage = String(format: String(localized: "%@ 思考中..."), player.name)
                }

                if !player.isHuman {
                    // 延迟展示，让玩家看清当前玩家的动作
                    let token = currentHandToken
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        if !self.isFastForwarding {
                            try? await Task.sleep(nanoseconds: UInt64(self.displayDelaySeconds * 1_000_000_000))
                        }
                        guard self.currentHandToken == token, !self.isHandFinished, !self.tournamentState.isFinished else { return }
                        self.processAITurn()
                    }
                }
                return
            }
            let skippedPlayer = gameState.players.first(where: { $0.seatId == nextSeat })
            let playerName = skippedPlayer?.name ?? "none"
            let isFolded = skippedPlayer?.isFolded.description ?? "?"
            attempts += 1
        }

        // 所有玩家已行动
        advancePhase()
    }

    // MARK: - 阶段推进

    private func advancePhase() {
        isTimerRunning = false
        gameState.currentPlayerIndex = -1 // 重置当前玩家，防止延迟期间被二次点击

        let currentPhase = gameState.phase
        let nextPhase = gameState.phase.next


        if nextPhase == .showdown {
            showdown()
        } else if nextPhase == .finished {
            endTournament()
        } else {
            gameState.phase = nextPhase
            gameState.lastRaiseAmount = gameState.bbAmount

            // 重置投入
            for i in 0..<gameState.players.count {
                gameState.players[i].currentBet = 0
            }

            // 发公共牌
            if nextPhase == .flop {
                dealCommunityCards(count: 3)
            } else if nextPhase == .turn {
                dealCommunityCards(count: 1)
            } else if nextPhase == .river {
                dealCommunityCards(count: 1)
            }

            recordPhaseStartForHH(phase: nextPhase)

            // 发完牌后延迟一下，让玩家看清公共牌再开始投入
            let token = currentHandToken
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if !self.isFastForwarding {
                    try? await Task.sleep(nanoseconds: UInt64(self.displayDelaySeconds * 1_000_000_000))
                }
                guard self.currentHandToken == token, !self.isHandFinished, !self.tournamentState.isFinished else { return }
                self.startBettingRound()
            }
        }
    }

    private func dealCommunityCards(count: Int) {
        for _ in 0..<count {
            if let card = gameState.deck.draw() {
                gameState.communityCards.append(card)
            }
        }
    }

    // MARK: - 摊牌

    private func showdown() {
        gameState.phase = .showdown
        gameMessage = String(localized: "摊牌！")


        let (distributions, layerWinners) = bettingManager.distributePot(
            players: gameState.players,
            communityCards: gameState.communityCards,
            evaluator: evaluator
        )

        let potOutcomes: [PotOutcome] = layerWinners.map { entry in
            PotOutcome(
                amount: entry.layer.amount,
                eligiblePlayerIds: entry.layer.eligiblePlayerIds,
                winnerIds: entry.winners
            )
        }

        let totalPot = potOutcomes.reduce(0) { $0 + $1.amount }



        // 更新赢家积分
        for dist in distributions {
            if let idx = gameState.players.firstIndex(where: { $0.id == dist.playerId }) {
                let beforeChips = gameState.players[idx].chips
                gameState.players[idx].chips += dist.amount
                if let tIdx = tournamentState.players.firstIndex(where: { $0.id == dist.playerId }) {
                    tournamentState.players[tIdx].chips = gameState.players[idx].chips
                }
            }
        }

        var actualWins: [UUID: Int] = [:]
        var returns: [UUID: Int] = [:]
        var totalPayouts: [UUID: Int] = [:]

        for entry in layerWinners {
            let layer = entry.layer
            let winners = entry.winners
            guard !winners.isEmpty else { continue }
            
            let perWinner = layer.amount / winners.count
            let remainder = layer.amount % winners.count
            
            for (idx, winnerId) in winners.enumerated() {
                let amount = perWinner + (idx < remainder ? 1 : 0)
                totalPayouts[winnerId, default: 0] += amount
                
                // 如果这个彩池只有一个人有资格参与，说明这是他未被跟注的多余积分，属于“退回”
                if layer.eligiblePlayerIds.count == 1 {
                    returns[winnerId, default: 0] += amount
                } else {
                    actualWins[winnerId, default: 0] += amount
                }
            }
        }

        var summaryParts: [String] = []
        
        let winSummary = actualWins
            .sorted { $0.value > $1.value }
            .compactMap { (id, amount) -> String? in
                guard let name = gameState.players.first(where: { $0.id == id })?.name else { return nil }
                return String(localized: "\(name) 赢+\(amount)")
            }
            .joined(separator: "，")
        
        if !winSummary.isEmpty {
            summaryParts.append(winSummary)
        }
        
        let returnSummary = returns
            .sorted { $0.value > $1.value }
            .compactMap { (id, amount) -> String? in
                guard let name = gameState.players.first(where: { $0.id == id })?.name else { return nil }
                return String(localized: "\(name) 退回+\(amount)")
            }
            .joined(separator: "，")
            
        if !returnSummary.isEmpty {
            summaryParts.append(returnSummary)
        }

        gameMessage = summaryParts.isEmpty ? "摊牌结束" : summaryParts.joined(separator: " | ")

        // 导出并结束手牌历史
        var showdownPlayers: [(playerId: UUID, holeCards: [Card], hand: CardCombination)] = []
        for player in gameState.players where !player.isFolded {
            guard let holeCards = player.holeCards else { continue }
            let hand = evaluator.evaluateBestHand(holeCards: holeCards, communityCards: gameState.communityCards)
            showdownPlayers.append((playerId: player.id, holeCards: holeCards, hand: hand))
        }

        AIAgent.shared.recordHandResult(players: gameState.players, payouts: totalPayouts, bbAmount: gameState.bbAmount, gameState: gameState)

        finalizeHandForHH(showdownPlayers: showdownPlayers, potOutcomes: potOutcomes, payouts: totalPayouts)

        let winningIds = totalPayouts.filter { $0.value > 0 }.sorted { $0.value > $1.value }.map { $0.key }
        onHandComplete?(winningIds)

        // 检查淘汰
        checkEliminations()

        // 标记手牌结束，等待用户点击"下一局"按钮或自动开始
        isHandFinished = true
        gameState.currentPlayerIndex = -1

        let hasActiveHuman = tournamentState.players.contains { $0.isHuman && !$0.isEliminated && $0.chips > 0 }
        let activePlayersCount = tournamentState.players.filter { !$0.isEliminated && $0.chips > 0 }.count
        
        if activePlayersCount <= 1 {
            endTournament()
            return
        }

        if !hasActiveHuman && !tournamentState.isFinished {
            let token = currentHandToken
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard self.currentHandToken == token, !self.tournamentState.isFinished else { return }
                self.endTournament()
            }
            return
        }

        if shouldAutoStartNextHand && !tournamentState.isFinished {
            let token = currentHandToken
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                // 停止“自动开下一局”的功能，改为让玩家必须停留在结果画面并手动选择操作
                // 但仍然保持 isFastForwarding 的状态重置逻辑
                if self.isFastForwarding {
                    self.isFastForwarding = false
                }
                
                // 不再自动调用 self.startNewHand()，停在原地
            }
        }

    }

    private func checkEliminations() {
        for i in 0..<tournamentState.players.count {
            if tournamentState.players[i].chips <= 0 && !tournamentState.players[i].isEliminated {
                tournamentState.players[i].isEliminated = true
                tournamentState.players[i].isActive = false
                if let gIdx = gameState.players.firstIndex(where: { $0.seatId == tournamentState.players[i].seatId }) {
                    gameState.players[gIdx].isEliminated = true
                    gameState.players[gIdx].isActive = false
                }
                let placement = tournamentState.players.filter { !$0.isEliminated }.count + 1
                tournamentState.recordElimination(playerId: tournamentState.players[i].id, placement: placement)
                
                if tournamentState.players[i].isHuman && !didRecordHumanTournamentResult && currentMode == .sng6Max {
                    didRecordHumanTournamentResult = true
                    EconomyManager.shared.onTournamentFinished(tournamentId: tournamentState.tournamentId, playerId: tournamentState.players[i].id, rank: placement)
                }
            }
        }
    }

    private func endTournament() {
        gameState.phase = .finished
        tournamentState.isFinished = true

        let totalChips = tournamentState.players.reduce(0) { $0 + $1.chips }
        let missing = tournamentInitialTotalChips - totalChips

        let remaining = tournamentState.players.filter { !$0.isEliminated && $0.chips > 0 }
        if let winner = remaining.first {
            if remaining.count == 1 {
                if missing > 0, let idx = tournamentState.players.firstIndex(where: { $0.id == winner.id }) {
                    tournamentState.players[idx].chips += missing
                    if let gIdx = gameState.players.firstIndex(where: { $0.id == winner.id }) {
                        gameState.players[gIdx].chips = tournamentState.players[idx].chips
                    }
                }

                tournamentState.winnerId = winner.id
                tournamentState.recordElimination(playerId: winner.id, placement: 1)
                gameMessage = String(format: String(localized: "🏆 冠军: %@！"), winner.name)
            } else {
                gameMessage = String(localized: "练习结束")
            }
        }
        
        let humanId = tournamentState.players.first(where: { $0.isHuman })?.id
        let humanRank = tournamentState.rankings[humanId ?? UUID()] ?? 0
        if !didRecordHumanTournamentResult && currentMode == .sng6Max {
            didRecordHumanTournamentResult = true
            EconomyManager.shared.onTournamentFinished(tournamentId: tournamentState.tournamentId, playerId: humanId ?? UUID(), rank: humanRank)
        }
        
        onTournamentComplete?(tournamentState.winnerId)
    }

    // MARK: - AI

    func processAITurn() {
        guard let currentPlayer = gameState.currentPlayer else {
            return
        }

        if currentPlayer.isHuman {
            return
        }

        if !currentPlayer.isActive || currentPlayer.isFolded || currentPlayer.isAllIn {
            currentAITurnToken = nil
            advanceToNextPlayer()
            return
        }

        gameMessage = String(format: String(localized: "%@ 思考中..."), currentPlayer.name)

        let token = currentHandToken
        let seatId = currentPlayer.seatId
        let snapshotPlayer = currentPlayer
        let snapshotGameState = gameState
        let aiTurnToken = UUID()
        currentAITurnToken = aiTurnToken

        Task.detached(priority: .userInitiated) { [weak self, token, seatId, snapshotPlayer, snapshotGameState, aiTurnToken] in
            let mode = await self?.currentMode ?? .sng6Max
            let aiDecision: PlayerAction
            
            if mode == .threeBet && snapshotGameState.phase == .preflop {
                if snapshotPlayer.seatId != snapshotGameState.players.first(where: { $0.isHuman })?.seatId {
                    // AI raises between 3bb and 10bb
                    // The raiseAmount represents the extra amount to put in.
                    // Let's add it to currentBet to get the total bet target.
                    let raiseAmount = snapshotGameState.bbAmount * Int.random(in: 3...10)
                    let targetAmount = snapshotPlayer.currentBet + raiseAmount
                    aiDecision = .raise(amount: targetAmount)
                } else {
                    aiDecision = .fold
                }
            } else if mode == .steal && snapshotGameState.phase == .preflop {
                // All AIs fold until human
                let humanIndex = snapshotGameState.actionOrder.firstIndex(where: { orderSeat in
                    snapshotGameState.players.first(where: { p in p.seatId == orderSeat })?.isHuman == true
                }) ?? 0
                let currentIndex = snapshotGameState.actionOrder.firstIndex(of: snapshotPlayer.seatId) ?? 0
                if currentIndex < humanIndex {
                    aiDecision = .fold
                } else {
                    aiDecision = .fold
                }
            } else if mode == .defend && snapshotGameState.phase == .preflop {
                if snapshotPlayer.position == .sb {
                    let highestBet = snapshotGameState.players.map { $0.currentBet }.max() ?? 0
                    if highestBet <= snapshotGameState.bbAmount {
                        // In Defend Practice, SB raises randomly between 3bb and all-in
                        let maxChips = snapshotPlayer.chips + snapshotPlayer.currentBet
                        let minRaise = snapshotGameState.bbAmount * 3
                        let raiseAmount = Int.random(in: minRaise...maxChips)
                        if raiseAmount >= maxChips {
                            aiDecision = .allIn(amount: maxChips)
                        } else {
                            // Target total amount
                            let targetAmount = snapshotPlayer.currentBet + raiseAmount
                            aiDecision = .raise(amount: targetAmount)
                        }
                    } else {
                        aiDecision = .fold
                    }
                } else {
                    aiDecision = .fold
                }
            } else {
                aiDecision = AIAgent.shared.decideAction(
                    for: snapshotPlayer,
                    gameState: snapshotGameState,
                    evaluator: HandEvaluator.shared
                )
            }

            let highestBet = snapshotGameState.players.map { $0.currentBet }.max() ?? 0
            let validActions = BettingManager.shared.getValidActions(
                  for: snapshotPlayer,
                  highestBet: highestBet,
                  lastRaiseAmount: snapshotGameState.lastRaiseAmount,
                  phase: snapshotGameState.phase,
                  minBet: snapshotGameState.bbAmount,
                  sbAmount: snapshotGameState.sbAmount,
                  bbAmount: snapshotGameState.bbAmount,
                  isFirstBettor: highestBet == 0
            )
            
            let adjusted: PlayerAction
            switch aiDecision {
            case .fold:
                adjusted = validActions.canFold ? .fold : (validActions.canCheck ? .check : (validActions.canCall ? .call(amount: validActions.callAmount) : .allIn(amount: validActions.allInAmount)))
            case .check:
                adjusted = validActions.canCheck ? .check : (validActions.canCall ? .call(amount: validActions.callAmount) : .allIn(amount: validActions.allInAmount))
            case .call:
                adjusted = validActions.canCall ? .call(amount: validActions.callAmount) : (validActions.canCheck ? .check : .allIn(amount: validActions.allInAmount))
            case .bet(let amount):
                if validActions.canBet {
                    let clamped = max(validActions.betAmount, min(amount, validActions.allInAmount))
                    if clamped >= validActions.allInAmount {
                        adjusted = .allIn(amount: validActions.allInAmount)
                    } else {
                        adjusted = .bet(amount: clamped)
                    }
                } else {
                    adjusted = validActions.canCheck ? .check : (validActions.canCall ? .call(amount: validActions.callAmount) : .allIn(amount: validActions.allInAmount))
                }
            case .raise(let amount):
                if validActions.canRaise {
                    // For raise, the amount represents the total bet the player wants to make.
                    // validActions.allInAmount is the player's remaining chips.
                    // The maximum total bet they can make is their currentBet + their remaining chips.
                    let maxTotalBet = snapshotPlayer.currentBet + validActions.allInAmount
                    let clamped = max(validActions.minRaise, min(amount, maxTotalBet))
                    
                    if clamped >= maxTotalBet {
                        adjusted = .allIn(amount: validActions.allInAmount)
                    } else {
                        // For AI decision, .raise(amount) already specifies the total amount.
                        // We clamp it between valid minRaise and maxTotalBet.
                        adjusted = .raise(amount: clamped)
                    }
                } else {
                    // Force the raise to happen in 3Bet and Defend practice mode for AI!
                    if !snapshotPlayer.isHuman && (mode == .threeBet || mode == .defend) {
                        let maxTotalBet = snapshotPlayer.currentBet + validActions.allInAmount
                        if amount >= maxTotalBet {
                            adjusted = .allIn(amount: validActions.allInAmount)
                        } else {
                            adjusted = .raise(amount: min(amount, maxTotalBet))
                        }
                    } else {
                        adjusted = validActions.canCall ? .call(amount: validActions.callAmount) : .allIn(amount: validActions.allInAmount)
                    }
                }
            case .allIn:
                adjusted = .allIn(amount: validActions.allInAmount)
            }

            await MainActor.run {
                guard let self else { return }
                guard self.currentHandToken == token, !self.isHandFinished, !self.tournamentState.isFinished else { return }
                guard self.currentAITurnToken == aiTurnToken else { return }
                guard self.gameState.currentPlayer?.seatId == seatId else { return }
                self.currentAITurnToken = nil
                self.playerAction(adjusted)
            }
        }

        Task { @MainActor [weak self, token, seatId, aiTurnToken] in
            guard let self else { return }
            // ALWAYS wait for timeout. Fast-forwarding should not cause the AI to instantly timeout and fold!
            try? await Task.sleep(nanoseconds: 20_000_000_000)
            
            guard self.currentHandToken == token, !self.isHandFinished, !self.tournamentState.isFinished else { return }
            guard self.currentAITurnToken == aiTurnToken else { return }
            guard let currentPlayer = self.gameState.currentPlayer, !currentPlayer.isHuman, currentPlayer.seatId == seatId else { return }

            let highestBet = self.gameState.players.map { $0.currentBet }.max() ?? 0
            let validActions = self.bettingManager.getValidActions(
                for: currentPlayer,
                highestBet: highestBet,
                lastRaiseAmount: self.gameState.lastRaiseAmount,
                phase: self.gameState.phase,
                minBet: self.gameState.bbAmount,
                sbAmount: self.gameState.sbAmount,
                bbAmount: self.gameState.bbAmount,
                isFirstBettor: highestBet == 0
            )

            let forced: PlayerAction
            if validActions.canCheck {
                forced = .check
            } else if validActions.canFold {
                forced = .fold
            } else if validActions.canCall {
                forced = .call(amount: validActions.callAmount)
            } else if validActions.canAllIn {
                forced = .allIn(amount: validActions.allInAmount)
            } else {
                forced = .check
            }

            self.currentAITurnToken = nil
            
            // Fix: Check if we are fast-forwarding, to decide whether to process this timeout action.
            // If the hand is finished or token mismatch, we don't process.
            guard self.currentHandToken == token, !self.isHandFinished, !self.tournamentState.isFinished else { return }
            
            self.playerAction(forced)
        }
    }

    /// 生成动作结果消息，用于UI显示
    private func actionResultMessage(_ action: PlayerAction, playerName: String, amount: Int, previousHighestBet: Int = 0) -> String {
        switch action {
        case .fold:
            return String(format: String(localized: "%@ 弃牌"), playerName)
        case .check:
            return String(format: String(localized: "%@ 过牌"), playerName)
        case .call:
            return String(format: String(localized: "%@ 跟注 %lld"), playerName, Int64(amount))
        case .bet:
            return String(format: String(localized: "%@ 下注 %lld"), playerName, Int64(amount))
        case .raise:
            // amount 是加注后的 currentBet（总投入额），需要计算增量
            let increment = max(0, amount - previousHighestBet)
            return String(format: String(localized: "%@ 加注 %lld"), playerName, Int64(increment))
        case .allIn:
            return String(format: String(localized: "%@ 全押 %lld"), playerName, Int64(amount))
        }
    }

    // MARK: - 加速/快进
    func fastForwardToEndOfHand() {
        // 如果当前手牌还没结束，或者玩家已经弃牌（等待AI演完）
        guard !isHandFinished else { return }
        
        isFastForwarding = true
        // 取消 shouldAutoStartNextHand 的强制设置，以便结算后停留在结算面板
        shouldAutoStartNextHand = false
        gameMessage = String(localized: "快进中...")
        
        // 我们不需要去重复 processAITurn，只需要清除 token 以打破可能的 Task.sleep 锁定，
        // 并且如果当前确实是 AI 在思考，直接触发下一个回合动作计算
        if let currentPlayer = gameState.currentPlayer, !currentPlayer.isHuman {
            // Cancel any pending AI delay task to prevent double processing
            aiDelayTask?.cancel()
            aiDelayTask = nil
            currentAITurnToken = nil
            
            // Generate a fresh token for this immediate forced turn
            let aiTurnToken = UUID()
            currentAITurnToken = aiTurnToken
            
            Task.detached { [weak self, aiTurnToken] in
                guard let self = self else { return }
                // Call processAITurn directly but ensure we hold the right token
                await MainActor.run {
                    guard self.currentAITurnToken == aiTurnToken else { return }
                    self.processAITurn()
                }
            }
        }
    }

    func timerExpired() {
        if let currentPlayer = gameState.currentPlayer, currentPlayer.isHuman {
            playerAction(.fold)
        }
    }

    // MARK: - 手牌历史集成

    private func setupHandHistory() {
        let handId = "HAND_\(UUID().uuidString)"
        let buttonSeat = tournamentState.buttonSeat

        // 仅在 GameManager 内部保证唯一初始化
        HandHistoryExporter.shared.startNewHand(
            handId: handId,
            sngId: tournamentState.tournamentId.uuidString,
            practiceType: currentMode.rawValue,
            blindLevel: tournamentState.currentLevel,
            sb: tournamentState.currentBlindLevel.sb,
            bb: tournamentState.currentBlindLevel.bb,
            ante: tournamentState.currentBlindLevel.ante,
            buttonPosition: buttonSeat,
            players: gameState.players
        )
    }

    private func recordPhaseStartForHH(phase: GamePhase) {
        HandHistoryExporter.shared.startBettingRound(
            phase: phase,
            communityCards: gameState.communityCards
        )
    }

    private func recordPlayerActionForHH(action: PlayerAction, player: Player, totalInvested: Int) {
        HandHistoryExporter.shared.recordAction(
            playerId: player.id.uuidString,
            seat: player.seatId,
            action: action,
            totalInvested: totalInvested
        )
        
        // 动作发生后，立刻更新内存中的点评数据，这样 UI 上“灯泡”随时能拿得到
        if player.isHuman {
            _ = HandHistoryExporter.shared.getCurrentHandCoachComments()
        }
    }

    private func updateHoleCardsForHH() {
        HandHistoryExporter.shared.updateHoleCards(players: gameState.players)
    }

    private func finalizeHandForHH(
        showdownPlayers: [(playerId: UUID, holeCards: [Card], hand: CardCombination)],
        potOutcomes: [PotOutcome],
        payouts: [UUID: Int]
    ) {
        HandHistoryExporter.shared.recordHandEnd(
            showdownPlayers: showdownPlayers,
            potOutcomes: potOutcomes,
            payouts: payouts,
            playersAfter: gameState.players
        )
        // 只要这手牌打完，立即保存，不需要等下一次 startNewHand
        // 这样在练习结束时（没有下一局）也能在列表看到最新的这手牌记录
        HandHistoryExporter.shared.saveCurrentHand()
    }
}
