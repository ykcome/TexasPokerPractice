import Foundation

let playerChips = 990
let amountToCall = 0
let isFirstBettor = false // Because he is SB
let minRaiseAmount = 40 // bb + bb

let isPreflopBlindWithNoRaise = true // phase == .preflop && amountToCall == 0 && !isFirstBettor
let canRaise = !isFirstBettor && (amountToCall > 0 || isPreflopBlindWithNoRaise) && minRaiseAmount <= playerChips

print("canRaise: \(canRaise)")
