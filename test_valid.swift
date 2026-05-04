let highestBet = 20
let lastRaiseAmount = 20
let bbAmount = 20
let playerChips = 1990
let playerCurrentBet = 10
let amountToCall = highestBet - playerCurrentBet
let minRaise = lastRaiseAmount > 0 ? lastRaiseAmount : bbAmount
let minRaiseAmount = amountToCall + minRaise
let canRaise = amountToCall > 0 && (highestBet + minRaise <= playerChips + playerCurrentBet)

print("canRaise: \(canRaise), minRaiseAmount: \(minRaiseAmount)")
