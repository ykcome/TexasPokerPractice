import json

with open('/Users/zhengliu/.openclaw/workspace/texaspoker/TexasPoker/Sources/Resources/Localizable.xcstrings', 'r') as f:
    data = json.load(f)

# The dictionary of missing translations
missing = {
    "1. 本产品为纯单机模拟器，体力值仅用于进行模拟练习。": "1. This app is a standalone simulator. Stamina is used purely for practice.",
    "3. 模拟器开发不易，您可以选择自愿支持开发者一杯咖啡，谢谢！": "3. Developing this simulator is hard work. You can optionally support the developer with a cup of coffee. Thank you!",
    "1v1 HU 练习": "1v1 HU Practice",
    "3Bet 练习": "3Bet Practice",
    "6人 SNG 练习": "6-Max SNG Practice",
    "Defend 防守盲注": "Defend Practice",
    "Push/Fold 练习": "Push/Fold Practice",
    "Steal 偷盲练习": "Steal Practice",
    "SNG 6人桌": "SNG 6-Max",
    "专业练习模式": "Pro Practice Modes",
    "个人主页": "Profile",
    "主页": "Profile",
    "体力值": "Stamina",
    "体力值: %lld": "Stamina: %lld",
    "体力值不足": "Insufficient Stamina",
    "体力值不足，明天可以继续领体力值": "Insufficient stamina. You can claim more tomorrow.",
    "选择一个模式开始提升你的策略": "Select a mode to start improving your strategy",
    "欢迎练习，%@": "Welcome to practice, %@",
    "首页": "Home"
}

for key, en_text in missing.items():
    if key in data["strings"] and data["strings"][key] == {}:
        data["strings"][key] = {
            "extractionState": "manual",
            "localizations": {
                "en": {
                    "stringUnit": {
                        "state": "translated",
                        "value": en_text
                    }
                }
            }
        }

with open('/Users/zhengliu/.openclaw/workspace/texaspoker/TexasPoker/Sources/Resources/Localizable.xcstrings', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
