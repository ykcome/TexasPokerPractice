import json

file_path = '/Users/zhengliu/.openclaw/workspace/texaspoker/TexasPoker/Sources/Resources/Localizable.xcstrings'

with open(file_path, 'r') as f:
    data = json.load(f)

old_keys = [
    "入场积分：%lld",
    "奖励积分：%lld"
]
for k in old_keys:
    if k in data["strings"]:
        del data["strings"][k]

new_keys = {
    "消耗体力值：%lld": "Cost Stamina: %lld",
    "奖励体力值：%lld": "Reward Stamina: %lld"
}

for k, v in new_keys.items():
    data["strings"][k] = {
        "localizations": {
            "en": {
                "stringUnit": {
                    "state": "translated",
                    "value": v
                }
            },
            "zh-Hans": {
                "stringUnit": {
                    "state": "translated",
                    "value": k
                }
            }
        }
    }

with open(file_path, 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print("Updated stamina translation strings")