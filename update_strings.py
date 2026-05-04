import json
import os

path = '/Users/zhengliu/.openclaw/workspace/texaspoker/TexasPoker/Sources/Resources/Localizable.xcstrings'

with open(path, 'r', encoding='utf-8') as f:
    data = json.load(f)

new_strings = {
    "1. 本产品为纯粹的德州扑克教学与训练工具，体力值仅作为开启训练的门票消耗。": "1. This product is strictly a Texas Hold'em educational and training tool. Stamina is only consumed as an entry ticket for training sessions.",
    "2. 每天系统自动恢复至3点体力值，另外每天最多可额外免费领取300点（分3次，每次100点）。训练过程中的盈亏不影响体力值。": "2. Stamina auto-recovers to 3 points daily. You can claim up to 300 free stamina points daily (3 times, 100 points each). Winning or losing in training does not affect stamina.",
    "3. 教学工具开发不易，自愿支持开发者一杯咖啡，将获赠1000点体力值以供长期训练，谢谢！": "3. Developing educational tools takes effort. Support the developer with a coffee, and you'll receive 1000 stamina points for long-term training. Thank you!",
    "支持开发者 (%@) - 赠1000体力": "Support Developer (%@) - Get 1000 Stamina",
    "支持开发者 - 赠1000体力": "Support Developer - Get 1000 Stamina",
    "感谢支持！已获得1000点体力值": "Thanks for your support! 1000 Stamina received."
}

for zh, en in new_strings.items():
    if zh not in data['strings']:
        data['strings'][zh] = {
            "extractionState": "manual",
            "localizations": {
                "en": {
                    "stringUnit": {
                        "state": "translated",
                        "value": en
                    }
                }
            }
        }

with open(path, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print("Updated Localizable.xcstrings successfully.")
