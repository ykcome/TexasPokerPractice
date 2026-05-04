import XCTest
@testable import TexasPoker

// MARK: - P0 核心规则测试

final class P0CoreRulesTests: XCTestCase {

    var evaluator: HandEvaluator!

    override func setUp() {
        super.setUp()
        evaluator = HandEvaluator.shared
    }

    override func tearDown() {
        evaluator = nil
        super.tearDown()
    }

    // MARK: - #1 手牌大小判定（10种牌型）

    func testHandTypeRanking_RoyalFlush() {
        let royal = [
            Card(rank: .ace, suit: .hearts),
            Card(rank: .king, suit: .hearts),
            Card(rank: .queen, suit: .hearts),
            Card(rank: .jack, suit: .hearts),
            Card(rank: .ten, suit: .hearts)
        ]
        XCTAssertEqual(evaluator.evaluateFiveCards(royal).handType, .royalFlush)
    }

    func testHandTypeRanking_StraightFlush() {
        let straightFlush = [
            Card(rank: .nine, suit: .hearts),
            Card(rank: .eight, suit: .hearts),
            Card(rank: .seven, suit: .hearts),
            Card(rank: .six, suit: .hearts),
            Card(rank: .five, suit: .hearts)
        ]
        XCTAssertEqual(evaluator.evaluateFiveCards(straightFlush).handType, .straightFlush)
    }

    func testHandTypeRanking_FourOfAKind() {
        let fourKind = [
            Card(rank: .ace, suit: .hearts),
            Card(rank: .ace, suit: .diamonds),
            Card(rank: .ace, suit: .clubs),
            Card(rank: .ace, suit: .spades),
            Card(rank: .king, suit: .hearts)
        ]
        XCTAssertEqual(evaluator.evaluateFiveCards(fourKind).handType, .fourOfAKind)
    }

    func testHandTypeRanking_FullHouse() {
        let fullHouse = [
            Card(rank: .ace, suit: .hearts),
            Card(rank: .ace, suit: .diamonds),
            Card(rank: .ace, suit: .clubs),
            Card(rank: .king, suit: .hearts),
            Card(rank: .king, suit: .diamonds)
        ]
        XCTAssertEqual(evaluator.evaluateFiveCards(fullHouse).handType, .fullHouse)
    }

    func testHandTypeRanking_Flush() {
        let flush = [
            Card(rank: .ace, suit: .hearts),
            Card(rank: .king, suit: .hearts),
            Card(rank: .jack, suit: .hearts),
            Card(rank: .ten, suit: .hearts),
            Card(rank: .three, suit: .hearts)
        ]
        XCTAssertEqual(evaluator.evaluateFiveCards(flush).handType, .flush)
    }

    func testHandTypeRanking_Straight() {
        let straight = [
            Card(rank: .ace, suit: .hearts),
            Card(rank: .king, suit: .diamonds),
            Card(rank: .queen, suit: .clubs),
            Card(rank: .jack, suit: .spades),
            Card(rank: .ten, suit: .hearts)
        ]
        XCTAssertEqual(evaluator.evaluateFiveCards(straight).handType, .straight)
    }

    func testHandTypeRanking_ThreeOfAKind() {
        let trips = [
            Card(rank: .ace, suit: .hearts),
            Card(rank: .ace, suit: .diamonds),
            Card(rank: .ace, suit: .clubs),
            Card(rank: .king, suit: .hearts),
            Card(rank: .queen, suit: .diamonds)
        ]
        XCTAssertEqual(evaluator.evaluateFiveCards(trips).handType, .threeOfAKind)
    }

    func testHandTypeRanking_TwoPair() {
        let twoPair = [
            Card(rank: .ace, suit: .hearts),
            Card(rank: .ace, suit: .diamonds),
            Card(rank: .king, suit: .hearts),
            Card(rank: .king, suit: .diamonds),
            Card(rank: .queen, suit: .clubs)
        ]
        XCTAssertEqual(evaluator.evaluateFiveCards(twoPair).handType, .twoPair)
    }

    func testHandTypeRanking_OnePair() {
        let onePair = [
            Card(rank: .ace, suit: .hearts),
            Card(rank: .ace, suit: .diamonds),
            Card(rank: .king, suit: .hearts),
            Card(rank: .queen, suit: .diamonds),
            Card(rank: .jack, suit: .clubs)
        ]
        XCTAssertEqual(evaluator.evaluateFiveCards(onePair).handType, .onePair)
    }

    func testHandTypeRanking_HighCard() {
        let highCard = [
            Card(rank: .ace, suit: .hearts),
            Card(rank: .king, suit: .diamonds),
            Card(rank: .queen, suit: .clubs),
            Card(rank: .jack, suit: .spades),
            Card(rank: .nine, suit: .hearts)
        ]
        XCTAssertEqual(evaluator.evaluateFiveCards(highCard).handType, .highCard)
    }

    // MARK: - #1 手牌强度排序

    func testHandTypeOrder_FlushGreaterThanStraight() {
        let flush = evaluator.evaluateFiveCards([
            Card(rank: .ace, suit: .hearts),
            Card(rank: .ten, suit: .hearts),
            Card(rank: .seven, suit: .hearts),
            Card(rank: .five, suit: .hearts),
            Card(rank: .three, suit: .hearts)
        ])
        let straight = evaluator.evaluateFiveCards([
            Card(rank: .ace, suit: .spades),
            Card(rank: .king, suit: .diamonds),
            Card(rank: .queen, suit: .clubs),
            Card(rank: .jack, suit: .hearts),
            Card(rank: .ten, suit: .spades)
        ])
        XCTAssertTrue(flush > straight)
    }

    // MARK: - #3 顺子判断

    func testStraight_WheelIsLowest() {
        // A-2-3-4-5 is a valid wheel straight
        let wheel = [
            Card(rank: .ace, suit: .hearts),
            Card(rank: .two, suit: .diamonds),
            Card(rank: .three, suit: .clubs),
            Card(rank: .four, suit: .spades),
            Card(rank: .five, suit: .hearts)
        ]
        let broadway = [
            Card(rank: .ten, suit: .hearts),
            Card(rank: .jack, suit: .diamonds),
            Card(rank: .queen, suit: .clubs),
            Card(rank: .king, suit: .spades),
            Card(rank: .ace, suit: .hearts)
        ]

        let wheelHand = evaluator.evaluateFiveCards(wheel)
        let broadwayHand = evaluator.evaluateFiveCards(broadway)

        XCTAssertEqual(wheelHand.handType, .straight)
        XCTAssertEqual(broadwayHand.handType, .straight)
    }

    func testStraight_WheelWith7Cards() {
        let hole = [
            Card(rank: .ace, suit: .hearts),
            Card(rank: .two, suit: .diamonds)
        ]
        let community = [
            Card(rank: .three, suit: .clubs),
            Card(rank: .four, suit: .spades),
            Card(rank: .five, suit: .hearts),
            Card(rank: .king, suit: .clubs),
            Card(rank: .queen, suit: .diamonds)
        ]

        let result = evaluator.evaluateBestHand(holeCards: hole, communityCards: community)
        XCTAssertEqual(result.handType, .straight)
    }

    func testStraight_NormalStraight() {
        let straight = [
            Card(rank: .six, suit: .hearts),
            Card(rank: .seven, suit: .diamonds),
            Card(rank: .eight, suit: .clubs),
            Card(rank: .nine, suit: .spades),
            Card(rank: .ten, suit: .hearts)
        ]
        XCTAssertEqual(evaluator.evaluateFiveCards(straight).handType, .straight)
    }

    func testStraight_StraightWithAceHigh() {
        let aceHighStraight = [
            Card(rank: .ten, suit: .hearts),
            Card(rank: .jack, suit: .diamonds),
            Card(rank: .queen, suit: .clubs),
            Card(rank: .king, suit: .spades),
            Card(rank: .ace, suit: .hearts)
        ]
        let result = evaluator.evaluateFiveCards(aceHighStraight)
        XCTAssertEqual(result.handType, .straight)
        XCTAssertEqual(result.kickers.first, 14)
    }

    func testStraight_BustedNotAStraight() {
        // 2-3-5-6-7 is NOT a straight (missing 4)
        let busted = [
            Card(rank: .two, suit: .hearts),
            Card(rank: .three, suit: .diamonds),
            Card(rank: .five, suit: .clubs),
            Card(rank: .six, suit: .spades),
            Card(rank: .seven, suit: .hearts)
        ]
        let result = evaluator.evaluateFiveCards(busted)
        XCTAssertEqual(result.handType, .highCard)
    }

    // MARK: - #4 同花判断

    func testFlush_5SameSuit() {
        let flush = [
            Card(rank: .ace, suit: .hearts),
            Card(rank: .king, suit: .hearts),
            Card(rank: .jack, suit: .hearts),
            Card(rank: .ten, suit: .hearts),
            Card(rank: .three, suit: .hearts)
        ]
        XCTAssertEqual(evaluator.evaluateFiveCards(flush).handType, .flush)
    }

    func testFlush_NotFlushWith4SameSuit() {
        let notFlush = [
            Card(rank: .ace, suit: .hearts),
            Card(rank: .king, suit: .hearts),
            Card(rank: .jack, suit: .hearts),
            Card(rank: .ten, suit: .hearts),
            Card(rank: .three, suit: .clubs)
        ]
        let result = evaluator.evaluateFiveCards(notFlush)
        XCTAssertNotEqual(result.handType, .flush)
    }

    // MARK: - #5 平局分池

    func testTieSplitPot_SameHand() {
        let hole1 = [
            Card(rank: .ace, suit: .hearts),
            Card(rank: .king, suit: .diamonds)
        ]
        let hole2 = [
            Card(rank: .ace, suit: .spades),
            Card(rank: .king, suit: .clubs)
        ]
        let community = [
            Card(rank: .queen, suit: .hearts),
            Card(rank: .jack, suit: .diamonds),
            Card(rank: .ten, suit: .clubs),
            Card(rank: .five, suit: .spades),
            Card(rank: .three, suit: .hearts)
        ]

        let result = evaluator.compareHands(hole1: hole1, hole2: hole2, community: community)
        XCTAssertEqual(result, 0)
    }

    // MARK: - 综合测试

    func testDetermineWinner_MultiplePlayers() {
        var players = [
            Player(name: "P1", chips: 1000, position: .button, isHuman: true),
            Player(name: "P2", chips: 1000, position: .sb),
            Player(name: "P3", chips: 1000, position: .bb)
        ]
        players[0].holeCards = [
            Card(rank: .ace, suit: .hearts),
            Card(rank: .king, suit: .diamonds)
        ]
        players[1].holeCards = [
            Card(rank: .queen, suit: .spades),
            Card(rank: .jack, suit: .clubs)
        ]
        players[2].holeCards = [
            Card(rank: .ten, suit: .hearts),
            Card(rank: .nine, suit: .diamonds)
        ]
        let community = [
            Card(rank: .ace, suit: .clubs),
            Card(rank: .king, suit: .spades),
            Card(rank: .queen, suit: .clubs),
            Card(rank: .jack, suit: .spades),
            Card(rank: .ten, suit: .hearts)
        ]

        let winners = evaluator.determineWinner(players: players, communityCards: community)

        // P1 has two pair: Aces and Kings
        // P2 has two pair: Aces and Queens
        // P3 has two pair: Aces and Jacks
        // All have Aces, compare second pair: Kings > Queens > Jacks
        XCTAssertEqual(winners.count, 1)
        XCTAssertEqual(winners.first, players[0].id)
    }
}
