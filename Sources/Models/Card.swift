import Foundation

// MARK: - Card Model

struct Card: Equatable, Hashable, Codable {
    let rank: Rank
    let suit: Suit

    enum Rank: Int, CaseIterable, Codable, Comparable {
        case two = 2, three, four, five, six, seven, eight, nine, ten, jack, queen, king, ace

        var symbol: String {
            switch self {
            case .two: return "2"
            case .three: return "3"
            case .four: return "4"
            case .five: return "5"
            case .six: return "6"
            case .seven: return "7"
            case .eight: return "8"
            case .nine: return "9"
            case .ten: return "T"
            case .jack: return "J"
            case .queen: return "Q"
            case .king: return "K"
            case .ace: return "A"
            }
        }

        static func < (lhs: Rank, rhs: Rank) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    enum Suit: Int, CaseIterable, Codable {
        case clubs = 0, diamonds, hearts, spades

        var symbol: String {
            switch self {
            case .clubs: return "♣"
            case .diamonds: return "♦"
            case .hearts: return "♥"
            case .spades: return "♠"
            }
        }

        var color: String {
            switch self {
            case .clubs, .spades: return "black"
            case .diamonds, .hearts: return "red"
            }
        }
    }

    var displayString: String {
        "\(rank.symbol)\(suit.symbol)"
    }

    var numericValue: Int {
        var value = rank.rawValue
        if rank == .ace { value = 14 }
        return value
    }

    static func == (lhs: Card, rhs: Card) -> Bool {
        lhs.rank == rhs.rank && lhs.suit == rhs.suit
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(rank)
        hasher.combine(suit)
    }
}

// MARK: - Deck

struct Deck {
    var cards: [Card] = []

    init() {
        reset()
    }

    mutating func reset() {
        cards.removeAll()
        for suit in Card.Suit.allCases {
            for rank in Card.Rank.allCases {
                cards.append(Card(rank: rank, suit: suit))
            }
        }
    }

    mutating func shuffle() {
        cards.shuffle()
    }

    mutating func draw() -> Card? {
        guard !cards.isEmpty else { return nil }
        return cards.removeFirst()
    }

    mutating func draw(count: Int) -> [Card] {
        var drawn: [Card] = []
        for _ in 0..<count {
            guard let card = draw() else { break }
            drawn.append(card)
        }
        return drawn
    }
}

// MARK: - Card Combination (for hand evaluation)

struct CardCombination: Comparable {
    let cards: [Card]
    let handType: HandType
    let handRank: Int
    let kickers: [Int]

    enum HandType: Int, CaseIterable {
        case highCard = 0
        case onePair
        case twoPair
        case threeOfAKind
        case straight
        case flush
        case fullHouse
        case fourOfAKind
        case straightFlush
        case royalFlush

        var displayName: String {
            switch self {
            case .highCard: return String(localized: "高牌")
            case .onePair: return String(localized: "一对")
            case .twoPair: return String(localized: "两对")
            case .threeOfAKind: return String(localized: "三条")
            case .straight: return String(localized: "顺子")
            case .flush: return String(localized: "同花")
            case .fullHouse: return String(localized: "葫芦")
            case .fourOfAKind: return String(localized: "四条")
            case .straightFlush: return String(localized: "同花顺")
            case .royalFlush: return String(localized: "皇家同花顺")
            }
        }
    }

    static func == (lhs: CardCombination, rhs: CardCombination) -> Bool {
        return lhs.handType == rhs.handType &&
               lhs.handRank == rhs.handRank &&
               lhs.kickers == rhs.kickers
    }

    static func < (lhs: CardCombination, rhs: CardCombination) -> Bool {
        if lhs.handType != rhs.handType {
            return lhs.handType.rawValue < rhs.handType.rawValue
        }
        if lhs.handRank != rhs.handRank {
            return lhs.handRank < rhs.handRank
        }
        for i in 0..<min(lhs.kickers.count, rhs.kickers.count) {
            if lhs.kickers[i] != rhs.kickers[i] {
                return lhs.kickers[i] < rhs.kickers[i]
            }
        }
        return lhs.kickers.count < rhs.kickers.count
    }
}
