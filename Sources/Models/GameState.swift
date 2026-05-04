import Foundation

// MARK: - Game Phase

enum GamePhase: String, Codable {
    case waiting = "等待开始"
    case preflop = "发牌前"
    case flop = "翻牌"
    case turn = "转牌"
    case river = "河牌"
    case showdown = "摊牌"
    case finished = "比赛结束"

    var next: GamePhase {
        switch self {
        case .waiting: return .preflop
        case .preflop: return .flop
        case .flop: return .turn
        case .turn: return .river
        case .river: return .showdown
        case .showdown, .finished: return .finished
        }
    }
}

// MARK: - Betting Round State

struct BettingRound {
    var currentPlayerIndex: Int
    var bets: [UUID: Int] = [:]  // player id -> bet amount
    var highestBet: Int = 0
    var isComplete: Bool = false
    var numberOfCalls: Int = 0
    var hasRaised: Bool = false

    mutating func reset() {
        currentPlayerIndex = 0
        bets.removeAll()
        highestBet = 0
        isComplete = false
        numberOfCalls = 0
        hasRaised = false
    }
}

// MARK: - Game State

struct GameState {
    var phase: GamePhase
    var communityCards: [Card]
    var pot: Int
    var mainPot: Int
    var sidePots: [Int]
    var currentPlayerIndex: Int
    var bettingRound: Int
    var deck: Deck
    var players: [Player]
    var buttonPosition: Int  // 按钮所在的物理座位号 (0-5)
    var actionOrder: [Int]  // 当前投入轮的行动顺序，按座位号排序
    var currentActionIndex: Int?  // 当前行动者在actionOrder中的索引
    var sbAmount: Int
    var bbAmount: Int
    var anteAmount: Int
    var level: Int
    var playersRequiredToCall: Int
    var actionHistory: [ActionRecord]
    var lastRaiseAmount: Int
    var isAllInRunout: Bool

    struct ActionRecord {
        let playerId: UUID
        let action: PlayerAction
        let phase: GamePhase
        let bettingRound: Int
        let timestamp: Date
    }

    init(
        players: [Player],
        sbAmount: Int = 10,
        bbAmount: Int = 20,
        anteAmount: Int = 0
    ) {
        self.phase = .waiting
        self.communityCards = []
        self.pot = 0
        self.mainPot = 0
        self.sidePots = []
        self.currentPlayerIndex = 0
        self.bettingRound = 0
        self.deck = Deck()
        self.players = players
        self.buttonPosition = 1  // 默认为座位1
        self.actionOrder = []
        self.currentActionIndex = nil
        self.sbAmount = sbAmount
        self.bbAmount = bbAmount
        self.anteAmount = anteAmount
        self.level = 1
        self.playersRequiredToCall = 0
        self.actionHistory = []
        self.lastRaiseAmount = bbAmount
        self.isAllInRunout = false
    }

    var activePlayers: [Player] {
        players.filter { $0.isActive && !$0.isFolded }
    }

    var activePlayerCount: Int {
        activePlayers.count
    }

    var isHeadsUp: Bool {
        activePlayerCount == 2
    }

    var currentPlayer: Player? {
        guard currentPlayerIndex >= 0 && currentPlayerIndex < players.count else { return nil }
        return players[currentPlayerIndex]
    }

    mutating func nextPlayer() {
        currentPlayerIndex = (currentPlayerIndex + 1) % players.count
    }

    mutating func rotateButton() {
        buttonPosition = (buttonPosition + 1) % players.count
    }

    mutating func resetForNewHand() {
        phase = .preflop
        communityCards = []
        pot = 0
        mainPot = 0
        sidePots = []
        bettingRound = 0
        deck.reset()
        deck.shuffle()
        currentPlayerIndex = 0
        actionHistory = []
        actionOrder = []
        currentActionIndex = nil
        lastRaiseAmount = bbAmount

        for i in 0..<players.count {
            players[i].resetForNewHand()
        }
    }
}

// MARK: - Tournament State

struct TournamentState: Codable {
    var tournamentId: UUID
    var players: [Player]
    var currentLevel: Int
    var levelStartTime: Date
    var blindSchedule: [BlindLevel]
    var payouts: [Double]
    var isFinished: Bool
    var rankings: [UUID: Int]  // player id -> placement
    var winnerId: UUID?
    var buttonSeat: Int  // 按钮所在的物理座位号 (0-5)，每局结束后顺时针移动

    struct BlindLevel: Codable {
        let level: Int
        let sb: Int
        let bb: Int
        let ante: Int
        let durationMinutes: Int
    }

    static let defaultBlindSchedule: [BlindLevel] = [
        BlindLevel(level: 1, sb: 10, bb: 20, ante: 0, durationMinutes: 3),
        BlindLevel(level: 2, sb: 15, bb: 30, ante: 0, durationMinutes: 3),
        BlindLevel(level: 3, sb: 25, bb: 50, ante: 0, durationMinutes: 3),
        BlindLevel(level: 4, sb: 50, bb: 100, ante: 10, durationMinutes: 3),
        BlindLevel(level: 5, sb: 75, bb: 150, ante: 15, durationMinutes: 3),
        BlindLevel(level: 6, sb: 100, bb: 200, ante: 25, durationMinutes: 3),
        BlindLevel(level: 7, sb: 150, bb: 300, ante: 40, durationMinutes: 3),
        BlindLevel(level: 8, sb: 200, bb: 400, ante: 50, durationMinutes: 3),
    ]

    static let defaultPayouts: [Double] = [0.50, 0.30, 0.20]

    init(players: [Player]) {
        self.tournamentId = UUID()
        self.players = players
        self.currentLevel = 1
        self.levelStartTime = Date()
        self.blindSchedule = TournamentState.defaultBlindSchedule
        self.payouts = TournamentState.defaultPayouts
        self.isFinished = false
        self.rankings = [:]
        self.winnerId = nil
        self.buttonSeat = 1  // 初始按钮在座位1
    }

    var currentBlindLevel: BlindLevel {
        blindSchedule.first { $0.level == currentLevel } ?? blindSchedule.last!
    }

    var timeUntilNextLevel: TimeInterval {
        let levelDuration = TimeInterval(currentBlindLevel.durationMinutes * 60)
        return max(0, levelStartTime.addingTimeInterval(levelDuration).timeIntervalSinceNow)
    }

    mutating func advanceLevel() {
        if currentLevel < blindSchedule.count {
            currentLevel += 1
            levelStartTime = Date()
        }
    }

    mutating func recordElimination(playerId: UUID, placement: Int) {
        rankings[playerId] = placement
    }
}
