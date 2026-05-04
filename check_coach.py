import json
import re

with open("Sources/GameLogic/GameManager.swift", "r", encoding="utf-8") as f:
    content = f.read()

matches = re.findall(r'String\(localized:\s*"([^"]+)"\)', content)

with open("Sources/Resources/Localizable.xcstrings", "r", encoding="utf-8") as f:
    data = json.load(f)

missing = []
for m in matches:
    if any(char >= "\u4e00" and char <= "\u9fa5" for char in m):
        if m not in data["strings"]:
            missing.append(f"Missing Key: {m}")
        else:
            en_loc = data["strings"][m].get("localizations", {}).get("en", {})
            if not en_loc:
                missing.append(f"Missing EN block: {m}")
            else:
                val = en_loc.get("stringUnit", {}).get("value", "")
                if not val or val == m:
                    missing.append(f"Bad EN value: {m} -> {val}")
                elif any(char >= "\u4e00" and char <= "\u9fa5" for char in val):
                    missing.append(f"Chinese in EN value: {m} -> {val}")

with open("coach_report.txt", "w", encoding="utf-8") as f:
    f.write("\n".join(missing))
