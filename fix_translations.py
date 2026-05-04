import json
import re

translations = {
    "免费获取金币": "Free Coins",
    "金币不足": "Not Enough Coins",
    "当前金币：%lld": "Current Coins: %lld",
    "免费领取%lld金币 (今日剩余%lld次)": "Claim %lld Free Coins (%lld left today)",
    "赞助一杯咖啡 (%@), 获取10000金币": "Buy a Coffee (%@), Get 10000 Coins",
    "赞助一杯咖啡, 获取10000金币": "Buy a Coffee, Get 10000 Coins",
    "处理中…": "Processing...",
    "重新加载商品": "Reload Products",
    "加载中…": "Loading...",
    "第一名！获得%lld金币": "1st Place! Won %lld Coins",
    "第二名！获得%lld金币": "2nd Place! Won %lld Coins",
    "已领取%lld金币": "Claimed %lld Coins",
    "已获得%lld金币": "Received %lld Coins",
    "赞助成功！已获得10000金币": "Thank you! Received 10000 Coins",
    "今日免费领取次数已达上限": "Daily free claim limit reached",
    "商品加载失败：%@": "Failed to load products: %@",
    "购买失败：%@": "Purchase failed: %@",
    "同步失败：%@": "Sync failed: %@",
    "轮到你（需跟注 %lld）": "Your turn (Call %lld)",
    "轮到你": "Your turn",
    "%@ 思考中...": "%@ is thinking...",
    "赢家: %@ +%lld": "Winner: %@ +%lld",
    "%@ 赢+%lld": "%@ wins +%lld",
    "%@ 退回+%lld": "%@ returned +%lld",
    "🏆 冠军: %@！": "🏆 Champion: %@!",
    "%@ 弃牌": "%@ Folds",
    "%@ 过牌": "%@ Checks",
    "%@ 跟注 %lld": "%@ Calls %lld",
    "%@ 下注 %lld": "%@ Bets %lld",
    "%@ 加注 %lld": "%@ Raises %lld",
    "%@ 全下 %lld": "%@ All-in %lld",
    "单机德州扑克": "Texas Hold'em Offline",
    "单人锦标赛": "Single Player SNG",
    "单人常规桌": "Single Player Cash Game",
    "开始游戏": "Start Game",
    "继续游戏": "Resume Game",
    "设置": "Settings",
    "玩家资料": "Player Profile",
    "历史战绩": "Hand History",
    "退出游戏": "Quit Game",
    "弃牌": "Fold",
    "过牌": "Check",
    "跟注": "Call",
    "下注": "Bet",
    "加注": "Raise",
    "全下": "All-in",
    "底池": "Pot",
    "买入": "Buy-in",
    "盲注": "Blinds",
    "筹码": "Chips",
    "确定": "OK",
    "取消": "Cancel",
    "提示": "Notice",
    "警告": "Warning",
    "错误": "Error",
    "成功": "Success",
    "暂无数据": "No Data",
    "历史记录": "History",
    "返回": "Back",
    "分享": "Share",
    "保存": "Save",
    "删除": "Delete",
    "总胜率": "Win Rate",
    "入池率": "VPIP",
    "激进率": "PFR",
    "3-Bet率": "3-Bet Rate",
    "SNG 历史记录": "SNG History",
    "历史牌谱": "Hand History",
    "金币": "Coins",
    "等级": "Level",
    "经验": "EXP",
    "胜场": "Wins",
    "败场": "Losses",
    "平局": "Ties",
    "总局数": "Total Games",
    "胜率": "Win Rate",
    "最大赢取": "Biggest Win",
    "最大损失": "Biggest Loss",
    "最佳牌型": "Best Hand",
    "最近更新": "Last Updated",
    "时间": "Time",
    "地点": "Location",
    "玩家": "Player",
    "AI玩家": "AI Player",
    "游戏结束": "Game Over",
    "游戏开始": "Game Starts",
    "盲注升级": "Blinds Up",
    "玩家淘汰": "Player Eliminated",
    "玩家胜利": "Player Wins",
    "平分底池": "Split Pot",
    "摊牌": "Showdown",
    "发牌": "Deal Cards",
    "翻牌前": "Preflop",
    "翻牌": "Flop",
    "转牌": "Turn",
    "河牌": "River",
    "小盲": "Small Blind",
    "大盲": "Big Blind",
    "庄家": "Dealer",
    "枪口": "UTG",
    "关位": "CO",
    "中间位置": "MP",
    "前位": "Early Position",
    "中位": "Middle Position",
    "后位": "Late Position",
    "胜率评估": "Equity Eval",
    "牌力": "Hand Strength",
    "听牌": "Draw",
    "成牌": "Made Hand",
    "高牌": "High Card",
    "一对": "One Pair",
    "两对": "Two Pair",
    "三条": "Three of a Kind",
    "顺子": "Straight",
    "同花": "Flush",
    "葫芦": "Full House",
    "四条": "Four of a Kind",
    "同花顺": "Straight Flush",
    "皇家同花顺": "Royal Flush",
    "踢脚": "Kicker",
    "未知": "Unknown",
    "买入: %lld": "Buy-in: %lld",
    "奖金: %lld": "Reward: %lld",
    "还没有战绩，去打一把SNG吧！": "No records yet, go play a SNG!",
    "入围率 (ITM)": "ITM Rate",
    "6人SNG": "6-Max SNG",
    "第%lld名": "%lld Place",
    "第%@名": "%@ Place"
}

xcstrings_path = "Sources/Resources/Localizable.xcstrings"
with open(xcstrings_path, "r", encoding='utf-8') as f:
    data = json.load(f)

for key, val in data["strings"].items():
    # If key contains \\( it's the raw source string that Xcode mistakenly extracted as manual, we can ignore or delete it,
    # because SwiftUI will look for the %lld / %@ version.
    
    # Try exact match
    eng_val = translations.get(key)
    
    # Auto-translate
    if not eng_val:
        if "次" in key and "场" in key:
            pass # custom logic if needed
        elif "名" in key and "第" in key:
            eng_val = key.replace("第", "").replace("名", " Place")
        elif "局" in key and "场" in key:
            eng_val = key.replace("场", " Games")
            
    if eng_val:
        if "localizations" not in val:
            val["localizations"] = {}
        val["localizations"]["en"] = {
            "stringUnit": {
                "state": "translated",
                "value": eng_val
            }
        }
    else:
        # Fallback basic copy
        if "localizations" not in val:
            val["localizations"] = {}
        # don't overwrite if it exists
        if "en" not in val["localizations"]:
            pass # keep it untranslated for now to avoid breaking

with open(xcstrings_path, "w", encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print("Translations applied.")
