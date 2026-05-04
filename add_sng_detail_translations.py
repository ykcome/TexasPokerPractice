import json

translations = {
    "翻牌前": "Preflop",
    "翻牌圈": "Flop",
    "转牌圈": "Turn",
    "河牌圈": "River",
    "前注": "Ante",
    "小盲": "Small Blind",
    "大盲": "Big Blind",
    "弃牌": "Fold",
    "过牌": "Check",
    "跟注": "Call",
    "下注": "Bet",
    "加注": "Raise",
    "全下": "All-in",
    "赢得": "Win"
}

xcstrings_path = "Sources/Resources/Localizable.xcstrings"
with open(xcstrings_path, "r", encoding='utf-8') as f:
    data = json.load(f)

for s, eng_val in translations.items():
    if s not in data["strings"]:
        data["strings"][s] = {
            "extractionState": "manual",
            "localizations": {
                "en": {
                    "stringUnit": {
                        "state": "translated",
                        "value": eng_val
                    }
                }
            }
        }
    else:
        val = data["strings"][s]
        if "localizations" not in val:
            val["localizations"] = {}
        val["localizations"]["en"] = {
            "stringUnit": {
                "state": "translated",
                "value": eng_val
            }
        }

with open(xcstrings_path, "w", encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print("SNG Detail translations applied.")
