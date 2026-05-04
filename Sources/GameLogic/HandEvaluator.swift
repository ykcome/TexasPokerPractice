import Foundation

// MARK: - Hand Evaluator

final class HandEvaluator {

    static let shared = HandEvaluator()

    private init() {}

    // MARK: - Best 5 Card Combination

    func evaluateBestHand(holeCards: [Card], communityCards: [Card]) -> CardCombination {
        let allCards = holeCards + communityCards
        guard allCards.count >= 5 else {
            return CardCombination(cards: allCards, handType: .highCard, handRank: 0, kickers: [])
        }

        var bestHand = findBestCombination(from: allCards)
        return bestHand
    }

    private func findBestCombination(from cards: [Card]) -> CardCombination {
        var bestHand = CardCombination(
            cards: [],
            handType: .highCard,
            handRank: 0,
            kickers: []
        )

        // Generate all 5-card combinations from the 7 cards
        let combinations = generateCombinations(cards, k: 5)

        for combo in combinations {
            let evaluated = evaluateFiveCards(combo)
            if evaluated > bestHand {
                bestHand = evaluated
            }
        }

        return bestHand
    }

    private func generateCombinations(_ array: [Card], k: Int) -> [[Card]] {
        guard k > 0 else { return [[]] }
        guard k <= array.count else { return [] }

        var result: [[Card]] = []

        if k == 1 {
            return array.map { [$0] }
        }

        for i in 0...(array.count - k) {
            let head = array[i]
            let subCombos = generateCombinations(Array(array[(i + 1)...]), k: k - 1)
            for var combo in subCombos {
                combo.insert(head, at: 0)
                result.append(combo)
            }
        }

        return result
    }

    // MARK: - Evaluate 5 Cards

    func evaluateFiveCards(_ cards: [Card]) -> CardCombination {
        guard cards.count == 5 else {
            return CardCombination(cards: cards, handType: .highCard, handRank: 0, kickers: [])
        }

        let sortedCards = cards.sorted { $0.numericValue > $1.numericValue }
        let ranks = sortedCards.map { $0.numericValue }
        let suits = sortedCards.map { $0.suit }

        // Check flush
        let isFlush = suits.allSatisfy { $0 == suits[0] }

        // Check straight
        let isStraight = checkStraight(ranks: ranks)

        // Check royal flush
        if isFlush && isStraight && ranks.first == 14 {
            return CardCombination(
                cards: sortedCards,
                handType: .royalFlush,
                handRank: 9,
                kickers: []
            )
        }

        // Check straight flush
        if isFlush && isStraight {
            let kicker = (ranks == [14, 5, 4, 3, 2]) ? 5 : ranks.first!
            return CardCombination(
                cards: sortedCards,
                handType: .straightFlush,
                handRank: 8,
                kickers: [kicker]
            )
        }

        // Count ranks
        var rankCounts: [Int: Int] = [:]
        for rank in ranks {
            rankCounts[rank, default: 0] += 1
        }

        let counts = rankCounts.values.sorted(by: >)
        let uniqueRanks = rankCounts.keys.sorted(by: { 
            rankCounts[$0]! > rankCounts[$1]! || (rankCounts[$0]! == rankCounts[$1]! && $0 > $1)
        })

        // Four of a kind
        if counts.first == 4 {
            let kicker = uniqueRanks.first { $0 != uniqueRanks[0] } ?? 0
            return CardCombination(
                cards: sortedCards,
                handType: .fourOfAKind,
                handRank: 7,
                kickers: [uniqueRanks[0], kicker]
            )
        }

        // Full house
        if counts.first == 3 && counts.count >= 2 && counts[1] == 2 {
            return CardCombination(
                cards: sortedCards,
                handType: .fullHouse,
                handRank: 6,
                kickers: [uniqueRanks[0], uniqueRanks[1]]
            )
        }

        // Flush
        if isFlush {
            let kickers = Array(ranks.prefix(5))
            return CardCombination(
                cards: sortedCards,
                handType: .flush,
                handRank: 5,
                kickers: kickers
            )
        }

        // Straight
        if isStraight {
            let kicker = (ranks == [14, 5, 4, 3, 2]) ? 5 : ranks.first!
            return CardCombination(
                cards: sortedCards,
                handType: .straight,
                handRank: 4,
                kickers: [kicker]
            )
        }

        // Three of a kind
        if counts.first == 3 {
            var kickers: [Int] = [uniqueRanks[0]]
            for rank in uniqueRanks.dropFirst() {
                kickers.append(rank)
            }
            return CardCombination(
                cards: sortedCards,
                handType: .threeOfAKind,
                handRank: 3,
                kickers: kickers
            )
        }

        // Two pair
        if counts.first == 2 && counts.count >= 2 && counts[1] == 2 {
            let pairRanks = uniqueRanks.prefix(2)
            let kicker = uniqueRanks.last ?? 0
            return CardCombination(
                cards: sortedCards,
                handType: .twoPair,
                handRank: 2,
                kickers: [pairRanks[0], pairRanks[1], kicker]
            )
        }

        // One pair
        if counts.first == 2 {
            var kickers: [Int] = [uniqueRanks[0]]
            for rank in uniqueRanks.dropFirst() {
                kickers.append(rank)
            }
            return CardCombination(
                cards: sortedCards,
                handType: .onePair,
                handRank: 1,
                kickers: kickers
            )
        }

        // High card
        return CardCombination(
            cards: sortedCards,
            handType: .highCard,
            handRank: 0,
            kickers: ranks
        )
    }

    private func checkStraight(ranks: [Int]) -> Bool {
        guard ranks.count == 5 else { return false }

        let sortedRanks = ranks.sorted()

        // Regular straight
        for i in 1..<sortedRanks.count {
            if sortedRanks[i] - sortedRanks[i - 1] != 1 {
                // Check wheel straight (A-2-3-4-5)
                if sortedRanks == [2, 3, 4, 5, 14] {
                    return true
                }
                return false
            }
        }
        return true
    }

    // MARK: - Compare Two Hands

    func compareHands(
        hole1: [Card], hole2: [Card],
        community: [Card]
    ) -> Int {
        let hand1 = evaluateBestHand(holeCards: hole1, communityCards: community)
        let hand2 = evaluateBestHand(holeCards: hole2, communityCards: community)

        if hand1 > hand2 {
            return 1
        } else if hand1 < hand2 {
            return -1
        } else {
            return 0
        }
    }

    // MARK: - Showdown

    func determineWinner(players: [Player], communityCards: [Card]) -> [UUID] {
        var bestHand: CardCombination?
        var winners: [UUID] = []

        for player in players where !player.isFolded {
            guard let holeCards = player.holeCards else { continue }

            let hand = evaluateBestHand(holeCards: holeCards, communityCards: communityCards)

            if bestHand == nil || hand > bestHand! {
                bestHand = hand
                winners = [player.id]
            } else if hand == bestHand {
                winners.append(player.id)
            }
        }

        return winners
    }
}
