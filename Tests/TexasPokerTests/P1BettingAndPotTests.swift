import XCTest
@testable import TexasPoker

// MARK: - P1 下注逻辑测试

final class P1BettingAndPotTests: XCTestCase {

    var bettingManager: BettingManager!

    override func setUp() {
        super.setUp()
        bettingManager = BettingManager.shared
    }

    override func tearDown() {
        bettingManager = nil
        super.tearDown()
    }

    // MARK: - #6 最小加注

    func testMinRaise_FirstBettorIsBB() {
        var player = Player(name: "Test", chips: 1000, position: .button, isHuman: true)

        let actions = bettingManager.getValidActions(
            for: player,
            highestBet: 0,
            phase: .preflop,
            minBet: 20,
            sbAmount: 10,
            bbAmount: 20,
            isFirstBettor: true
        )

        XCTAssertTrue(actions.canBet)
        XCTAssertEqual(actions.betAmount, 20)
    }

    func testMinRaise_AfterBet() {
        var player = Player(name: "Test", chips: 1000, position: .mp, isHuman: true)
        player.currentBet = 30

        let actions = bettingManager.getValidActions(
            for: player,
            highestBet: 50,
            phase: .preflop,
            minBet: 20,
            sbAmount: 10,
            bbAmount: 20,
            isFirstBettor: false
        )

        // Player needs to call 20 more
        XCTAssertTrue(actions.canCall)
        XCTAssertEqual(actions.callAmount, 20)
    }

    // MARK: - #7 跟注金额

    func testCallAmount_ExactCall() {
        var player = Player(name: "Test", chips: 1000, position: .mp, isHuman: true)
        player.currentBet = 30

        let actions = bettingManager.getValidActions(
            for: player,
            highestBet: 50,
            phase: .preflop,
            minBet: 20,
            sbAmount: 10,
            bbAmount: 20,
            isFirstBettor: false
        )

        XCTAssertTrue(actions.canCall)
        XCTAssertEqual(actions.callAmount, 20)
    }

    // MARK: - #8 全下

    func testAllIn_PlayerChipsZero() {
        var player = Player(name: "Test", chips: 0, position: .mp, isHuman: true)

        let actions = bettingManager.getValidActions(
            for: player,
            highestBet: 100,
            phase: .preflop,
            minBet: 20,
            sbAmount: 10,
            bbAmount: 20,
            isFirstBettor: false
        )

        XCTAssertFalse(actions.canAllIn)
    }

    // MARK: - #9 首轮下注（大盲位）

    func testBB_Preflop_NoRaiseYet() {
        var player = Player(name: "BB", chips: 980, position: .bb, isHuman: true)
        player.currentBet = 20

        let actions = bettingManager.getValidActions(
            for: player,
            highestBet: 20,
            phase: .preflop,
            minBet: 20,
            sbAmount: 10,
            bbAmount: 20,
            isFirstBettor: false
        )

        XCTAssertTrue(actions.canCheck)
    }

    // MARK: - #10 过牌/下注 验证

    func testCannotCheck_WhenBetsExist() {
        var player = Player(name: "Test", chips: 1000, position: .mp, isHuman: true)
        player.currentBet = 20

        let actions = bettingManager.getValidActions(
            for: player,
            highestBet: 50,
            phase: .flop,
            minBet: 20,
            sbAmount: 10,
            bbAmount: 20,
            isFirstBettor: false
        )

        XCTAssertFalse(actions.canCheck)
        XCTAssertTrue(actions.canCall)
    }

    func testCanCheck_WhenNoBet() {
        var player = Player(name: "Test", chips: 1000, position: .button, isHuman: true)
        player.currentBet = 50

        let actions = bettingManager.getValidActions(
            for: player,
            highestBet: 50,
            phase: .flop,
            minBet: 20,
            sbAmount: 10,
            bbAmount: 20,
            isFirstBettor: false
        )

        XCTAssertTrue(actions.canCheck)
        XCTAssertFalse(actions.canCall)
    }

    // MARK: - #11 弃牌后状态

    func testFold_PlayerIsFolded() {
        var player = Player(name: "Test", chips: 1000, position: .mp, isHuman: true)
        var gameState = GameState(players: [player])
        gameState.pot = 50
        gameState.bettingRound = 1

        let result = bettingManager.processAction(
            action: .fold,
            for: &player,
            gameState: &gameState
        )

        XCTAssertTrue(result.success)
        XCTAssertTrue(player.isFolded)
    }

    // MARK: - #12 边池分配

    func testSidePot_BasicAllIn() {
        var players = [
            Player(name: "P1", chips: 0, position: .button),
            Player(name: "P2", chips: 400, position: .sb),
            Player(name: "P3", chips: 400, position: .bb)
        ]
        players[0].currentBet = 100
        players[1].currentBet = 100
        players[2].currentBet = 100

        let mainPot = bettingManager.calculateMainPot(players: players, highestBet: 100)
        XCTAssertEqual(mainPot, 300)
    }

    // MARK: - #15 按钮位旋转

    func testButtonRotation_AfterHand() {
        var gameState = GameState(players: [
            Player(name: "P1", chips: 1000, position: .button),
            Player(name: "P2", chips: 1000, position: .sb),
            Player(name: "P3", chips: 1000, position: .bb),
            Player(name: "P4", chips: 1000, position: .utg),
            Player(name: "P5", chips: 1000, position: .mp),
            Player(name: "P6", chips: 1000, position: .co)
        ])
        gameState.buttonPosition = 0

        gameState.rotateButton()

        XCTAssertEqual(gameState.buttonPosition, 1)
    }

    func testButtonRotation_FullCycle() {
        var gameState = GameState(players: [
            Player(name: "P1", chips: 1000, position: .button),
            Player(name: "P2", chips: 1000, position: .sb),
            Player(name: "P3", chips: 1000, position: .bb),
            Player(name: "P4", chips: 1000, position: .utg),
            Player(name: "P5", chips: 1000, position: .mp),
            Player(name: "P6", chips: 1000, position: .co)
        ])

        for _ in 0..<6 {
            gameState.rotateButton()
        }

        XCTAssertEqual(gameState.buttonPosition, 0)
    }

    // MARK: - #16 第一行动顺序

    func testPositionOrder_6Max() {
        let positions = Player.Position.allCases

        XCTAssertEqual(positions[0], .button)
        XCTAssertEqual(positions[1], .sb)
        XCTAssertEqual(positions[2], .bb)
        XCTAssertEqual(positions[3], .utg)
        XCTAssertEqual(positions[4], .mp)
        XCTAssertEqual(positions[5], .co)
    }

    // MARK: - #19 盲注升级

    func testBlindLevelIncrease() {
        let players = [
            Player(name: "P1", chips: 1000, position: .button),
            Player(name: "P2", chips: 1000, position: .sb),
            Player(name: "P3", chips: 1000, position: .bb)
        ]
        var tournament = TournamentState(players: players)
        tournament.currentLevel = 3

        XCTAssertEqual(tournament.currentBlindLevel.sb, 25)
        XCTAssertEqual(tournament.currentBlindLevel.bb, 50)

        tournament.advanceLevel()
        XCTAssertEqual(tournament.currentBlindLevel.sb, 50)
        XCTAssertEqual(tournament.currentBlindLevel.bb, 100)
    }

    // MARK: - #20 Ante 引入

    func testAnteStartsAtLevel4() {
        let players = [
            Player(name: "P1", chips: 1000, position: .button),
            Player(name: "P2", chips: 1000, position: .sb),
            Player(name: "P3", chips: 1000, position: .bb)
        ]
        let tournament = TournamentState(players: players)

        XCTAssertEqual(tournament.blindSchedule[2].ante, 0)
        XCTAssertEqual(tournament.blindSchedule[3].ante, 10)
    }

    // MARK: - #21 淘汰判定

    func testElimination_WhenChipsZero() {
        let player = Player(name: "Test", chips: 0, position: .bb)

        XCTAssertTrue(player.isEliminated)
        XCTAssertFalse(player.canBet)
    }

    // MARK: - #22 奖励分配

    func testPayout_6MaxSNG() {
        let players = [
            Player(name: "P1", chips: 0, position: .button),
            Player(name: "P2", chips: 0, position: .sb),
            Player(name: "P3", chips: 0, position: .bb)
        ]
        let tournament = TournamentState(players: players)

        XCTAssertEqual(tournament.payouts.count, 3)
        XCTAssertEqual(tournament.payouts[0], 0.50)
        XCTAssertEqual(tournament.payouts[1], 0.30)
        XCTAssertEqual(tournament.payouts[2], 0.20)
    }

    // MARK: - #23 决赛桌定义

    func testFinalTable_3PlayersRemain() {
        let players = [
            Player(name: "P1", chips: 500, position: .button),
            Player(name: "P2", chips: 300, position: .sb),
            Player(name: "P3", chips: 200, position: .bb),
            Player(name: "P4", chips: 0, position: .utg),
            Player(name: "P5", chips: 0, position: .mp),
            Player(name: "P6", chips: 0, position: .co)
        ]

        let remaining = players.filter { !$0.isEliminated }
        XCTAssertEqual(remaining.count, 3)
    }

    // MARK: - #27 公共牌发牌（无重复）

    func testNoDuplicateCards() {
        var deck = Deck()

        var drawnCards: [Card] = []
        for _ in 0..<52 {
            if let card = deck.draw() {
                drawnCards.append(card)
            }
        }

        let uniqueCards = Set(drawnCards.map { "\($0.rank)\($0.suit)" })
        XCTAssertEqual(uniqueCards.count, 52)
    }

    func testDeckHas52Cards() {
        var deck = Deck()
        XCTAssertEqual(deck.cards.count, 52)
    }

    func testDeckReset() {
        var deck = Deck()
        deck.shuffle()

        for _ in 0..<10 {
            _ = deck.draw()
        }

        XCTAssertEqual(deck.cards.count, 42)

        deck.reset()

        XCTAssertEqual(deck.cards.count, 52)
    }
}
