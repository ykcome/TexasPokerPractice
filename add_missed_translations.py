import json

translations = {
    # GameView
    "重新开始SNG": "Restart SNG",
    "级别: %lld": "Level: %lld",
    "金币: %lld": "Coins: %lld",
    "全押": "All-in",
    
    # PlayerProfileView
    "我的金币": "My Coins",
    "总场次": "Total Games",
    "冠军次数": "Wins",
    "入围率 (ITM)": "ITM Rate",
    "今天": "Today",
    "昨天": "Yesterday"
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

print("Missed translations applied.")
