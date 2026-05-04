import Foundation

struct Player {
    var seatId: Int
    var isHuman: Bool
    var currentBet: Int
    var chips: Int
}

let players = [
    Player(seatId: 2, isHuman: false, currentBet: 10, chips: 1990),
    Player(seatId: 4, isHuman: true, currentBet: 20, chips: 1980)
]

let actionOrder = [2, 4]
let snapshotPlayer = players[0]

let humanIndex = actionOrder.firstIndex(where: { orderSeat in
    players.first(where: { p in p.seatId == orderSeat })?.isHuman == true
}) ?? 0
let currentIndex = actionOrder.firstIndex(of: snapshotPlayer.seatId) ?? 0

print("humanIndex: \(humanIndex), currentIndex: \(currentIndex)")

if currentIndex < humanIndex {
    let highestBet = players.map { $0.currentBet }.max() ?? 0
    let bbAmount = 20
    if highestBet <= bbAmount {
        let raiseAmount = bbAmount * Int.random(in: 3...10)
        print("3BET MODE DEBUG: AI raising to \(raiseAmount)")
    } else {
        print("3BET MODE DEBUG: AI folding because highestBet \(highestBet) > bbAmount \(bbAmount)")
    }
} else {
    print("3BET MODE DEBUG: AI folding because currentIndex \(currentIndex) >= humanIndex \(humanIndex)")
}
