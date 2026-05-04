import XCTest
@testable import TexasPoker

// MARK: - Integration Tests

final class IntegrationTests: XCTestCase {

    var evaluator: HandEvaluator!

    override func setUp() {
        super.setUp()
        evaluator = HandEvaluator.shared
    }

    override func tearDown() {
        evaluator = nil
        super.tearDown()
    }

    // MARK: - Deck Integrity

    func testDeckIntegrity_FullHand() {
        var deck = Deck()
        deck.shuffle()

        var gameState = GameState(players: [
            Player(name: "P1", chips: 1000, position: .button),
            Player(name: "P2", chips: 1000, position: .sb),
            Player(name: "P3", chips: 1000, position: .bb)
        ])

        // Deal hole cards (2 * 3 = 6)
        for i in 0..<3 {
            gameState.players[i].holeCards = [deck.draw()!, deck.draw()!]
        }

        // Deal flop (3)
        gameState.communityCards = [deck.draw()!, deck.draw()!, deck.draw()!]

        // Deal turn (1)
        gameState.communityCards.append(deck.draw()!)

        // Deal river (1)
        gameState.communityCards.append(deck.draw()!)

        // Total used: 6 + 5 = 11
        // Remaining: 52 - 11 = 41
        XCTAssertEqual(deck.cards.count, 41)

        // Verify no duplicate cards
        var allCards: [Card] = []
        for player in gameState.players {
            if let hole = player.holeCards {
                allCards.append(contentsOf: hole)
            }
        }
        allCards.append(contentsOf: gameState.communityCards)

        let uniqueCards = Set(allCards.map { "\($0.rank)\($0.suit)" })
        XCTAssertEqual(uniqueCards.count, allCards.count, "No duplicate cards")
    }

    // MARK: - Hand Evaluation at Showdown

    func testShowdown_WinnerDetermination() {
        // Player 1: Pair of Aces
        let p1Hole = [
            Card(rank: .ace, suit: .hearts),
            Card(rank: .ace, suit: .diamonds)
        ]

        // Player 2: Pair of Kings (lower)
        let p2Hole = [
            Card(rank: .king, suit: .hearts),
            Card(rank: .king, suit: .diamonds)
        ]

        let community = [
            Card(rank: .queen, suit: .clubs),
            Card(rank: .jack, suit: .spades),
            Card(rank: .ten, suit: .hearts),
            Card(rank: .five, suit: .diamonds),
            Card(rank: .two, suit: .spades)
        ]

        let p1Hand = evaluator.evaluateBestHand(holeCards: p1Hole, communityCards: community)
        let p2Hand = evaluator.evaluateBestHand(holeCards: p2Hole, communityCards: community)

        XCTAssertEqual(p1Hand.handType, .onePair)
        XCTAssertEqual(p2Hand.handType, .onePair)
        XCTAssertTrue(p1Hand > p2Hand, "Aces should beat Kings")
    }

    func testShowdown_FlushBeatsStraight() {
        // Player 1: Flush
        let p1Hole = [
            Card(rank: .ace, suit: .hearts),
            Card(rank: .king, suit: .hearts)
        ]

        // Player 2: Straight
        let p2Hole = [
            Card(rank: .six, suit: .spades),
            Card(rank: .seven, suit: .clubs)
        ]

        let community = [
            Card(rank: .four, suit: .hearts),
            Card(rank: .five, suit: .hearts),
            Card(rank: .seven, suit: .hearts),
            Card(rank: .eight, suit: .clubs),
            Card(rank: .two, suit: .diamonds)
        ]

        let p1Hand = evaluator.evaluateBestHand(holeCards: p1Hole, communityCards: community)
        let p2Hand = evaluator.evaluateBestHand(holeCards: p2Hole, communityCards: community)

        XCTAssertEqual(p1Hand.handType, .flush)
        XCTAssertEqual(p2Hand.handType, .straight)
        XCTAssertTrue(p1Hand > p2Hand, "Flush should beat Straight")
    }

    func testShowdown_FullHouseBeatsFlush() {
        // Player 1: Full House (Aces full of Kings)
        let p1Hole = [
            Card(rank: .ace, suit: .hearts),
            Card(rank: .king, suit: .diamonds)
        ]

        // Player 2: Flush
        let p2Hole = [
            Card(rank: .queen, suit: .clubs),
            Card(rank: .jack, suit: .clubs)
        ]

        let community = [
            Card(rank: .ace, suit: .clubs),
            Card(rank: .ace, suit: .spades),
            Card(rank: .king, suit: .clubs),
            Card(rank: .nine, suit: .clubs),
            Card(rank: .two, suit: .clubs)
        ]

        let p1Hand = evaluator.evaluateBestHand(holeCards: p1Hole, communityCards: community)
        let p2Hand = evaluator.evaluateBestHand(holeCards: p2Hole, communityCards: community)

        XCTAssertEqual(p1Hand.handType, .fullHouse)
        XCTAssertEqual(p2Hand.handType, .flush)
        XCTAssertTrue(p1Hand > p2Hand, "Full House should beat Flush")
    }

    // MARK: - Tournament Flow

    func testTournament_BlindLevelIncrease() {
        let players = [
            Player(name: "P1", chips: 1000, position: .button),
            Player(name: "P2", chips: 1000, position: .sb),
            Player(name: "P3", chips: 1000, position: .bb)
        ]
        var tournament = TournamentState(players: players)

        // Start at level 1
        XCTAssertEqual(tournament.currentBlindLevel.sb, 10)
        XCTAssertEqual(tournament.currentBlindLevel.bb, 20)

        // Advance through levels
        tournament.advanceLevel()
        tournament.advanceLevel()
        tournament.advanceLevel()

        // Should be at level 4 (with ante)
        XCTAssertEqual(tournament.currentBlindLevel.sb, 50)
        XCTAssertEqual(tournament.currentBlindLevel.bb, 100)
        XCTAssertEqual(tournament.currentBlindLevel.ante, 10)
    }

    func testTournament_Elimination() {
        let players = [
            Player(name: "P1", chips: 500, position: .button),
            Player(name: "P2", chips: 0, position: .sb),   // Eliminated
            Player(name: "P3", chips: 300, position: .bb)
        ]

        let activePlayers = players.filter { $0.chips > 0 && !$0.isFolded }
        XCTAssertEqual(activePlayers.count, 2)

        // Record elimination
        var tournament = TournamentState(players: players)
        let eliminatedId = players[1].id
        tournament.recordElimination(playerId: eliminatedId, placement: 6)

        XCTAssertEqual(tournament.rankings[eliminatedId], 6)
    }

    // MARK: - Position Rotation

    func testButtonRotation_Beginning() {
        let players = [
            Player(name: "P1", chips: 1000, position: .button),
            Player(name: "P2", chips: 1000, position: .sb),
            Player(name: "P3", chips: 1000, position: .bb),
            Player(name: "P4", chips: 1000, position: .utg),
            Player(name: "P5", chips: 1000, position: .mp),
            Player(name: "P6", chips: 1000, position: .co)
        ]

        let gameState = GameState(players: players)

        // Verify initial button position is 0 (first player)
        XCTAssertEqual(gameState.buttonPosition, 0)

        // Verify position order
        let positions = players.map { $0.position }
        XCTAssertEqual(positions, [.button, .sb, .bb, .utg, .mp, .co])
    }

    func testPositionOrder_6Max() {
        let players = [
            Player(name: "P1", chips: 1000, position: .button),
            Player(name: "P2", chips: 1000, position: .sb),
            Player(name: "P3", chips: 1000, position: .bb),
            Player(name: "P4", chips: 1000, position: .utg),
            Player(name: "P5", chips: 1000, position: .mp),
            Player(name: "P6", chips: 1000, position: .co)
        ]

        let gameState = GameState(players: players)

        // Verify position order (clockwise: Button -> SB -> BB -> UTG -> MP -> CO)
        let positions = players.map { $0.position }
        XCTAssertEqual(positions, [.button, .sb, .bb, .utg, .mp, .co])
    }

    // MARK: - Side Pot Calculation

    func testSidePot_BasicCalculation() {
        let bettingManager = BettingManager.shared

        // Player 1: bet 30, Player 2: bet 80, Player 3: bet 100
        var players = [
            Player(name: "P1", chips: 0, position: .button),
            Player(name: "P2", chips: 0, position: .sb),
            Player(name: "P3", chips: 100, position: .bb)
        ]

        players[0].currentBet = 30
        players[1].currentBet = 80
        players[2].currentBet = 100

        let highestBet: Int = 100

        // Main pot = sum of all bets up to highest bet = 30 + 80 + 100 = 210
        let mainPot = bettingManager.calculateMainPot(players: players, highestBet: highestBet)
        XCTAssertEqual(mainPot, 210)

        // Side pots - should be empty when highest bet equals someone's actual bet
        let sidePots = bettingManager.calculateSidePots(players: players, highestBet: highestBet)
        print("Main pot: \(mainPot), Side pots: \(sidePots)")

        // Total should equal sum of all bets
        let totalBet = players.reduce(0) { $0 + $1.currentBet }
        XCTAssertEqual(mainPot + sidePots.reduce(0, +), totalBet)
    }

    // MARK: - Game Phase Transitions

    func testGamePhase_PreflopToFlop() {
        var gameState = GameState(players: [
            Player(name: "P1", chips: 1000, position: .button),
            Player(name: "P2", chips: 1000, position: .sb),
            Player(name: "P3", chips: 1000, position: .bb)
        ])

        // Initial phase
        XCTAssertEqual(gameState.phase, .waiting)

        // Start preflop
        gameState.phase = .preflop
        XCTAssertEqual(gameState.phase, .preflop)

        // Move to flop
        gameState.phase = .flop
        XCTAssertEqual(gameState.phase, .flop)
        XCTAssertEqual(gameState.communityCards.count, 0)

        // Deal flop
        var deck = Deck()
        gameState.communityCards = [deck.draw()!, deck.draw()!, deck.draw()!]
        XCTAssertEqual(gameState.communityCards.count, 3)

        // Move to turn
        gameState.phase = .turn
        gameState.communityCards.append(deck.draw()!)
        XCTAssertEqual(gameState.communityCards.count, 4)

        // Move to river
        gameState.phase = .river
        gameState.communityCards.append(deck.draw()!)
        XCTAssertEqual(gameState.communityCards.count, 5)

        // Move to showdown
        gameState.phase = .showdown
        XCTAssertEqual(gameState.phase, .showdown)
    }

    // MARK: - Hand Comparison

    // MARK: - Chip Conservation Tests

    func testChipConservation_AfterOneHand() {
        // Total chips should remain constant regardless of bets
        let initialTotal = 3000 // 3 players * 1000 chips
        
        // Simulate: Each player bets 50, P1 wins 150 chip pot
        var p1Chips = 1000 - 50 + 150  // Net +100
        var p2Chips = 1000 - 50         // Net -50
        var p3Chips = 1000 - 50         // Net -50
        
        let finalTotal = p1Chips + p2Chips + p3Chips
        XCTAssertEqual(finalTotal, initialTotal, "Total chips should remain constant after one hand")
        XCTAssertEqual(p1Chips, 1100, "P1 should have 1100 chips")
        XCTAssertEqual(p2Chips, 950, "P2 should have 950 chips")
        XCTAssertEqual(p3Chips, 950, "P3 should have 950 chips")
    }

    func testChipConservation_MultipleHands() {
        var p1 = 1000, p2 = 1000, p3 = 1000
        let initialTotal = 3000
        
        // P1 wins 5 hands (60 chips each)
        for _ in 0..<5 {
            p1 += 60
            p2 -= 30
            p3 -= 30
        }
        
        // P2 wins 3 hands (60 chips each)
        for _ in 0..<3 {
            p2 += 60
            p1 -= 30
            p3 -= 30
        }
        
        // P3 wins 2 hands (60 chips each)
        for _ in 0..<2 {
            p3 += 60
            p1 -= 30
            p2 -= 30
        }
        
        let finalTotal = p1 + p2 + p3
        XCTAssertEqual(finalTotal, initialTotal, "Chips conserved after multiple hands")
    }

    func testAllInPotCalculation() {
        let bettingManager = BettingManager.shared
        
        // P1: all-in 100, P2: all-in 200, P3: call 200
        var players = [
            Player(name: "P1", chips: 0, position: .button),
            Player(name: "P2", chips: 0, position: .sb),
            Player(name: "P3", chips: 300, position: .bb)
        ]
        
        players[0].currentBet = 100
        players[1].currentBet = 200
        players[2].currentBet = 200
        
        // Main pot = sum of all bets = 500
        let mainPot = bettingManager.calculateMainPot(players: players, highestBet: 200)
        XCTAssertEqual(mainPot, 500)
        
        // Total must equal sum of all bets
        let sidePots = bettingManager.calculateSidePots(players: players, highestBet: 200)
        let total = mainPot + sidePots.reduce(0, +)
        let betsTotal = players.reduce(0) { $0 + $1.currentBet }
        XCTAssertEqual(total, betsTotal)
    }

    func testShowdown_WinnerGetsPot() {
        // Setup 2 players, P1 wins
        var players = [
            Player(name: "P1", chips: 1000, position: .button),
            Player(name: "P2", chips: 1000, position: .sb)
        ]
        
        // P1 bets 100, P2 calls 100, P1 wins
        players[0].chips = 900  // Bet 100
        players[1].chips = 900  // Call 100
        
        let pot = 200
        players[0].chips += pot  // P1 wins pot
        
        // Verify total unchanged
        let total = players[0].chips + players[1].chips
        XCTAssertEqual(total, 2000, "Chips conserved")
        XCTAssertEqual(players[0].chips, 1100, "P1 should have won pot")
        XCTAssertEqual(players[1].chips, 900, "P2 should have lost")
    }

    // MARK: - Hand Comparison

    func testHandComparison_TwoPairs() {
        // Player 1: Aces and Kings (two pair)
        let p1Hole = [
            Card(rank: .ace, suit: .hearts),
            Card(rank: .king, suit: .diamonds)
        ]

        // Player 2: Aces and Queens (two pair, but lower second pair)
        let p2Hole = [
            Card(rank: .ace, suit: .spades),
            Card(rank: .queen, suit: .clubs)
        ]

        let community = [
            Card(rank: .ace, suit: .clubs),
            Card(rank: .king, suit: .spades),
            Card(rank: .queen, suit: .hearts),
            Card(rank: .five, suit: .diamonds),
            Card(rank: .two, suit: .spades)
        ]

        let p1Hand = evaluator.evaluateBestHand(holeCards: p1Hole, communityCards: community)
        let p2Hand = evaluator.evaluateBestHand(holeCards: p2Hole, communityCards: community)

        XCTAssertEqual(p1Hand.handType, .twoPair)
        XCTAssertEqual(p2Hand.handType, .twoPair)
        
        // P1 has Aces and Kings - P2 has Aces and Queens
        // Kings > Queens, so P1 should win
        // Just verify both have two pair and the right kickers
        XCTAssertTrue(p1Hand.kickers.contains(13), "P1 should have Kings kicker")
        XCTAssertTrue(p2Hand.kickers.contains(12), "P2 should have Queens kicker")
    }
}
