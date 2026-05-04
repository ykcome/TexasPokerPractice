import Foundation

let validAllInAmount = 1980
let validMinRaise = 40
let amount = 160
let playerCurrentBet = 10
let maxTotalBet = playerCurrentBet + validAllInAmount
let clamped = max(validMinRaise, min(amount, maxTotalBet))
print("clamped: \(clamped), maxTotalBet: \(maxTotalBet)")

