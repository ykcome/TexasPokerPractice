import Foundation

let minBet = 20
let highestBet = 20
let lastRaiseAmount = 20
let amountToCall = 0

let isFirstBettor = false

let minRaiseAmount: Int
if isFirstBettor || highestBet == 0 {
    minRaiseAmount = minBet
} else {
    minRaiseAmount = highestBet + lastRaiseAmount
}
print("minRaiseAmount: \(minRaiseAmount)")

let playerCurrentBet = 20
let playerChips = 1980

let phase = "preflop"
let isPreflopBlindWithNoRaise = phase == "preflop" && amountToCall == 0 && !isFirstBettor
let amountNeededToRaise = minRaiseAmount - playerCurrentBet
let canRaise = !isFirstBettor && (amountToCall > 0 || isPreflopBlindWithNoRaise) && amountNeededToRaise <= playerChips

print("isPreflopBlindWithNoRaise: \(isPreflopBlindWithNoRaise)")
print("amountNeededToRaise: \(amountNeededToRaise)")
print("canRaise: \(canRaise)")

