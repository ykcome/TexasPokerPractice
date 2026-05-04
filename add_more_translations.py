import json

translations = {
    "小盲/大盲": "SB/BB",
    "SB/BB": "SB/BB",
    "前注": "Ante",
    "级别": "Level",
    "跳过本局": "Skip Hand",
    "关闭": "Close",
    "总场次": "Total Games",
    "冠军次数": "Wins",
    "入围率": "ITM Rate",
    "战绩回顾": "Hand History",
    "还没有战绩，去打一把SNG吧！": "No records yet, go play a SNG!"
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

print("More translations applied.")
