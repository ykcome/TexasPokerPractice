import json

xcstrings_path = "Sources/Resources/Localizable.xcstrings"
with open(xcstrings_path, "r", encoding='utf-8') as f:
    data = json.load(f)

keys_to_update = {
    "赞助一杯咖啡 (%@), 获取10000金币": "Buy Me a Coffee (%@), get 10,000 coins",
    "赞助一杯咖啡, 获取10000金币": "Buy Me a Coffee, get 10,000 coins"
}

for k, eng_val in keys_to_update.items():
    if k in data["strings"]:
        val = data["strings"][k]
        if "localizations" not in val:
            val["localizations"] = {}
        if "en" not in val["localizations"]:
            val["localizations"]["en"] = {}
        if "stringUnit" not in val["localizations"]["en"]:
            val["localizations"]["en"]["stringUnit"] = {}
        
        val["localizations"]["en"]["stringUnit"]["state"] = "translated"
        val["localizations"]["en"]["stringUnit"]["value"] = eng_val

with open(xcstrings_path, "w", encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print("Translations updated.")
