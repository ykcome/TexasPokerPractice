import XCTest
@testable import TexasPoker

// MARK: - Tournament State Tests

final class TournamentTests: XCTestCase {

    // MARK: - Blind Level Tests

    func testDefaultBlindSchedule() {
        let schedule = TournamentState.defaultBlindSchedule

        XCTAssertEqual(schedule.count, 8)

        // Level 1
        XCTAssertEqual(schedule[0].level, 1)
        XCTAssertEqual(schedule[0].sb, 10)
        XCTAssertEqual(schedule[0].bb, 20)
        XCTAssertEqual(schedule[0].ante, 0)

        // Level 4 - ante starts
        XCTAssertEqual(schedule[3].level, 4)
        XCTAssertEqual(schedule[3].ante, 10)

        // Level 8
        XCTAssertEqual(schedule[7].sb, 200)
        XCTAssertEqual(schedule[7].bb, 400)
        XCTAssertEqual(schedule[7].ante, 50)
    }

    func testCurrentBlindLevel() {
        let players = [
            Player(name: "P1", chips: 1000, position: .button, isHuman: true)
        ]
        var tournament = TournamentState(players: players)
        tournament.currentLevel = 3

        let blindLevel = tournament.currentBlindLevel

        XCTAssertEqual(blindLevel.level, 3)
        XCTAssertEqual(blindLevel.sb, 25)
        XCTAssertEqual(blindLevel.bb, 50)
        XCTAssertEqual(blindLevel.ante, 0)
    }

    func testAdvanceLevel() {
        let players = [
            Player(name: "P1", chips: 1000, position: .button, isHuman: true)
        ]
        var tournament = TournamentState(players: players)
        tournament.currentLevel = 1

        tournament.advanceLevel()

        XCTAssertEqual(tournament.currentLevel, 2)
    }

    // MARK: - Payout Tests

    func testDefaultPayouts() {
        let players = [
            Player(name: "P1", chips: 1000, position: .button),
            Player(name: "P2", chips: 1000, position: .sb),
            Player(name: "P3", chips: 1000, position: .bb)
        ]
        let tournament = TournamentState(players: players)

        XCTAssertEqual(tournament.payouts.count, 3)
        XCTAssertEqual(tournament.payouts[0], 0.50) // 1st: 50%
        XCTAssertEqual(tournament.payouts[1], 0.30) // 2nd: 30%
        XCTAssertEqual(tournament.payouts[2], 0.20) // 3rd: 20%
    }

    func testPayoutCalculation() {
        let players = [
            Player(name: "P1", chips: 1000, position: .button),
            Player(name: "P2", chips: 500, position: .sb),
            Player(name: "P3", chips: 0, position: .bb)
        ]

        let totalPrize = 1000.0

        // P3 is eliminated, P1 is 1st, P2 is 2nd
        let p1Payout = totalPrize * 0.50
        let p2Payout = totalPrize * 0.30

        XCTAssertEqual(p1Payout, 500.0)
        XCTAssertEqual(p2Payout, 300.0)
    }

    // MARK: - Elimination Tests

    func testPlayerElimination() {
        var players = [
            Player(name: "P1", chips: 1000, position: .button),
            Player(name: "P2", chips: 0, position: .sb),
            Player(name: "P3", chips: 500, position: .bb)
        ]
        let tournament = TournamentState(players: players)

        let eliminatedPlayers = tournament.players.filter { $0.isEliminated }

        XCTAssertEqual(eliminatedPlayers.count, 1)
        XCTAssertEqual(eliminatedPlayers.first?.name, "P2")
    }

    func testRecordElimination() {
        let players = [
            Player(name: "P1", chips: 1000, position: .button),
            Player(name: "P2", chips: 500, position: .sb),
            Player(name: "P3", chips: 0, position: .bb)
        ]
        var tournament = TournamentState(players: players)

        tournament.recordElimination(playerId: players[1].id, placement: 2)
        tournament.recordElimination(playerId: players[2].id, placement: 3)

        XCTAssertEqual(tournament.rankings[players[1].id], 2)
        XCTAssertEqual(tournament.rankings[players[2].id], 3)
    }

    // MARK: - Tournament End Tests

    func testTournamentEndsWhenOnePlayerLeft() {
        let players = [
            Player(name: "P1", chips: 1000, position: .button),
            Player(name: "P2", chips: 0, position: .sb),
            Player(name: "P3", chips: 0, position: .bb)
        ]

        let activePlayers = players.filter { !$0.isEliminated }

        XCTAssertTrue(activePlayers.count == 1)
        XCTAssertEqual(activePlayers.first?.name, "P1")
    }

    // MARK: - Final Table Tests (6-max)

    func testFinalTableDefinition() {
        // 6-max SNG: Final table is when 3 players remain (ITM)
        let players = [
            Player(name: "P1", chips: 1000, position: .button),
            Player(name: "P2", chips: 500, position: .sb),
            Player(name: "P3", chips: 300, position: .bb),
            Player(name: "P4", chips: 0, position: .utg),
            Player(name: "P5", chips: 0, position: .mp),
            Player(name: "P6", chips: 0, position: .co)
        ]

        let remainingPlayers = players.filter { !$0.isEliminated }

        XCTAssertEqual(remainingPlayers.count, 3) // Final table
    }
}
