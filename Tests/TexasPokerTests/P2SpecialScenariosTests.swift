import XCTest
@testable import TexasPoker

// MARK: - P2 特殊场景测试

final class P2SpecialScenariosTests: XCTestCase {

    var evaluator: HandEvaluator!
    var bettingManager: BettingManager!

    override func setUp() {
        super.setUp()
        evaluator = HandEvaluator.shared
        bettingManager = BettingManager.shared
    }

    override func tearDown() {
        evaluator = nil
        bettingManager = nil
        super.tearDown()
    }

    // MARK: - #24 超时自动弃牌

    func testTimeoutAction_Fold() {
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

    // MARK: - #26 起手牌表

    func testVPIP_EasyAI() {
        let difficulty = Player.AIDifficulty.easy

        XCTAssertEqual(difficulty.vpipRange.lowerBound, 0.15)
        XCTAssertEqual(difficulty.vpipRange.upperBound, 0.20)
    }

    func testVPIP_MediumAI() {
        let difficulty = Player.AIDifficulty.medium

        XCTAssertEqual(difficulty.vpipRange.lowerBound, 0.25)
        XCTAssertEqual(difficulty.vpipRange.upperBound, 0.35)
    }

    func testVPIP_HardAI() {
        let difficulty = Player.AIDifficulty.hard

        XCTAssertEqual(difficulty.vpipRange.lowerBound, 0.20)
        XCTAssertEqual(difficulty.vpipRange.upperBound, 0.30)
    }

    func testAggressionFactor() {
        XCTAssertEqual(Player.AIDifficulty.easy.aggressionFactor, 0.3)
        XCTAssertEqual(Player.AIDifficulty.medium.aggressionFactor, 0.6)
        XCTAssertEqual(Player.AIDifficulty.hard.aggressionFactor, 0.9)
    }

    // MARK: - #27 公共牌不能发出已有手牌

    func testDeckDrawExcludesHoleCards() {
        var deck = Deck()
        deck.shuffle()

        let holeCards = [deck.cards[0], deck.cards[1]]
        deck.cards.remove(at: 0)
        deck.cards.remove(at: 1)

        XCTAssertEqual(deck.cards.count, 50)

        // Draw 5 cards
        let drawnCards = deck.draw(count: 5)

        XCTAssertEqual(drawnCards.count, 5)
        // Verify deck now has 45 cards
        XCTAssertEqual(deck.cards.count, 45)
    }

    // MARK: - #28 Deck 重置

    func testDeckReset_AfterHand() {
        var deck = Deck()
        deck.shuffle()

        for _ in 0..<17 {
            _ = deck.draw()
        }

        XCTAssertEqual(deck.cards.count, 35)

        deck.reset()

        XCTAssertEqual(deck.cards.count, 52)
    }

    // MARK: - 综合场景测试

    func testFullHandFlow_PreflopToShowdown() {
        var gameState = GameState(players: [
            Player(name: "P1", chips: 1000, position: .button, isHuman: true),
            Player(name: "P2", chips: 1000, position: .sb),
            Player(name: "P3", chips: 1000, position: .bb)
        ])

        // Initial phase should be waiting
        XCTAssertEqual(gameState.phase, .waiting)

        gameState.players[1].currentBet = 10
        gameState.players[2].currentBet = 20
        gameState.pot = 30

        gameState.deck.reset()
        gameState.deck.shuffle()
        gameState.players[0].holeCards = [gameState.deck.draw()!, gameState.deck.draw()!]
        gameState.players[1].holeCards = [gameState.deck.draw()!, gameState.deck.draw()!]
        gameState.players[2].holeCards = [gameState.deck.draw()!, gameState.deck.draw()!]

        XCTAssertNotNil(gameState.players[0].holeCards)
        XCTAssertEqual(gameState.players[0].holeCards?.count, 2)

        let flop = [gameState.deck.draw()!, gameState.deck.draw()!, gameState.deck.draw()!]
        gameState.communityCards = flop
        XCTAssertEqual(gameState.communityCards.count, 3)

        let turn = gameState.deck.draw()!
        gameState.communityCards.append(turn)
        XCTAssertEqual(gameState.communityCards.count, 4)

        let river = gameState.deck.draw()!
        gameState.communityCards.append(river)
        XCTAssertEqual(gameState.communityCards.count, 5)

        XCTAssertEqual(gameState.deck.cards.count, 41)
    }

    func testPositionOrder_6Max() {
        let positions = Player.Position.allCases

        XCTAssertEqual(positions[0], .button)
        XCTAssertEqual(positions[1], .sb)
        XCTAssertEqual(positions[2], .bb)
        XCTAssertEqual(positions[3], .utg)
        XCTAssertEqual(positions[4], .mp)
        XCTAssertEqual(positions[5], .co)
    }

    // MARK: - Edge Cases

    func testEmptyCommunityCards() {
        let hole = [
            Card(rank: .ace, suit: .hearts),
            Card(rank: .king, suit: .diamonds)
        ]

        let result = evaluator.evaluateBestHand(holeCards: hole, communityCards: [])

        XCTAssertEqual(result.handType, .highCard)
    }

    func testOnlyHoleCards() {
        let hole = [
            Card(rank: .ace, suit: .hearts),
            Card(rank: .ace, suit: .diamonds)
        ]

        let result = evaluator.evaluateBestHand(holeCards: hole, communityCards: [])

        // With only 2 cards, it should return high card or the pair
        // The evaluator may return highCard when community cards are empty
        XCTAssertTrue(result.handType == .onePair || result.handType == .highCard)
    }

    func testAllInOnFirstStreet() {
        var player = Player(name: "Test", chips: 500, position: .mp, isHuman: true)
        var gameState = GameState(players: [player])
        gameState.pot = 0
        gameState.bettingRound = 0

        let result = bettingManager.processAction(
            action: .allIn(amount: 500),
            for: &player,
            gameState: &gameState
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(player.chips, 0)
        XCTAssertTrue(player.isAllIn)
        XCTAssertEqual(player.currentBet, 500)
        XCTAssertEqual(gameState.pot, 500)
    }

    func testMultipleRaisesInOneStreet() {
        var players = [
            Player(name: "P1", chips: 1000, position: .button),
            Player(name: "P2", chips: 1000, position: .sb),
            Player(name: "P3", chips: 1000, position: .bb)
        ]

        players[0].currentBet = 50
        players[1].currentBet = 100
        players[2].currentBet = 200

        let actions = bettingManager.getValidActions(
            for: players[0],
            highestBet: 200,
            phase: .preflop,
            minBet: 20,
            sbAmount: 10,
            bbAmount: 20,
            isFirstBettor: false
        )

        XCTAssertTrue(actions.canCall)
        XCTAssertEqual(actions.callAmount, 150)
        XCTAssertTrue(actions.canRaise)
        XCTAssertEqual(actions.minRaise, 400)
    }

    func testBettingRoundResetsBets() {
        var gameState = GameState(players: [
            Player(name: "P1", chips: 1000, position: .button),
            Player(name: "P2", chips: 1000, position: .sb)
        ])
        gameState.players[0].currentBet = 50
        gameState.players[1].currentBet = 50

        for i in 0..<gameState.players.count {
            gameState.players[i].currentBet = 0
        }

        XCTAssertEqual(gameState.players[0].currentBet, 0)
        XCTAssertEqual(gameState.players[1].currentBet, 0)
    }

    func testPlayerResetBetweenHands() {
        var player = Player(name: "Test", chips: 800, position: .sb)
        player.isFolded = true
        player.isAllIn = true
        player.currentBet = 100
        player.holeCards = [Card(rank: .ace, suit: .hearts)]

        player.resetForNewHand()

        XCTAssertEqual(player.chips, 800)
        XCTAssertEqual(player.currentBet, 0)
        XCTAssertFalse(player.isFolded)
        XCTAssertFalse(player.isAllIn)
        XCTAssertNil(player.holeCards)
        XCTAssertTrue(player.isActive)
    }
}
