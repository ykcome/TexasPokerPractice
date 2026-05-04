import json

with open('/Users/zhengliu/.openclaw/workspace/texaspoker/TexasPoker/Sources/Resources/Localizable.xcstrings', 'r') as f:
    data = json.load(f)

key = "免费领取 %lld 体力值 (今日剩余 %lld 次)"

if key in data["strings"]:
    data["strings"][key] = {
        "extractionState": "manual",
        "localizations": {
            "en": {
                "stringUnit": {
                    "state": "translated",
                    "value": "Claim %lld Free Stamina (%lld times left today)"
                }
            },
            "zh-Hans": {
                "stringUnit": {
                    "state": "translated",
                    "value": "免费领取 %lld 体力值 (今日剩余 %lld 次)"
                }
            }
        }
    }

with open('/Users/zhengliu/.openclaw/workspace/texaspoker/TexasPoker/Sources/Resources/Localizable.xcstrings', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
