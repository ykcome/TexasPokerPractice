import json

with open('/Users/zhengliu/.openclaw/workspace/texaspoker/TexasPoker/Sources/Resources/Localizable.xcstrings', 'r') as f:
    data = json.load(f)

# Delete old key if exists
old_key = "重新开始 SNG 策略模拟器"
if old_key in data["strings"]:
    del data["strings"][old_key]

new_key = "重新开始 SNG 练习"
data["strings"][new_key] = {
    "extractionState": "manual",
    "localizations": {
        "en": {
            "stringUnit": {
                "state": "translated",
                "value": "Restart SNG Practice"
            }
        },
        "zh-Hans": {
            "stringUnit": {
                "state": "translated",
                "value": "重新开始 SNG 练习"
            }
        }
    }
}

with open('/Users/zhengliu/.openclaw/workspace/texaspoker/TexasPoker/Sources/Resources/Localizable.xcstrings', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
