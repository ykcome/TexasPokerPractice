import json

translations = {
    "下一局": "Next Hand"
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

print("Next Hand translation applied.")
