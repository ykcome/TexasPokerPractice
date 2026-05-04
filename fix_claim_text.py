import re

file_path = "/Users/zhengliu/.openclaw/workspace/texaspoker/TexasPoker/Sources/UI/Views/EconomySheetView.swift"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the text
content = re.sub(
    r'Text\(String\(localized: "免费领取\\\(economyManager\.buyInCoins\)练习积分"\)\)',
    r'Text(String(localized: "免费领取 \(economyManager.buyInCoins) 练习积分"))',
    content
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("EconomySheetView claim text updated.")
