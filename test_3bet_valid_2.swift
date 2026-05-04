import Foundation

let playerBet = 10
let highestBet = 20
let amountToCall = highestBet - playerBet
let playerChips = 990
let isFirstBettor = false

let lastRaiseAmount = 20
let minRaiseAmount = highestBet + lastRaiseAmount

let phase = "preflop"

let isPreflopBlindWithNoRaise = phase == "preflop" && amountToCall == 0 && !isFirstBettor
let canRaise = !isFirstBettor && (amountToCall > 0 || isPreflopBlindWithNoRaise) && minRaiseAmount <= playerChips + playerBet // note player chips are remaining

print("canRaise: \(canRaise)")
