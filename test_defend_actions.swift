import Foundation

let highestBet = 20
let lastRaiseAmount = 20
let bbAmount = 20
let chips = 990
let currentBet = 10
let amountToCall = highestBet - currentBet

let canRaise = (amountToCall > 0) && (highestBet + lastRaiseAmount <= chips)
print("canRaise: \(canRaise)")
