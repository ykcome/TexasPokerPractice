import json

with open("Sources/Resources/Localizable.xcstrings", "r", encoding="utf-8") as f:
    data = json.load(f)

new_strings = {
    "用顶级强牌直接全下！这是非常激进但也非常有效的价值榨取。": "Shoving directly with a premium hand! A highly aggressive but effective way to extract value.",
    "非常暴力的反击！用强牌全下可以立刻给对手施加极大的压力。": "A fierce counter-attack! Shoving a strong hand puts immense pressure on your opponent immediately.",
    "用中等牌力或同花连张全下作为半诈唬，具有一定的弃牌率，但风险较高。": "Shoving medium strength hands or suited connectors as a semi-bluff generates fold equity, but it carries high risk.",
    "激进的防守策略！这手牌有一定的胜率，全下可以最大化你的弃牌率。": "An aggressive defensive strategy! This hand has some equity, and shoving maximizes your fold equity.",
    "太疯狂了！用弱牌在盲注位全下是极其危险的。": "Too crazy! Shoving a weak hand from the blinds is extremely dangerous.",
    "毫无逻辑的全下。面对加注，用弱牌直接拼命会导致快速破产。": "An illogical shove. Risking everything with a weak hand facing a raise will quickly lead to ruin."
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
