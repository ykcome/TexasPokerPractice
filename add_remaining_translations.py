import json
import re

translations = {
    # Main UI Strings missing from previous passes
    "SNG 6人桌": "6-Max SNG",
    "小盲": "Small Blind",
    "大盲": "Big Blind",
    "前注": "Ante",
    "级别": "Level",
    "金币": "Coins",
    "弃牌": "Fold",
    "跟注": "Call",
    "全下": "All-in",
    "轮到你": "Your turn",
    "需跟注": "To call",
    "玩家主页": "Player Profile",
    "跳过本局": "Skip Hand",
    "关闭": "Close",
    "总场次": "Total Games",
    "冠军次数": "Wins",
    "入围率": "ITM Rate",
    "战绩回顾": "Hand History",
    "还没有战绩，去打一把SNG吧！": "No records yet, go play a SNG!",
    
    # Player Names
    "Jack": "Jack",
    "Rain": "Rain",
    "Coco": "Coco",
    "Zhe": "Zhe",
    "Player": "Player",
    "Lan": "Lan",
    
    # Hand History detail replacements
    "玩家": "Player",
    "入围率 (ITM)": "ITM Rate",
    "第%lld名": "%lld Place",
    "第%@名": "%@ Place"
}

xcstrings_path = "Sources/Resources/Localizable.xcstrings"
with open(xcstrings_path, "r", encoding='utf-8') as f:
    data = json.load(f)

for s, eng_val in translations.items():
    if s not in data["strings"]:
        data["strings"][s] = {
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
        val = data["strings"][s]
        if "localizations" not in val:
            val["localizations"] = {}
        val["localizations"]["en"] = {
            "stringUnit": {
                "state": "translated",
                "value": eng_val
            }
        }

with open(xcstrings_path, "w", encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print("Remaining UI Translations applied.")
