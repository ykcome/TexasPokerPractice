import json
import re

swift_file = "Sources/GameLogic/GameManager.swift"
loc_file = "Sources/Resources/Localizable.xcstrings"

with open(swift_file, "r", encoding="utf-8") as f:
    content = f.read()

# Extract all String(localized: "...")
matches = re.findall(r'String\(localized:\s*"([^"]+)"\)', content)
unique_strings = sorted(list(set(matches)))

with open(loc_file, "r", encoding="utf-8") as f:
    xc = json.load(f)

translations = {
    "漂亮的 3Bet！你拿到了优质手牌，进行 3Bet 获取价值并夺取主动权是非常正确的决定。": "Nice 3Bet! You have a premium hand, and 3Betting for value and initiative is the absolute right play.",
    "面对前位加注，拿到强牌果断 3Bet 是正确的，不要给对手看便宜翻牌的机会。": "When facing an early position raise, 3Betting a strong hand is correct. Don't give your opponents a cheap flop.",
    "很好的 3Bet 尺度！你利用优质手牌建立了足够的底池并隔离了对手。": "Good 3Bet sizing! You built a solid pot with a premium hand and isolated your opponent.",
    "你的 3Bet 过于激进。手牌不够强时，面对前位加注进行 3Bet 容易陷入被动或损失筹码。": "Your 3Bet is too aggressive. 3Betting an early position raise with a weak hand easily leads to tough spots and chip loss.",
    "翻前面对 4-bet 弃牌过频，或者用边缘牌 3-bet 都是负 EV 行为，请收紧你的范围。": "Folding too often to 4-bets, or 3-betting marginal hands, are both -EV. Tighten your range.",
    "新手期不要盲目模仿顶尖高手的漂移或诈唬打法，用边缘牌 3-bet 容易失控。": "As a beginner, don't blindly copy high-stakes bluffs. 3-betting marginal hands easily spirals out of control.",
    "手牌很强，只选择跟注过于被动了。这里应该 3Bet 来压榨价值并夺取主动权。": "Your hand is very strong; just calling is too passive. You should 3Bet to extract value and seize the initiative.",
    "拿到强牌时翻前仅平跟，未能通过 3-bet 隔离成单挑底池，会导致多人池胜率下降。": "Flat calling with a strong hand fails to isolate via a 3-bet, reducing your equity in a multi-way pot.",
    "拿到 KK/AA 过于保守，实际上翻前你应该更激进地进行加注或反加。": "Playing KK/AA too passively. You should be much more aggressive preflop with raises and 3-bets.",
    "跟注是可以接受的。手牌有一定可玩性，但不值得 3Bet 冒险。": "Calling is acceptable. The hand has playability but isn't worth the risk of a 3Bet.",
    "同花大牌在有利位置可以跟注或 3-bet，但要注意控制翻后的底池大小。": "Suited broadways in position can call or 3-bet, but be careful with pot control postflop.",
    "拿到中等对子跟注寻求暗三条是可以的，但要注意筹码深度是否提供足够的隐含赔率。": "Set-mining with a medium pair is fine, but ensure the stack depth offers sufficient implied odds.",
    "手牌偏弱，这里跟注前位加注会让你在翻后面临困难，建议弃牌。": "Your hand is too weak. Calling an early position raise here will put you in a tough spot post-flop. Recommend folding.",
    "前位入池标准太低，应只玩顶级手牌避免后续位置带来的决策压力。": "Your early position entering standard is too loose. Only play premium hands to avoid pressure from late positions.",
    "翻前入池范围太宽，建议新手先采用 ABC 打法，专注 99-AA 及 AK/AQ/AJ。": "Your preflop VPIP is too wide. Beginners should stick to ABC poker, focusing on 99-AA and AK/AQ/AJ.",
    "太紧了！你放弃了一手优质牌，这里绝对应该 3Bet。": "Too tight! You folded a premium hand; this is an absolute mandatory 3Bet spot.",
    "面对加注弃牌过频，未能利用你的强牌范围捍卫底池。": "You fold too frequently to raises, failing to defend the pot with your strong range.",
    "打法过于保守，放弃了巨大的价值获取机会，这在长期是不可持续的。": "Too conservative. Giving up massive value opportunities is unsustainable in the long run.",
    "好弃牌！面对前位加注，边缘牌和垃圾牌果断弃掉是赢家的素养。": "Good fold! Decisively folding marginal and trash hands against early position raises is a winning trait.",
    "正确的弃牌，避免了在不利位置用弱牌对抗紧凶玩家的加注。": "Correct fold, avoiding playing a weak hand out of position against a tight-aggressive raiser.",
    "保持耐心是德扑的核心，过滤掉弱牌是迈向盈利的第一步。": "Patience is core to poker. Filtering out weak hands is the first step towards profitability.",
    "漂亮的 Push！在 %lldBB 的深度，拿到有胜率的手牌全押施压是正确的。": "Beautiful Push! Shoving a hand with equity at a %lldBB depth is the correct play.",
    "在短码阶段拿到可玩性手牌果断全押，可以最大化弃牌率（Fold Equity）。": "Decisively shoving playable hands in the short stack phase maximizes your Fold Equity.",
    "非常坚决的 Push。处于短码时，避免被动跟注，主动出击是最好的防守。": "Very resolute Push. When short-stacked, avoid passive calls; attacking is the best defense.",
    "这个全押有点松。虽然筹码不多，但这手牌赢率太低，建议等待更好的时机。": "This shove is a bit loose. Even with a short stack, this hand has too little equity. Wait for a better spot.",
    "缺乏位置意识，在不利位置用垃圾牌盲目全下，被跟注的风险极高。": "Lacking positional awareness. Blindly shoving trash hands out of position carries a huge risk of being called.",
    "全下尺度计算虽然简单，但要结合起手牌质量，这手牌不值得拼命。": "Shove sizing is simple, but you must consider hand quality. This hand isn't worth risking your tournament life.",
    "在短码阶段，只跟注是不好的策略。你应该全押(Push)或者弃牌(Fold)来最大化你的弃牌率。": "In the short stack phase, calling is a poor strategy. You should Push or Fold to maximize fold equity.",
    "筹码深度不够时仍盲目跟注，不仅没有弃牌率，翻后也很难操作。": "Blindly calling without sufficient stack depth offers zero fold equity and makes postflop play difficult.",
    "短码时不要用跟注消耗自己所剩无几的筹码，请采用 Push/Fold 策略。": "Don't bleed your remaining chips by calling when short-stacked. Stick to a Push/Fold strategy.",
    "太保守了！在 %lldBB 的深度，这手牌绝对值得全押一搏。": "Too conservative! At %lldBB depth, this hand is absolutely worth a shove.",
    "这手牌即使被跟注也有很好的胜率，此时弃牌属于负 EV 行为。": "This hand has great equity even when called. Folding here is a -EV play.",
    "拿到优质手牌过于保守，没有把握住筹码翻倍的绝佳机会。": "Too conservative with a premium hand. You missed a perfect opportunity to double up.",
    "好弃牌。保留短码等待更好的起手牌。": "Good fold. Preserve your short stack and wait for a better starting hand.",
    "面对不利局势果断弃牌，在短码阶段每一分筹码都很宝贵。": "Decisive fold in an unfavorable spot. Every chip is precious when short-stacked.",
    "理智的弃牌。牌力太弱时不要被短码焦虑冲昏头脑强行全下。": "Rational fold. Don't let short-stack anxiety push you to shove a weak hand.",
    "标准的价值加注。你在后位拿到强牌，加注理所应当。": "Standard value raise. Raising a strong hand from late position is the right move.",
    "非常棒的施压！用大牌偷盲，被跟注后在翻后也有极大优势。": "Excellent pressure! Stealing with a big hand gives you a massive postflop advantage if called.",
    "优质牌加注，这才是德扑盈利的根本，保持这样的打法。": "Raising premium hands is the foundation of winning poker. Keep it up.",
    "很好的偷盲加注！在庄家或小盲位，用宽范围施压是极佳的策略。": "Great steal raise! Applying pressure with a wide range from the button or small blind is an excellent strategy.",
    "位置越靠后，可操作手牌越宽。按钮位用这手牌偷盲非常标准。": "The later your position, the wider your playable range. A button steal with this hand is very standard.",
    "正确的隔离策略。利用位置优势，迫使盲注玩家放弃他们的底池权益。": "Correct isolation strategy. Using positional advantage to force the blinds to forfeit their equity.",
    "你的偷盲范围太宽了。用毫无联系的垃圾牌加注很容易被反击。": "Your steal range is too wide. Raising with uncoordinated trash hands easily invites counter-attacks.",
    "位置优势不能掩盖手牌过弱的事实，遇到大盲位 3-bet 你将毫无还手之力。": "Positional advantage doesn't cover for a weak hand. You'll be defenseless against a BB 3-bet.",
    "用垃圾牌偷盲一旦被跟注，翻后处于不利位置的决策将极为困难。": "Stealing with trash hands leads to extremely difficult postflop decisions out of position if called.",
    "手牌这么强，你应该加注建立底池。": "With such a strong hand, you should raise to build the pot.",
    "拿到 AA/KK 时翻前仅平跟，未能通过 3-bet 隔离，多人池胜率会大幅下降。": "Flat calling AA/KK preflop fails to isolate. Multi-way pot equity drops significantly.",
    "盲注位跟注过于被动，你放弃了翻前夺取主动权并赢下盲注的最好机会。": "Calling from the blinds is too passive. You gave up the best chance to seize initiative and win the blinds preflop.",
    "跛入（Limp）不是好习惯。如果要打这手牌，你应该加注来偷盲。": "Limping is a bad habit. If you want to play this hand, you should raise to steal.",
    "小对子或同花连张如果在有利位置，要么加注偷盲，要么弃牌，平跟是下策。": "Small pairs or suited connectors in position should either raise to steal or fold. Limping is suboptimal.",
    "在按钮位平跟等于把主动权拱手让给大盲，极易被利用位置反打。": "Flat calling on the button surrenders initiative to the big blind, easily inviting a squeeze play.",
    "你放弃了偷盲的机会！在后位，你应该用这手牌加注向盲注施压。": "You passed up a steal opportunity! From late position, you should raise to pressure the blinds.",
    "按钮位过于保守！未利用位置优势放宽同花连张或小对子。": "Too conservative on the button! You didn't leverage position to widen your range for suited connectors or small pairs.",
    "你损失了盲注的死钱价值。德扑中 70% 的利润来自于后位的偷盲和施压。": "You lost dead money value from the blinds. 70% of poker profits come from late-position steals and pressure.",
    "正确的弃牌。牌太差不值得偷盲。": "Correct fold. The hand is too weak to attempt a steal.",
    "即便在庄家位，也没有必要强行用垃圾牌入池。明智的选择。": "Even on the button, there's no need to force a trash hand. Wise choice.",
    "很好的纪律性。不强行偷盲，避免了被紧凶玩家剥削。": "Great discipline. Not forcing a steal prevents you from being exploited by tight-aggressive players.",
    "非常棒的 3Bet！面对偷盲，用强牌反击获取价值。": "Awesome 3Bet! Counter-attacking a steal with a strong hand for value.",
    "完美！拿到顶级手牌不仅要防守，更要 3Bet 扩大底池让对手付出代价。": "Perfect! With a premium hand, don't just defend—3Bet to bloat the pot and make your opponent pay.",
    "很好的防守反击。让偷盲者陷入困境，这才是盲注防守的核心。": "Great defensive counter-attack. Putting stealers in tough spots is the core of blind defense.",
    "不错的 3Bet 诈唬。面对频繁偷盲的对手，用这手牌反击可以赢下底池。": "Nice 3Bet bluff. Against a frequent stealer, counter-attacking with this hand can win the pot outright.",
    "利用阻断牌（如含A/K的牌）在大盲位进行 3-bet，能给宽范围偷盲者极大的弃牌压力。": "Using blockers (like A/K) to 3-bet from the BB applies immense fold equity against wide stealers.",
    "这种半诈唬加注很好。就算被跟注，翻后你依然有不错的操作空间和胜率。": "This semi-bluff raise is great. Even if called, you still have good playability and equity postflop.",
    "你的反击太激进了。用垃圾牌 3Bet 风险过大。": "Your counter-attack is too aggressive. 3Betting with trash carries excessive risk.",
    "大盲位拿到弱牌盲目反加是资金粉碎机。防守要有度，不要变成情绪化玩家。": "Blindly re-raising weak hands from the BB is a chip shredder. Defend reasonably; don't play emotionally.",
    "缺乏逻辑支撑的 3-bet，对手如果 4-bet 你只能弃牌，白白损失大量筹码。": "An illogical 3-bet. If the opponent 4-bets, you must fold, wasting a ton of chips for nothing.",
    "这手牌你应该 3Bet 获取价值，而不是只跟注。": "You should 3Bet this hand for value instead of just calling.",
    "用 AA/KK 在大盲位只跟注，给了按钮位玩家太好的隐含赔率去击中两对或三条。": "Flatting AA/KK from the BB gives the button incredible implied odds to hit two pair or a set.",
    "盲注位防守强牌过于被动。慢打强牌时机不对，翻后在不利位置会很难受。": "Defending strong hands from the blinds too passively. Slow-playing here is ill-timed and tough to play postflop OOP.",
    "标准的防守跟注。你在大盲位有很好的赔率，看看翻牌是可以的。": "Standard defense call. You have great odds from the BB; seeing a flop is fine.",
    "大盲位有防守折扣，用同花连张或中等牌力跟注看翻牌是正 EV 的打法。": "The BB gets a discount. Calling with suited connectors or medium strength hands is a +EV play.",
    "理智的跟注防守。但要注意，翻后如果没有击中强牌，不要盲目纠缠。": "Rational call defense. Just remember: if you miss the flop, don't blindly stick around.",
    "这手牌太差了，即使有底池赔率也不建议跟注。": "This hand is too poor. Even with pot odds, calling isn't recommended.",
    "拿到小牌且非同色，即便赔率再好也不应跟注。防守范围太宽容易导致翻后破产。": "Offsuit small cards shouldn't be called despite good odds. Defending too wide leads to postflop disaster.",
    "位置劣势下拿到垃圾牌，过牌或轻易跟注属于典型的“跟注站”行为。": "Playing trash hands out of position by checking or calling is typical 'calling station' behavior.",
    "重大失误！你放弃了一手顶级牌。": "Major mistake! You folded a premium hand.",
    "面对松凶玩家的偷盲加注弃掉了坚果牌，这是对筹码的严重浪费！": "Folding a monster hand to a loose-aggressive stealer is a severe waste of chips!",
    "大盲位面对加注弃牌过多，完全没有捍卫你的强牌范围。": "You fold too much from the BB to raises, failing completely to defend your strong range.",
    "你防守得太紧了。大盲位有很好的赔率，这手牌值得跟注或 3Bet。": "Defending too tightly. The BB offers great odds; this hand warrants a call or a 3Bet.",
    "大盲位防守范围太窄，面对 CO 或按钮位加注弃牌过多，损失了防守价值。": "BB defense range is too narrow. Folding too often to CO or Button raises bleeds defensive value.",
    "在极佳的底池赔率下弃掉了一手有潜力的好牌，太可惜了。": "It's a pity to fold a hand with such good potential given the excellent pot odds.",
    "正确的弃牌。面对加注，果断放弃垃圾牌。": "Correct fold. Decisively fold trash hands when facing a raise.",
    "即使在大盲位，不抵抗也是一种防守策略，保留筹码去打更优质的手牌。": "Even in the BB, folding is a valid defense. Save your chips for better hands.",
    "很好，没有因为舍不得已经投入的大盲注而陷入“沉没成本”陷阱。": "Good job avoiding the 'sunk cost' fallacy over your posted big blind."
}

count = 0

for k, v in translations.items():
    if k in xc["strings"]:
        if "en" in xc["strings"][k]["localizations"]:
            if xc["strings"][k]["localizations"]["en"]["stringUnit"]["value"] == k or xc["strings"][k]["localizations"]["en"]["stringUnit"]["value"] == "":
                xc["strings"][k]["localizations"]["en"]["stringUnit"]["value"] = v
                count += 1
        else:
            xc["strings"][k]["localizations"]["en"] = {
                "stringUnit": {
                    "state": "translated",
                    "value": v
                }
            }
            count += 1
    else:
        # Check if parameter format exists in unique_strings
        matched_key = None
        for us in unique_strings:
            # simple parameter replacement check
            replaced_us = us.replace("%lld", ".*")
            if re.match(f"^{replaced_us}$", k):
                matched_key = us
                break
        
        key_to_use = matched_key if matched_key else k
        
        if key_to_use not in xc["strings"]:
            xc["strings"][key_to_use] = {
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
            count += 1
        else:
            if "en" in xc["strings"][key_to_use]["localizations"]:
                xc["strings"][key_to_use]["localizations"]["en"]["stringUnit"]["value"] = v
            else:
                xc["strings"][key_to_use]["localizations"]["en"] = {
                    "stringUnit": {
                        "state": "translated",
                        "value": v
                    }
                }
            count += 1

with open(loc_file, "w", encoding="utf-8") as f:
    json.dump(xc, f, indent=2, ensure_ascii=False)

print(f"Added {count} translations.")