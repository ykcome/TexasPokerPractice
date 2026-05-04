import json

xcstrings_path = "Sources/Resources/Localizable.xcstrings"
with open(xcstrings_path, "r", encoding='utf-8') as f:
    data = json.load(f)

new_keys = {
    "无明显标签": "None",
    "负EV跟注/全押": "Negative EV Call/All-in",
    "强牌被动": "Passive Value",
    "强牌投入偏小": "Small sizing (strong hand)",
    "标准持续施压": "Standard continuation play",
    "好弃牌": "Good Fold",
    "好的诈唬时机": "Good Bluff Opportunity",
    "打得太紧": "Too Tight",
    "Bad Beat (运气极差)": "Bad Beat",
    "未知": "Unknown"
}

count = 0
for k, v in new_keys.items():
    if k not in data["strings"]:
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
        count += 1
    else:
        # If it exists, ensure 'en' is translated
        if "en" not in data["strings"][k].get("localizations", {}):
            if "localizations" not in data["strings"][k]:
                data["strings"][k]["localizations"] = {}
            data["strings"][k]["localizations"]["en"] = {
                "stringUnit": {
                    "state": "translated",
                    "value": v
                }
            }
            count += 1

with open(xcstrings_path, "w", encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print(f"Added {count} new keys.")
