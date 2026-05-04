import json

with open('/Users/zhengliu/.openclaw/workspace/texaspoker/TexasPoker/Sources/Resources/Localizable.xcstrings', 'r') as f:
    data = json.load(f)

# The dictionary of missing translations
missing = {
    "SNG Simulator": "SNG Simulator",
    "修改昵称": "Edit Name",
    "免费领取体力值": "Claim Free Stamina",
    "入圈率": "ITM Rate",
    "完整的6人桌SNG策略模拟。": "A complete 6-max SNG strategy simulation.",
    "在后位或小盲位，通过加注向盲注施压。": "Apply pressure to the blinds by raising from late position or the small blind.",
    "在大盲位面对偷盲加注，决定跟注、3Bet或弃牌。": "Decide whether to call, 3Bet, or fold when facing a steal raise in the big blind.",
    "已获得%lld体力值": "Received %lld stamina points",
    "已领取%lld体力值": "Claimed %lld stamina points",
    "当前体力值：%lld": "Current Stamina: %lld",
    "总局数": "Total Games",
    "模拟SNG后期单挑阶段，双方以20BB开始对抗。": "Simulate late-stage SNG Heads-Up play, both starting with 20BB.",
    "短码阶段(8-15BB)的全押与弃牌决策。": "Push/Fold decisions in the short stack stage (8-15BB).",
    "第一名次数": "1st Place Count",
    "面对前位加注，练习你的3Bet决策。附带教练点评。": "Practice your 3Bet decisions facing early position raises. Coach comments included.",
    "输入新昵称": "Enter new name",
    "保存": "Save",
    "取消": "Cancel",
    "支持开发者": "Support the developer",
    "处理中…": "Processing...",
    "今日免费领取次数已达上限": "Daily free claim limit reached",
    "感谢支持！": "Thank you for your support!",
    "免费领取 %lld 体力值 (今日剩余 %lld 次)": "Claim %lld Free Stamina (%lld times left today)",
    "下一局": "Next Hand"
}

for key, en_text in missing.items():
    if key in data["strings"] and data["strings"][key] == {}:
        data["strings"][key] = {
            "extractionState": "manual",
            "localizations": {
                "en": {
                    "stringUnit": {
                        "state": "translated",
                        "value": en_text
                    }
                }
            }
        }

with open('/Users/zhengliu/.openclaw/workspace/texaspoker/TexasPoker/Sources/Resources/Localizable.xcstrings', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
