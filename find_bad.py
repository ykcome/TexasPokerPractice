import json

loc_file = "Sources/Resources/Localizable.xcstrings"
with open(loc_file, "r", encoding="utf-8") as f:
    xc = json.load(f)

output = []

for k, v in xc["strings"].items():
    if "en" in v.get("localizations", {}):
        en_val = v["localizations"]["en"]["stringUnit"]["value"]
        if any(char >= "\u4e00" and char <= "\u9fa5" for char in en_val):
            output.append(f"KEY: {k}\nEN: {en_val}\n")

with open("bad_en_translations.txt", "w", encoding="utf-8") as f:
    f.write("\n".join(output))
