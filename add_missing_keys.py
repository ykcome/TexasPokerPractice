import json

xcstrings_path = "Sources/Resources/Localizable.xcstrings"
with open(xcstrings_path, "r", encoding='utf-8') as f:
    data = json.load(f)

new_keys = {
    "练习开始！": "Practice Started!",
    "比赛开始！": "Tournament Started!",
    "底分升级！级别 %lld: %lld/%lld": "Blinds Up! Level %lld: %lld/%lld",
    "无效动作": "Invalid Action",
    "摊牌！": "Showdown!",
    "该场战绩生成于旧版本，未关联牌谱": "This record is from an older version, no hand history attached.",
    "加载牌谱失败": "Failed to load hand history"
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
