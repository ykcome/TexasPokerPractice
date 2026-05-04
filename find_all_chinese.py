import os
import re
import json

def find_chinese():
    swift_files = []
    for root, dirs, files in os.walk("Sources"):
        for file in files:
            if file.endswith(".swift"):
                swift_files.append(os.path.join(root, file))

    output = []
    for f in swift_files:
        with open(f, "r", encoding="utf-8") as file:
            lines = file.readlines()
            for i, line in enumerate(lines):
                matches = re.findall(r'"([^"]*[\u4e00-\u9fa5][^"]*)"', line)
                if matches:
                    for m in matches:
                        # Skip if it is part of PokerCoachEngine dual comments (has \n)
                        if "\\n" in m: continue
                        output.append(f"{f}:{i+1}: {m}")
    return output

out = find_chinese()
with open("chinese_strings.txt", "w", encoding="utf-8") as f:
    f.write("\n".join(out))
print(f"Found {len(out)} chinese strings in swift files")
