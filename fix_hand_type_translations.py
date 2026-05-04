import json

xcstrings_path = "Sources/Resources/Localizable.xcstrings"
with open(xcstrings_path, "r", encoding='utf-8') as f:
    data = json.load(f)

keys_to_add = {
    "高牌": "High Card",
    "一对": "One Pair",
    "两对": "Two Pair",
    "三条": "Three of a Kind",
    "顺子": "Straight",
    "同花": "Flush",
    "葫芦": "Full House",
    "四条": "Four of a Kind",
    "同花顺": "Straight Flush",
    "皇家同花顺": "Royal Flush"
}

for k, eng_val in keys_to_add.items():
    if k not in data["strings"]:
        data["strings"][k] = {
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
        val = data["strings"][k]
        if "localizations" not in val:
            val["localizations"] = {}
        if "en" not in val["localizations"]:
            val["localizations"]["en"] = {}
        if "stringUnit" not in val["localizations"]["en"]:
            val["localizations"]["en"]["stringUnit"] = {}
            
        val["localizations"]["en"]["stringUnit"]["state"] = "translated"
        val["localizations"]["en"]["stringUnit"]["value"] = eng_val

with open(xcstrings_path, "w", encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print("Hand type translations added.")
