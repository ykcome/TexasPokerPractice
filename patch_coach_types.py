import re

with open("Sources/GameLogic/PokerCoachEngine.swift", "r") as f:
    content = f.read()

types_str = """
// MARK: - 评价建议
struct CoachAdvice: Equatable {
    let tag: PlayTag
    let comment: String
}

struct CoachContext {
    let position: String
    let stackBB: Double
    let playersRemaining: Int
}

// MARK: - 评价标签枚举
"""
content = content.replace("// MARK: - 评价标签枚举\n", types_str)

with open("Sources/GameLogic/PokerCoachEngine.swift", "w") as f:
    f.write(content)
