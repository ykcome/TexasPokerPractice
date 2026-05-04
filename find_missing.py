import json
import re
import os

swift_files = []
for root, dirs, files in os.walk("Sources"):
    for file in files:
        if file.endswith(".swift"):
            swift_files.append(os.path.join(root, file))

strings_in_code = set()
for f in swift_files:
    with open(f, "r", encoding='utf-8') as file:
        content = file.read()
        matches = re.findall(r'String\(localized:\s*"([^"]+)"\)', content)
        for m in matches:
            if any(char >= "\u4e00" and char <= "\u9fa5" for char in m):
                strings_in_code.add(m)

xcstrings_path = "Sources/Resources/Localizable.xcstrings"
with open(xcstrings_path, "r", encoding='utf-8') as f:
    data = json.load(f)

missing = []
for s in strings_in_code:
    if s not in data["strings"]:
        missing.append(s)

with open("missing_in_json.txt", "w", encoding='utf-8') as f:
    f.write("\n".join(missing))
