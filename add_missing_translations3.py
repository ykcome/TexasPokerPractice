import json

with open('/Users/zhengliu/.openclaw/workspace/texaspoker/TexasPoker/Sources/Resources/Localizable.xcstrings', 'r') as f:
    data = json.load(f)

# The dictionary of missing translations
missing = {
    "不错的 3Bet 诈唬。面对频繁偷盲的对手，用这手牌反击可以赢下底池。": "Nice 3Bet bluff. Counter-attacking frequent stealers with this hand can win the pot.",
    "你放弃了偷盲的机会！在后位，你应该用这手牌加注向盲注施压。": "You missed a steal opportunity! From late position, you should raise to pressure the blinds.",
    "你的 3Bet 过于激进。手牌不够强时，面对前位加注进行 3Bet 容易陷入被动或损失筹码。": "Your 3Bet is too aggressive. With a weak hand facing early position raise, 3Betting can trap you or cost chips.",
    "你的偷盲范围太宽了。用毫无联系的垃圾牌加注很容易被反击。": "Your steal range is too wide. Raising with uncoordinated junk hands easily invites counter-attacks.",
    "你的反击太激进了。用垃圾牌 3Bet 风险过大。": "Your counter-attack is too aggressive. 3Betting with trash hands is too risky.",
    "你防守得太紧了。大盲位有很好的赔率，这手牌值得跟注或 3Bet。": "You are defending too tight. The big blind offers great odds; this hand is worth calling or 3Betting.",
    "在短码阶段，只跟注是不好的策略。你应该全押(Push)或者弃牌(Fold)来最大化你的弃牌率。": "In the short stack phase, calling is a poor strategy. You should Push or Fold to maximize fold equity.",
    "太保守了！在 %lldBB 的深度，这手牌绝对值得全押一搏。": "Too conservative! At %lld BBs deep, this hand is absolutely worth shoving.",
    "太紧了！你放弃了一手优质牌，这里绝对应该 3Bet。": "Too tight! You folded a premium hand; you should definitely 3Bet here.",
    "好弃牌！面对前位加注，边缘牌和垃圾牌果断弃掉是赢家的素养。": "Good fold! Folding marginal and junk hands against early position raises is the mark of a winner.",
    "好弃牌。保留短码等待更好的起手牌。": "Good fold. Preserve your short stack for a better starting hand.",
    "很好的偷盲加注！在庄家或小盲位，用宽范围施压是极佳的策略。": "Great steal raise! Pressuring from the button or small blind with a wide range is an excellent strategy.",
    "手牌偏弱，这里跟注前位加注会让你在翻后面临困难，建议弃牌。": "Your hand is too weak. Calling an early position raise here will put you in a tough spot post-flop. Recommend folding.",
    "手牌很强，只选择跟注过于被动了。这里应该 3Bet 来压榨价值并夺取主动权。": "Your hand is very strong; just calling is too passive. You should 3Bet to extract value and seize the initiative.",
    "手牌这么强，你应该加注建立底池。": "With such a strong hand, you should raise to build the pot.",
    "无效动作": "Invalid Action",
    "暂无记录": "No Records",
    "标准的价值加注。你在后位拿到强牌，加注理所应当。": "Standard value raise. You got a strong hand in late position, raising is the right play.",
    "标准的防守跟注。你在大盲位有很好的赔率，看看翻牌是可以的。": "Standard defensive call. You get good pot odds in the big blind, seeing a flop is fine.",
    "正确的弃牌。牌太差不值得偷盲。": "Correct fold. The hand is too weak to steal with.",
    "正确的弃牌。面对加注，果断放弃垃圾牌。": "Correct fold. Facing a raise, decisively folding junk hands is correct.",
    "漂亮的 3Bet！你拿到了优质手牌，进行 3Bet 获取价值并夺取主动权是非常正确的决定。": "Beautiful 3Bet! You hold a premium hand, 3Betting for value and taking initiative is absolutely correct.",
    "漂亮的 Push！在 %lldBB 的深度，拿到有胜率的手牌全押施压是正确的。": "Nice Push! At %lld BBs deep, shoving with a hand that has good equity is correct."
}

for key, en_text in missing.items():
    if key in data["strings"] and data["strings"][key] == {}:
        data["strings"][key] = {
            "extractionState": "manual",
            "localizations": {
                "en": {
                    "stringUnit": {
                        "state": "translated",
                        "value": en_text
                    }
                }
            }
        }

with open('/Users/zhengliu/.openclaw/workspace/texaspoker/TexasPoker/Sources/Resources/Localizable.xcstrings', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
