import Foundation

let playerChips = 990
let playerCurrentBet = 10
let highestBet = 20
let lastRaiseAmount = 20

let amountToCall = highestBet - playerCurrentBet
let isFirstBettor = false

let minRaiseAmount = highestBet + lastRaiseAmount
let amountNeededToRaise = minRaiseAmount - playerCurrentBet

let isPreflopBlindWithNoRaise = true // phase == .preflop && amountToCall == 0 && !isFirstBettor
let canRaise = !isFirstBettor && (amountToCall > 0 || isPreflopBlindWithNoRaise) && amountNeededToRaise <= playerChips

print("canRaise: \(canRaise), minRaiseAmount: \(minRaiseAmount), amountNeededToRaise: \(amountNeededToRaise)")

let targetAmount = 80
let amountNeeded = targetAmount - playerCurrentBet
let raiseAmount = min(amountNeeded, playerChips)
print("amountNeeded: \(amountNeeded), raiseAmount: \(raiseAmount)")

