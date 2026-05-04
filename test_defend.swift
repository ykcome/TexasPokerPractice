let reverseCycle = [6, 5, 4, 3, 2, 1]
let humanSeat = 4
let humanIdx = reverseCycle.firstIndex(of: humanSeat) ?? 0
let seatBeforeHuman = reverseCycle[(humanIdx + 1) % reverseCycle.count]
let buttonSeat = reverseCycle[(humanIdx + 2) % reverseCycle.count]
print("Human: \(humanSeat), SB (expected): \(seatBeforeHuman), BTN: \(buttonSeat)")
