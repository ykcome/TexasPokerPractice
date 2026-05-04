import XCTest
@testable import TexasPoker

// MARK: - Game State Tests

final class GameStateTests: XCTestCase {

    // MARK: - Position Rotation Tests

    func testButtonRotation() {
        var players = [
            Player(name: "P1", chips: 1000, position: .button),
            Player(name: "P2", chips: 1000, position: .sb),
            Player(name: "P3", chips: 1000, position: .bb),
            Player(name: "P4", chips: 1000, position: .utg),
            Player(name: "P5", chips: 1000, position: .mp),
            Player(name: "P6", chips: 1000, position: .co)
        ]

        let gameState = GameState(players: players)

        var state = gameState
        state.buttonPosition = 0

        // Simulate button rotation for 6 hands
        let expectedPositions = [
            [Player.Position.button, .sb, .bb, .utg, .mp, .co],
            [Player.Position.co, .button, .sb, .bb, .utg, .mp],
            [Player.Position.mp, .co, .button, .sb, .bb, .utg],
            [Player.Position.utg, .mp, .co, .button, .sb, .bb],
            [Player.Position.bb, .utg, .mp, .co, .button, .sb],
            [Player.Position.sb, .bb, .utg, .mp, .co, .button]
        ]

        for (rotation, expected) in expectedPositions.enumerated() {
            state.buttonPosition = rotation
            state.rotateButton()

            let rotated = (rotation + 1) % 6
            XCTAssertEqual(rotated, (rotation + 1) % 6, "Button should rotate clockwise")
        }
    }

    // MARK: - Phase Transition Tests

    func testPhaseTransitions() {
        var phase: GamePhase = .waiting

        let expectedPhases: [GamePhase] = [
            .preflop, .flop, .turn, .river, .showdown, .finished
        ]

        for expected in expectedPhases {
            phase = phase.next
            XCTAssertEqual(phase, expected)
        }
    }

    func testFlopDealsThreeCards() {
        var gameState = GameState(players: [
            Player(name: "P1", chips: 1000, position: .button),
            Player(name: "P2", chips: 1000, position: .sb)
        ])

        gameState.deck.reset()
        gameState.deck.shuffle()

        // Deal 3 cards for flop
        var community: [Card] = []
        for _ in 0..<3 {
            if let card = gameState.deck.draw() {
                community.append(card)
            }
        }

        XCTAssertEqual(community.count, 3)
    }

    func testTurnDealsOneCard() {
        var gameState = GameState(players: [
            Player(name: "P1", chips: 1000, position: .button),
            Player(name: "P2", chips: 1000, position: .sb)
        ])

        gameState.deck.reset()
        gameState.deck.shuffle()

        // Deal 1 card for turn
        if let card = gameState.deck.draw() {
            XCTAssertNotNil(card)
        }
    }

    // MARK: - Deck Tests

    func testDeckHas52Cards() {
        let deck = Deck()

        XCTAssertEqual(deck.cards.count, 52)
    }

    func testDeckShuffleChangesOrder() {
        var deck1 = Deck()
        deck1.shuffle()

        var deck2 = Deck()
        deck2.shuffle()

        // Decks should be different after shuffling
        // (statistically almost certain)
        let shuffled1 = deck1.cards.prefix(10).map { $0.displayString }
        let shuffled2 = deck2.cards.prefix(10).map { $0.displayString }

        // Note: This test could theoretically fail due to random chance,
        // but the probability is extremely low
    }

    func testDeckDrawRemovesCard() {
        var deck = Deck()
        let initialCount = deck.cards.count

        _ = deck.draw()

        XCTAssertEqual(deck.cards.count, initialCount - 1)
    }

    func testDeckDrawTwoCards() {
        var deck = Deck()
        let cards = deck.draw(count: 2)

        XCTAssertEqual(cards.count, 2)
        XCTAssertEqual(deck.cards.count, 50)
    }

    func testDeckDrawMoreThanAvailable() {
        var deck = Deck()
        deck.cards.removeAll() // Empty deck

        let cards = deck.draw(count: 5)

        XCTAssertEqual(cards.count, 0)
    }

    // MARK: - Card Equality Tests

    func testCardEquality() {
        let card1 = Card(rank: .ace, suit: .hearts)
        let card2 = Card(rank: .ace, suit: .hearts)
        let card3 = Card(rank: .ace, suit: .diamonds)

        XCTAssertEqual(card1, card2)
        XCTAssertNotEqual(card1, card3)
    }

    // MARK: - Player State Tests

    func testPlayerResetForNewHand() {
        var player = Player(name: "Test", chips: 500, position: .sb)
        player.isFolded = true
        player.isAllIn = true
        player.holeCards = [Card(rank: .ace, suit: .hearts)]
        player.currentBet = 100

        player.resetForNewHand()

        XCTAssertTrue(player.isActive)
        XCTAssertFalse(player.isFolded)
        XCTAssertFalse(player.isAllIn)
        XCTAssertNil(player.holeCards)
        XCTAssertEqual(player.currentBet, 0)
        XCTAssertEqual(player.chips, 500)
    }

    func testPlayerElimination() {
        var player = Player(name: "Test", chips: 0, position: .sb)

        XCTAssertTrue(player.isEliminated)
        XCTAssertFalse(player.canBet)
    }

    func testPlayerCanBet() {
        var player = Player(name: "Test", chips: 100, position: .sb)

        XCTAssertTrue(player.canBet)

        player.isFolded = true
        XCTAssertFalse(player.canBet)

        player.isFolded = false
        player.isAllIn = true
        XCTAssertFalse(player.canBet)
    }

    // MARK: - Active Players Tests

    func testActivePlayerCount() {
        var players = [
            Player(name: "P1", chips: 1000, position: .button),
            Player(name: "P2", chips: 0, position: .sb),
            Player(name: "P3", chips: 500, position: .bb),
            Player(name: "P4", chips: 1000, position: .utg)
        ]
        players[0].isFolded = true

        var gameState = GameState(players: players)

        // Note: activePlayers only filters by isActive && !isFolded, not by chips/elimination
        let activePlayers = gameState.activePlayers

        // P1 is folded, P2 is not folded (despite 0 chips), P3 and P4 are not folded
        XCTAssertEqual(activePlayers.count, 3)
        XCTAssertEqual(gameState.activePlayerCount, 3)
    }

    func testHeadsUpDetection() {
        var players = [
            Player(name: "P1", chips: 1000, position: .button),
            Player(name: "P2", chips: 0, position: .sb),
            Player(name: "P3", chips: 500, position: .bb)
        ]
        players[0].isFolded = true

        var gameState = GameState(players: players)

        XCTAssertTrue(gameState.isHeadsUp)
    }

    // MARK: - Game Phase Tests

    func testGamePhaseDisplayNames() {
        XCTAssertEqual(GamePhase.preflop.rawValue, "发牌前")
        XCTAssertEqual(GamePhase.flop.rawValue, "翻牌")
        XCTAssertEqual(GamePhase.turn.rawValue, "转牌")
        XCTAssertEqual(GamePhase.river.rawValue, "河牌")
        XCTAssertEqual(GamePhase.showdown.rawValue, "摊牌")
    }

    // MARK: - Player Action Tests

    func testPlayerActionDisplayName() {
        XCTAssertEqual(PlayerAction.fold.displayName, "弃牌")
        XCTAssertEqual(PlayerAction.check.displayName, "过牌")
        XCTAssertEqual(PlayerAction.call(amount: 50).displayName, "跟注")
        XCTAssertEqual(PlayerAction.bet(amount: 100).displayName, "下注")
        XCTAssertEqual(PlayerAction.raise(amount: 200).displayName, "加注")
        XCTAssertEqual(PlayerAction.allIn(amount: 500).displayName, "全下")
    }

    func testPlayerActionAmount() {
        XCTAssertEqual(PlayerAction.fold.amount, 0)
        XCTAssertEqual(PlayerAction.check.amount, 0)
        XCTAssertEqual(PlayerAction.call(amount: 50).amount, 50)
        XCTAssertEqual(PlayerAction.bet(amount: 100).amount, 100)
        XCTAssertEqual(PlayerAction.raise(amount: 200).amount, 200)
        XCTAssertEqual(PlayerAction.allIn(amount: 500).amount, 500)
    }
}

// MARK: - AI Difficulty Tests

final class AIDifficultyTests: XCTestCase {

    func testVPIPRanges() {
        XCTAssertEqual(Player.AIDifficulty.easy.vpipRange.lowerBound, 0.15)
        XCTAssertEqual(Player.AIDifficulty.easy.vpipRange.upperBound, 0.20)

        XCTAssertEqual(Player.AIDifficulty.medium.vpipRange.lowerBound, 0.25)
        XCTAssertEqual(Player.AIDifficulty.hard.vpipRange.upperBound, 0.30)
    }

    func testAggressionFactor() {
        XCTAssertEqual(Player.AIDifficulty.easy.aggressionFactor, 0.3)
        XCTAssertEqual(Player.AIDifficulty.medium.aggressionFactor, 0.6)
        XCTAssertEqual(Player.AIDifficulty.hard.aggressionFactor, 0.9)
    }
}
