import json

with open("Sources/Resources/Localizable.xcstrings", "r", encoding="utf-8") as f:
    data = json.load(f)

new_strings = {
    "这手牌牌力偏弱，即使在后位也建议弃牌。": "This hand is too weak; even in late position, folding is recommended.",
    "不错的弃牌。面对激进的盲注玩家，放弃边缘牌是合理的。": "Good fold. Against aggressive blinds, folding marginal hands is reasonable.",
    "保守但安全的打法。在偷盲位也可以选择性放弃较弱的手牌。": "A conservative but safe play. It's okay to selectively fold weaker hands even in a steal position."
}

for k, v in new_strings.items():
    data["strings"][k] = {
        "extractionState": "manual",
        "localizations": {
            "en": {
                "stringUnit": {
                    "state": "translated",
                    "value": v
                }
            }
        }
    }

with open("Sources/Resources/Localizable.xcstrings", "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
