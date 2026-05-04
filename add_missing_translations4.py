import json

with open('/Users/zhengliu/.openclaw/workspace/texaspoker/TexasPoker/Sources/Resources/Localizable.xcstrings', 'r') as f:
    data = json.load(f)

# The dictionary of missing translations
missing = {
    "确认下注": "Confirm Bet",
    "确认加注": "Confirm Raise",
    "第 %lld 名": "%lld Place",
    "第一名": "1st Place",
    "练习场": "Practice",
    "练习结束": "Practice Ended",
    "练习记录": "Practice History",
    "跛入（Limp）不是好习惯。如果要打这手牌，你应该加注来偷盲。": "Limping is a bad habit. If you want to play this hand, you should raise to steal the blinds.",
    "跟注是可以接受的。手牌有一定可玩性，但不值得 3Bet 冒险。": "Calling is acceptable. The hand has some playability but isn't worth risking a 3Bet.",
    "这个全押有点松。虽然筹码不多，但这手牌赢率太低，建议等待更好的时机。": "This shove is a bit loose. Even with a short stack, this hand has too little equity. Recommend waiting for a better spot.",
    "这手牌你应该 3Bet 获取价值，而不是只跟注。": "You should 3Bet this hand for value instead of just calling.",
    "这手牌太差了，即使有底池赔率也不建议跟注。": "This hand is too bad. Even with pot odds, calling is not recommended.",
    "重大失误！你放弃了一手顶级牌。": "Major mistake! You folded a premium hand.",
    "重新开始 1v1 HU 练习": "Restart 1v1 HU Practice",
    "非常棒的 3Bet！面对偷盲，用强牌反击获取价值。": "Excellent 3Bet! Countering a steal with a strong hand to extract value."
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
