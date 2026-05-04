import json

with open('/Users/zhengliu/.openclaw/workspace/texaspoker/TexasPoker/Sources/Resources/Localizable.xcstrings', 'r') as f:
    data = json.load(f)

# Delete old key if exists
old_key = "2. 每天系统自动恢复至5点体力值，另外每天最多可额外领取15点免费体力值（分5次）。"
if old_key in data["strings"]:
    del data["strings"][old_key]

new_key = "2. 每天系统自动恢复至3点体力值，另外每天最多可额外领取9点免费体力值（分3次）。"
data["strings"][new_key] = {
    "extractionState": "manual",
    "localizations": {
        "en": {
            "stringUnit": {
                "state": "translated",
                "value": "2. Stamina automatically restores to 3 points daily. You can also claim up to 9 additional free stamina points per day (in 3 claims)."
            }
        },
        "zh-Hans": {
            "stringUnit": {
                "state": "translated",
                "value": "2. 每天系统自动恢复至3点体力值，另外每天最多可额外领取9点免费体力值（分3次）。"
            }
        }
    }
}

with open('/Users/zhengliu/.openclaw/workspace/texaspoker/TexasPoker/Sources/Resources/Localizable.xcstrings', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
