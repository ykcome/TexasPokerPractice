import json

with open("Sources/Resources/Localizable.xcstrings", "r", encoding="utf-8") as f:
    data = json.load(f)

new_strings = {
    "用 AA/KK 在大盲位只跟注，给了加注玩家太好的隐含赔率去击中两对或三条。": "Just calling with AA/KK in the big blind gives the raiser great implied odds to hit two pair or a set.",
    "大盲位防守范围太窄，面对后位加注弃牌过多，损失了防守价值。": "Your big blind defense range is too narrow. Folding too often to late position raises loses defensive value."
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
