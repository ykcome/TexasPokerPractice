import os
import re
import json

src_dir = "Sources"
strings = set()

# Regex to find Text("...") and String(localized: "...")
# Also Button("...")
regexes = [
    r'Text\(\s*"([^"]+)"',
    r'String\(localized:\s*"([^"]+)"\)',
    r'Button\(\s*"([^"]+)"',
    r'\.navigationTitle\(\s*"([^"]+)"',
    r'Label\(\s*"([^"]+)"',
    r'picker\(\s*"([^"]+)"'
]

for root, _, files in os.walk(src_dir):
    for f in files:
        if f.endswith(".swift"):
            with open(os.path.join(root, f), 'r', encoding='utf-8') as file:
                content = file.read()
                for r in regexes:
                    matches = re.findall(r, content)
                    for m in matches:
                        # Ignore empty or just symbols
                        if any(c.isalpha() or '\u4e00' <= c <= '\u9fa5' for c in m):
                            strings.add(m)

# Hardcoded dynamic strings we know
extra_strings = [
    "免费获取金币", "金币不足", "当前金币：%@", "免费领取%@金币 (今日剩余%@次)",
    "赞助一杯咖啡 (%@), 获取10000金币", "赞助一杯咖啡, 获取10000金币",
    "处理中…", "重新加载商品", "加载中…", "第一名！获得%@金币", "第二名！获得%@金币",
    "已领取%@金币", "已获得%@金币", "赞助成功！已获得10000金币", "商品加载失败：%@",
    "购买失败：%@", "同步失败：%@", "轮到你（需跟注 %@）", "轮到你", "%@ 思考中...",
    "赢家: %@ +%@", "%@ 赢+%@", "%@ 退回+%@", "🏆 冠军: %@！", "%@ 弃牌", "%@ 过牌",
    "%@ 跟注 %@", "%@ 下注 %@", "%@ 加注 %@", "%@ 全下 %@"
]
for s in extra_strings:
    strings.add(s)

# Load existing xcstrings
xcstrings_path = "Sources/Resources/Localizable.xcstrings"
with open(xcstrings_path, "r", encoding='utf-8') as f:
    data = json.load(f)

if "strings" not in data:
    data["strings"] = {}

for s in strings:
    if s not in data["strings"]:
        data["strings"][s] = {
            "extractionState": "manual",
            "localizations": {
                "en": {
                    "stringUnit": {
                        "state": "needs_review",
                        "value": s # Will be translated later
                    }
                }
            }
        }

with open(xcstrings_path, "w", encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print(f"Extracted {len(strings)} strings.")
