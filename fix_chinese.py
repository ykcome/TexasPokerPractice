import json

xcstrings_path = "Sources/Resources/Localizable.xcstrings"
with open(xcstrings_path, "r", encoding='utf-8') as f:
    data = json.load(f)

translations = {
    "%@ 退回+%lld": "%@ returned +%lld",
    "%@ 跟注 %@": "%@ Calls %@",
    "%@ 下注 %@": "%@ Bets %@",
    "%@ 加注 %@": "%@ Raises %@",
    "%@ 全下 %@": "%@ All-in %@",
    "%@ 下注 %lld": "%@ Bets %lld",
    "%@ 加注 %lld": "%@ Raises %lld",
    "%@ 全押 %lld": "%@ All-in %lld",
    "%@ 全下 %lld": "%@ All-in %lld",
    "%@ 赢+%lld": "%@ won +%lld",
    "%@ 跟注 %lld": "%@ Calls %lld",
    "%@ 退回+%lld": "%@ returned +%lld",
    "1. 本产品为纯单机模拟器，练习币仅用于模拟器内对局，无任何实际价值。": "1. This product is a pure standalone simulator. Practice coins are only for simulated games and have no real value.",
    "2. 每天最多领取5次免费练习币，练习币不可转让，不可兑换现金或实物。": "2. Claim up to 5 free practice coins daily. Coins are non-transferable and cannot be exchanged for cash or physical goods.",
    "2. 每天系统自动恢复至3点体力值，另外每天最多可额外领取9点免费体力值（分3次）。": "2. Stamina restores to 3 points daily. You can claim up to 9 extra free stamina daily (in 3 batches).",
    "3. 模拟器开发不易，请支持开发者一杯咖啡，谢谢！": "3. Developing this simulator is not easy. Please support the developer with a cup of coffee, thank you!",
    "免费领取 %@ 积分 (今日剩余 %@ 次)": "Claim %@ Points (%@ left today)",
    "免费领取 %lld 体力值 (今日剩余 %lld 次)": "Claim %lld Stamina (%lld left today)",
    "免费领取 %lld 积分": "Claim %lld Points",
    "免费领取 %1$lld 积分 (今日剩余 %2$lld 次)": "Claim %1$lld Points (%2$lld left today)",
    "免费领取 1000 积分": "Claim 1000 Points",
    "免费领取 1000 积分 (今日剩余 %lld 次)": "Claim 1000 Points (%lld left today)",
    " Place次：\\(record.rank) Place": "\\(record.rank) Place",
    "奖励体力值：%lld": "Reward Stamina: %lld",
    "奖金: \\(record.reward)": "Reward: \\(record.reward)",
    "奖金：\\(record.reward)": "Reward: \\(record.reward)",
    "底分 L%1$lld %2$lld/%3$lld 前分 %4$lld": "Level %1$lld %2$lld/%3$lld Ante %4$lld",
    "座位\\(p.seat)": "Seat \\(p.seat)",
    "下注 \\(amount)": "Bet \\(amount)",
    "投入 %lld": "Bet %lld",
    "消耗体力值：%lld": "Stamina Cost: %lld",
    "级别: \\(gameManager.tournamentState.currentLevel)": "Level: \\(gameManager.tournamentState.currentLevel)",
    "赢家: %@ +%lld": "Winner: %@ +%lld",
    "跟注 \\(amount)": "Call \\(amount)",
    "跟注 %lld": "Call %lld",
    "轮到你（需跟注 \\(amount)）": "Your Turn (Call \\(amount))",
    "轮到你（需跟注 %lld）": "Your Turn (Call %lld)",
    "重新开始 SNG 练习": "Restart SNG Practice",
    "重要申明": "Important Notice"
}

count = 0

for k, v in data["strings"].items():
    if "en" in v.get("localizations", {}):
        en_val = v["localizations"]["en"]["stringUnit"]["value"]
        
        has_chinese = any(char >= "\u4e00" and char <= "\u9fa5" for char in en_val)
        
        if has_chinese:
            # Check translations dict
            if k in translations:
                v["localizations"]["en"]["stringUnit"]["value"] = translations[k]
                count += 1
            else:
                # Need to handle things like "免费领取..." directly
                if "免费领取" in k and "体力值" in k:
                    new_val = k.replace("免费领取", "Claim ").replace("体力值", "Stamina").replace(" (今日剩余", " (").replace("次)", " left today)")
                    v["localizations"]["en"]["stringUnit"]["value"] = new_val
                    count += 1
                elif "免费领取" in k and "积分" in k:
                    new_val = k.replace("免费领取", "Claim ").replace("积分", "Points").replace(" (今日剩余", " (").replace("次)", " left today)")
                    v["localizations"]["en"]["stringUnit"]["value"] = new_val
                    count += 1
                elif k == " Place次：\\(record.rank) Place":
                    v["localizations"]["en"]["stringUnit"]["value"] = "\\(record.rank) Place"
                    count += 1

with open(xcstrings_path, "w", encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print(f"Fixed {count} chinese translations.")
