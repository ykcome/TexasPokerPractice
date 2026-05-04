import json

xcstrings_path = "Sources/Resources/Localizable.xcstrings"
with open(xcstrings_path, "r", encoding='utf-8') as f:
    data = json.load(f)

key = "盲注 L\\(history.blindLevel) \\(history.sbAmount)/\\(history.bbAmount) 前注 \\(history.anteAmount)"
if key in data["strings"]:
    val = data["strings"][key]
    if "localizations" in val and "en" in val["localizations"]:
        val["localizations"]["en"]["stringUnit"]["value"] = "Blinds L\\(history.blindLevel) \\(history.sbAmount)/\\(history.bbAmount) Ante \\(history.anteAmount)"

with open(xcstrings_path, "w", encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print("Fixed blinds string interpolation translation.")
