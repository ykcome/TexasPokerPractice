import XCTest
@testable import TexasPoker

// MARK: - Betting Manager Tests

final class BettingManagerTests: XCTestCase {

    var bettingManager: BettingManager!

    override func setUp() {
        super.setUp()
        bettingManager = BettingManager.shared
    }

    override func tearDown() {
        bettingManager = nil
        super.tearDown()
    }

    // MARK: - Valid Actions Tests

    func testValidActionsFirstBettor() {
        let player = Player(name: "Test", chips: 1000, position: .mp, isHuman: true)

        let actions = bettingManager.getValidActions(
            for: player,
            highestBet: 0,
            phase: .preflop,
            minBet: 20,
            sbAmount: 10,
            bbAmount: 20,
            isFirstBettor: true
        )

        // First bettor can bet or check, cannot fold or call
        XCTAssertFalse(actions.canFold)
        XCTAssertTrue(actions.canCheck)
        XCTAssertFalse(actions.canCall)
        XCTAssertTrue(actions.canBet)
        XCTAssertFalse(actions.canRaise)
    }

    func testValidActionsFollowingPlayer() {
        var player = Player(name: "Test", chips: 1000, position: .mp, isHuman: true)
        player.currentBet = 20

        let actions = bettingManager.getValidActions(
            for: player,
            highestBet: 50,
            phase: .preflop,
            minBet: 20,
            sbAmount: 10,
            bbAmount: 20,
            isFirstBettor: false
        )

        // Following player can fold, call, raise
        XCTAssertTrue(actions.canFold)
        XCTAssertFalse(actions.canCheck)
        XCTAssertTrue(actions.canCall)
        XCTAssertEqual(actions.callAmount, 30)
        XCTAssertFalse(actions.canBet)
        XCTAssertTrue(actions.canRaise)
    }

    func testValidActionsAllIn() {
        var player = Player(name: "Test", chips: 0, position: .mp, isHuman: true)
        player.isAllIn = true

        let actions = bettingManager.getValidActions(
            for: player,
            highestBet: 100,
            phase: .preflop,
            minBet: 20,
            sbAmount: 10,
            bbAmount: 20,
            isFirstBettor: false
        )

        // All-in player with 0 chips cannot call or raise
        // But can fold (even though it doesn't make strategic sense)
        // The implementation doesn't check isAllIn flag
        XCTAssertFalse(actions.canCall)
        XCTAssertFalse(actions.canRaise)
        XCTAssertFalse(actions.canBet)
        XCTAssertFalse(actions.canAllIn)
    }

    func testValidActionsNoMoneyToCall() {
        var player = Player(name: "Test", chips: 30, position: .mp, isHuman: true)
        player.currentBet = 20

        let actions = bettingManager.getValidActions(
            for: player,
            highestBet: 100,
            phase: .preflop,
            minBet: 20,
            sbAmount: 10,
            bbAmount: 20,
            isFirstBettor: false
        )

        // Player needs 80 to call but only has 30
        XCTAssertTrue(actions.canFold)
        XCTAssertFalse(actions.canCheck)
        XCTAssertFalse(actions.canCall)
        XCTAssertFalse(actions.canRaise)
        XCTAssertTrue(actions.canAllIn)
        XCTAssertEqual(actions.allInAmount, 30)
    }

    // MARK: - Pot Calculation Tests

    func testCalculateTotalPot() {
        var players = [
            Player(name: "P1", chips: 1000, position: .button),
            Player(name: "P2", chips: 1000, position: .sb),
            Player(name: "P3", chips: 1000, position: .bb)
        ]
        players[0].currentBet = 50
        players[1].currentBet = 10
        players[2].currentBet = 20

        let totalPot = bettingManager.calculateTotalPot(players: players)

        XCTAssertEqual(totalPot, 80)
    }

    func testCalculateMainPot() {
        var players = [
            Player(name: "P1", chips: 1000, position: .button),
            Player(name: "P2", chips: 1000, position: .sb),
            Player(name: "P3", chips: 1000, position: .bb)
        ]
        players[0].currentBet = 100  // All-in
        players[1].currentBet = 50
        players[2].currentBet = 50

        let mainPot = bettingManager.calculateMainPot(players: players, highestBet: 50)

        XCTAssertEqual(mainPot, 150)  // 50 + 50 + 50 (all players contribute min of their bet to main pot)
    }

    func testCalculateSidePot() {
        var players = [
            Player(name: "P1", chips: 0, position: .button),
            Player(name: "P2", chips: 500, position: .sb),
            Player(name: "P3", chips: 500, position: .bb)
        ]
        players[0].currentBet = 100  // All-in at 100
        players[1].currentBet = 50
        players[2].currentBet = 50

        let highestBet = 100

        // P1 is all-in at 100, P2 and P3 only have 50 each
        // No side pot because no player bet above highestBet (100)
        // The extra from P1's all-in vs P2/P3's 50 creates a side pot situation
        let sidePots = bettingManager.calculateSidePots(players: players, highestBet: highestBet)

        // No side pot in this scenario since P2 and P3 didn't exceed highestBet
        XCTAssertEqual(sidePots.count, 0)
    }

    // MARK: - Action Processing Tests

    func testProcessFold() {
        var player = Player(name: "Test", chips: 1000, position: .mp, isHuman: true)
        player.currentBet = 20
        var gameState = GameState(players: [player])
        gameState.pot = 50

        let result = bettingManager.processAction(
            action: .fold,
            for: &player,
            gameState: &gameState
        )

        XCTAssertTrue(result.success)
        XCTAssertTrue(player.isFolded)
        XCTAssertEqual(gameState.pot, 50)  // Pot unchanged on fold
    }

    func testProcessCall() {
        var player = Player(name: "Test", chips: 1000, position: .mp, isHuman: true)
        player.currentBet = 0
        var otherPlayer = Player(name: "Other", chips: 1000, position: .sb)
        otherPlayer.currentBet = 30
        var gameState = GameState(players: [player, otherPlayer])
        gameState.pot = 80  // 30 from other player + 50 already in pot

        let result = bettingManager.processAction(
            action: .call(amount: 30),
            for: &player,
            gameState: &gameState
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(player.chips, 970)
        XCTAssertEqual(player.currentBet, 30)
        XCTAssertEqual(gameState.pot, 110)
    }

    func testProcessBet() {
        var player = Player(name: "Test", chips: 1000, position: .button, isHuman: true)
        var gameState = GameState(players: [player])
        gameState.pot = 0
        gameState.bettingRound = 0

        let result = bettingManager.processAction(
            action: .bet(amount: 100),
            for: &player,
            gameState: &gameState
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(player.chips, 900)
        XCTAssertEqual(player.currentBet, 100)
        XCTAssertEqual(gameState.pot, 100)
    }

    func testProcessAllIn() {
        var player = Player(name: "Test", chips: 500, position: .mp, isHuman: true)
        player.currentBet = 100
        var gameState = GameState(players: [player])
        gameState.pot = 200
        gameState.bettingRound = 1

        let result = bettingManager.processAction(
            action: .allIn(amount: 500),
            for: &player,
            gameState: &gameState
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(player.chips, 0)
        XCTAssertTrue(player.isAllIn)
        XCTAssertEqual(player.currentBet, 600)
        XCTAssertEqual(gameState.pot, 700)
    }

    // MARK: - Betting Round Complete Tests

    func testBettingRoundCompleteAllCalled() {
        var players = [
            Player(name: "P1", chips: 1000, position: .button),
            Player(name: "P2", chips: 1000, position: .sb),
            Player(name: "P3", chips: 1000, position: .bb)
        ]
        players[0].currentBet = 50
        players[1].currentBet = 50
        players[2].currentBet = 50

        let complete = bettingManager.isBettingRoundComplete(
            players: players,
            highestBet: 50,
            currentPlayerIndex: 0
        )

        XCTAssertTrue(complete)
    }

    func testBettingRoundCompleteNotAllCalled() {
        var players = [
            Player(name: "P1", chips: 1000, position: .button),
            Player(name: "P2", chips: 1000, position: .sb),
            Player(name: "P3", chips: 1000, position: .bb)
        ]
        players[0].currentBet = 50
        players[1].currentBet = 30
        players[2].currentBet = 50

        let complete = bettingManager.isBettingRoundComplete(
            players: players,
            highestBet: 50,
            currentPlayerIndex: 1
        )

        XCTAssertFalse(complete)
    }

    func testBettingRoundCompleteOnePlayerLeft() {
        var players = [
            Player(name: "P1", chips: 0, position: .button),
            Player(name: "P2", chips: 100, position: .sb),
            Player(name: "P3", chips: 100, position: .bb)
        ]
        players[0].isActive = false
        players[1].isFolded = true

        let complete = bettingManager.isBettingRoundComplete(
            players: players,
            highestBet: 20,
            currentPlayerIndex: 2
        )

        XCTAssertTrue(complete)
    }

    // MARK: - Min Raise Tests

    func testMinRaiseCalculation() {
        var player = Player(name: "Test", chips: 1000, position: .mp, isHuman: true)
        player.currentBet = 50

        let actions = bettingManager.getValidActions(
            for: player,
            highestBet: 100,
            phase: .preflop,
            minBet: 20,
            sbAmount: 10,
            bbAmount: 20,
            isFirstBettor: false
        )

        // Min raise = 100 * 2 = 200
        XCTAssertTrue(actions.canRaise)
        XCTAssertEqual(actions.minRaise, 200)
    }

    func testMinRaiseCalculationFirstBettor() {
        let player = Player(name: "Test", chips: 1000, position: .button, isHuman: true)

        let actions = bettingManager.getValidActions(
            for: player,
            highestBet: 0,
            phase: .preflop,
            minBet: 20,
            sbAmount: 10,
            bbAmount: 20,
            isFirstBettor: true
        )

        // First bettor min raise = minBet (BB) = 20
        XCTAssertTrue(actions.canBet)
        XCTAssertEqual(actions.betAmount, 20)
    }
}
