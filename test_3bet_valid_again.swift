import Foundation

let phase = "preflop"
let amountToCall = 0 // Since highest bet is BB, and player is SB, they owe BB - SB? Wait, 3bet is UTG/MP/CO/BTN... wait
// In 3Bet practice, it's 2 players. Human and Coco. Coco is Button, Human is BB.
// Coco (Button) posts SB (10). Human posts BB (20).
// Preflop: Coco acts first. Coco is SB (Button in HU). 
let playerCurrentBet = 10
let highestBet = 20
let amountToCall2 = highestBet - playerCurrentBet // 10
let isFirstBettor = false // Because he has to call the BB

let lastRaiseAmount = 20 // In preflop, last raise is BB amount
let minRaiseAmount = highestBet + lastRaiseAmount // 40

let playerChips = 1990 // Since he posted 10

let isPreflopBlindWithNoRaise = phase == "preflop" && amountToCall2 == 0 && !isFirstBettor
let amountNeededToRaise = minRaiseAmount - playerCurrentBet // 40 - 10 = 30
let canRaise = !isFirstBettor && (amountToCall2 > 0 || isPreflopBlindWithNoRaise) && amountNeededToRaise <= playerChips

print("canRaise: \(canRaise)")
print("amountNeededToRaise: \(amountNeededToRaise)")
print("isPreflopBlindWithNoRaise: \(isPreflopBlindWithNoRaise)")
print("amountToCall: \(amountToCall2)")

