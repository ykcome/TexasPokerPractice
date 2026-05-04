import json
import sys

filepath = "/Users/zhengliu/.openclaw/workspace/texaspoker/TexasPoker/Sources/Resources/Localizable.xcstrings"

with open(filepath, 'r', encoding='utf-8') as f:
    data = json.load(f)

new_key = "练习积分不足，明天可以继续领积分"
new_val = {
  "extractionState" : "manual",
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Insufficient practice points. You can claim more tomorrow."
      }
    }
  }
}

if new_key not in data['strings']:
    data['strings'][new_key] = new_val

with open(filepath, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

