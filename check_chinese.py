import json

loc_file = "Sources/Resources/Localizable.xcstrings"
with open(loc_file, "r", encoding="utf-8") as f:
    xc = json.load(f)

for k, v in xc["strings"].items():
    if "en" in v.get("localizations", {}):
        en_val = v["localizations"]["en"]["stringUnit"]["value"]
        if any(char >= "\u4e00" and char <= "\u9fa5" for char in en_val):
            print(f"Key: {k}\nEnValue: {en_val}\n")
