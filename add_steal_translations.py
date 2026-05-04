import json

with open("Sources/Resources/Localizable.xcstrings", "r", encoding="utf-8") as f:
    data = json.load(f)

new_strings = {
    "标准的价值加注。你在偷盲位拿到强牌，加注理所应当。": "Standard value raise. Raising a strong hand from a steal position is the right move.",
    "很好的偷盲加注！在偷盲位置，用宽范围施压是极佳的策略。": "Great steal raise! Applying pressure with a wide range from a steal position is an excellent strategy.",
    "位置越靠后，可操作手牌越宽。用这手牌偷盲非常标准。": "The later your position, the wider your playable range. A steal with this hand is very standard.",
    "平跟等于把主动权拱手让给大盲，极易被大盲玩家反打。": "Limping hands over the initiative to the big blind, making you highly exploitable to a counter-attack.",
    "你放弃了偷盲的机会！你应该用这手牌加注向盲注施压。": "You missed a steal opportunity! You should have raised with this hand to pressure the blinds.",
    "你损失了盲注的死钱价值。德扑中很大一部分利润来自于偷盲和施压。": "You lost out on the dead money in the blinds. A large portion of poker profits comes from stealing and pressuring.",
    "过于保守！在偷盲位应该放宽同花连张或小对子的入池范围。": "Too conservative! You should widen your range with suited connectors or small pairs in a steal position.",
    "即便在偷盲位，也没有必要强行用垃圾牌入池。明智的选择。": "Even in a steal position, there is no need to force play with a trash hand. A wise choice."
}

for k, v in new_strings.items():
    data["strings"][k] = {
        "extractionState": "manual",
        "localizations": {
            "en": {
                "stringUnit": {
                    "state": "translated",
                    "value": v
                }
            }
        }
    }

with open("Sources/Resources/Localizable.xcstrings", "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
