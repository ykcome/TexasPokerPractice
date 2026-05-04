import Foundation

final class AIAgent {

    static let shared = AIAgent()

    private let evaluator = HandEvaluator.shared
    private let stateLock = NSLock()
    private var states: [UUID: AIState] = [:]

    private init() {}

    private struct AIState {
        var tilt: Double
        var randomBaselineAggressionOffset: Double
    }
    
    private struct OpponentStats {
        var handsPlayed: Int = 0
        var allInPreflopCount: Int = 0
        var vpipCount: Int = 0
        var consecutiveAllInCount: Int = 0 // 记录连续全押的次数
        var consecutiveBigRaiseCount: Int = 0 // 记录连续大于 5BB 加注的次数
        var recentPreflopFolds: [Bool] = [] // 记录最近的翻前弃牌情况
        
        var isTightFish: Bool {
            return recentPreflopFolds.count == 5 && recentPreflopFolds.filter { $0 }.count >= 3
        }
        
        var isManiac: Bool {
            return consecutiveBigRaiseCount >= 3 || consecutiveAllInCount >= 2
        }
    }
    
    private var opponentStats: [UUID: OpponentStats] = [:]
    
    // 每一局 SNG 策略模拟器 随机确定的诈唬 5 秒区间起始值 (0~54)
    private var randomBluffStartSecond: Int = Int.random(in: 0...54)
    
    func resetForNewTournament() {
        stateLock.lock()
        states.removeAll()
        opponentStats.removeAll()
        randomBluffStartSecond = Int.random(in: 0...54)
        stateLock.unlock()
    }

    func recordHandResult(players: [Player], payouts: [UUID: Int], bbAmount: Int, gameState: GameState? = nil) {
        guard bbAmount > 0 else { return }

        // --- 更新跨局对手统计 ---
        if let state = gameState {
            for player in state.players {
                var stats = opponentStats[player.id] ?? OpponentStats()
                stats.handsPlayed += 1
                
                let preflopActions = state.actionHistory.filter { $0.playerId == player.id && $0.phase == .preflop }
                
                let isHugeAction = preflopActions.contains(where: { 
                    switch $0.action {
                    case .allIn: return true
                    case .raise(let amt), .bet(let amt): return amt >= 20 * bbAmount
                    default: return false
                    }
                })
                
                let isBigRaise = preflopActions.contains(where: { 
                    switch $0.action {
                    case .raise(let amt), .bet(let amt): return amt >= 5 * bbAmount
                    default: return false
                    }
                })
                
                if isHugeAction {
                    stats.allInPreflopCount += 1
                    stats.vpipCount += 1
                    stats.consecutiveAllInCount += 1 // 翻前全押或超大投入，连续次数 +1
                    stats.consecutiveBigRaiseCount += 1
                } else if isBigRaise {
                    stats.vpipCount += 1
                    stats.consecutiveBigRaiseCount += 1 // 连续大于5BB加注
                    stats.consecutiveAllInCount = 0
                } else if preflopActions.contains(where: { 
                    if case .call = $0.action { return true }
                    if case .raise = $0.action { return true }
                    if case .bet = $0.action { return true }
                    return false
                }) {
                    stats.vpipCount += 1
                    stats.consecutiveAllInCount = 0 // 有动作但不是全押，中断连续
                    stats.consecutiveBigRaiseCount = 0 // 不是大于5BB的投入，中断连续
                } else if preflopActions.contains(where: { if case .fold = $0.action { return true }; return false }) {
                    stats.consecutiveAllInCount = 0 // 弃牌也中断连续
                    stats.consecutiveBigRaiseCount = 0
                }
                
                // 记录人类玩家的翻前弃牌情况
                if player.isHuman {
                    let didFoldPreflop = preflopActions.contains(where: { if case .fold = $0.action { return true }; return false })
                    stats.recentPreflopFolds.append(didFoldPreflop)
                    if stats.recentPreflopFolds.count > 5 {
                        stats.recentPreflopFolds.removeFirst()
                    }
                }
                
                opponentStats[player.id] = stats
            }
        }

        for player in players where !player.isHuman {
            let payout = payouts[player.id] ?? 0
            let net = payout - player.totalInvested
            let netBB = Double(net) / Double(bbAmount)

            stateLock.lock()
            var state = states[player.id] ?? AIState(tilt: 0, randomBaselineAggressionOffset: Double.random(in: -0.15...0.15))

            // 每局结束时，有小概率重新给这个 AI 生成一个新的随机打法底色（避免一成不变）
            if Double.random(in: 0..<1) < 0.15 {
                state.randomBaselineAggressionOffset = Double.random(in: -0.15...0.15)
            }

            state.tilt *= 0.65
            if netBB <= -15 {
                let bump: Double
                switch player.aiDifficulty {
                case .easy: bump = 0.10
                case .medium: bump = 0.18
                case .hard: bump = 0.16
                case .loose: bump = 0.35
                }
                state.tilt = min(1.0, state.tilt + bump)
            } else if netBB <= -6 {
                let bump: Double
                switch player.aiDifficulty {
                case .easy: bump = 0.06
                case .medium: bump = 0.10
                case .hard: bump = 0.08
                case .loose: bump = 0.18
                }
                state.tilt = min(1.0, state.tilt + bump)
            } else if netBB > 0 {
                state.tilt *= 0.85
            }

            states[player.id] = state
            stateLock.unlock()
        }
    }

    // MARK: - Decision Making

    func decideAction(
        for player: Player,
        gameState: GameState,
        evaluator: HandEvaluator
    ) -> PlayerAction {
        guard let holeCards = player.holeCards else { return .fold }

        let deadline = CFAbsoluteTimeGetCurrent() + 18.0

        let highestBet = gameState.players.map { $0.currentBet }.max() ?? 0
        let validActions = BettingManager.shared.getValidActions(
            for: player,
            highestBet: highestBet,
            lastRaiseAmount: gameState.lastRaiseAmount,
            phase: gameState.phase,
            minBet: gameState.bbAmount,
            sbAmount: gameState.sbAmount,
            bbAmount: gameState.bbAmount,
            isFirstBettor: highestBet == 0  // First bettor = no one has bet yet
        )

        let bb = max(1, gameState.bbAmount)
        let stackBB = Double(player.chips) / Double(bb)
        let activeCount = gameState.players.filter { $0.isActive && !$0.isFolded }.count

        stateLock.lock()
        let state = states[player.id] ?? AIState(tilt: 0, randomBaselineAggressionOffset: Double.random(in: -0.15...0.15))
        let tilt = state.tilt
        let randomOffset = state.randomBaselineAggressionOffset
        stateLock.unlock()

        let maxSimulations: Int
        let base: Int
        switch player.aiDifficulty {
        case .easy: base = 30
        case .medium: base = 45
        case .hard: base = 65
        case .loose: base = 75
        }

        if gameState.communityCards.isEmpty {
            var sims = base + 15
            if Double.random(in: 0..<1) < 0.12 {
                sims = 100
            }
            maxSimulations = min(100, max(25, sims))
        } else {
            var sims = base + (gameState.communityCards.count == 3 ? 10 : 0)
            if Double.random(in: 0..<1) < 0.18 {
                sims = 100
            }
            maxSimulations = min(100, max(20, sims))
        }

        let rawEquity: Double
        if gameState.communityCards.isEmpty {
            rawEquity = calculatePreflopStrength(holeCards: holeCards, gameState: gameState)
        } else {
            rawEquity = calculateHandStrength(
                heroPlayerId: player.id,
                holeCards: holeCards,
                communityCards: gameState.communityCards,
                players: gameState.players,
                evaluator: evaluator,
                maxSimulations: maxSimulations,
                deadline: deadline,
                gameState: gameState
            )
        }

        let adjustedStrength = adjustEquityWithEQRAndAdvantages(
            heroPlayerId: player.id,
            equity: rawEquity,
            holeCards: holeCards,
            communityCards: gameState.communityCards,
            gameState: gameState
        )

        let handStrength = adjustedStrength

        if highestBet > 0, validActions.canCall, validActions.callAmount > 0, validActions.canFold {
            let amountToCallBB = Double(validActions.callAmount) / Double(bb)
            let callIsBig = amountToCallBB >= 6 || Double(validActions.callAmount) >= Double(player.chips) * 0.35
            if callIsBig {
                // --- [新增] SNG 策略模拟器第一局人类 All-in 必接逻辑 ---
                let humanPlayersForFirstHand = gameState.players.filter { $0.isHuman }
                if let human = humanPlayersForFirstHand.first {
                    // 第一局识别：直接检查是否所有 6 名玩家都在，且每个人的总积分（当前积分 + 本局已投入）都是初始的 1000
                    let isFirstHand = gameState.players.count == 6 && gameState.players.allSatisfy { ($0.chips + $0.totalInvested) == 1000 }
                    let humanWentAllIn = human.isAllIn || human.currentBet >= 40 * bb || gameState.actionHistory.contains(where: {
                        if $0.playerId != human.id { return false }
                        if case .allIn = $0.action { return true }
                        return false
                    })
                    
                    if isFirstHand && humanWentAllIn {
                        let activeAIs = gameState.players.filter { !$0.isHuman && !$0.isFolded && $0.isActive }
                        var aiStrengths: [(UUID, Double)] = []
                        for ai in activeAIs {
                            if let hc = ai.holeCards {
                                let str = calculatePreflopStrength(holeCards: hc, gameState: gameState)
                                aiStrengths.append((ai.id, str))
                            }
                        }
                        aiStrengths.sort { $0.1 > $1.1 }
                        
                        let minMandatoryCallStrength = amountToCallBB > 40 ? 0.80 : 0.68
                        if let bestAI = aiStrengths.first, bestAI.1 >= minMandatoryCallStrength {
                            if player.id == bestAI.0 {
                                return validActions.canCall ? .call(amount: validActions.callAmount) : .allIn(amount: validActions.allInAmount)
                            } else {
                                let investedRatio = Double(player.totalInvested) / Double(player.totalInvested + player.chips)
                                if validActions.canFold && investedRatio < 0.50 {
                                    return .fold
                                }
                            }
                        }
                    }
                }
                
                var threshold = allInEquityThreshold(difficulty: player.aiDifficulty, activeCount: activeCount, tilt: tilt)
                var requiredEquity = Double(validActions.callAmount) / Double(gameState.pot + validActions.callAmount)

                let humanPlayers = gameState.players.filter { $0.isHuman }
                if let human = humanPlayers.first {
                    let aggScore = opponentAggressionScore(for: human.id, gameState: gameState)
                    if aggScore > 0.6 {
                        // 防止 AI 被过度剥削：当人类极其激进，喜欢无脑推 All-in 时
                        // 我们稍微放宽接推的门槛，但也必须保证只用价值牌去接（比如 AJ+, 88+）
                        let adjustment = min(0.12, 0.18 * aggScore) 
                        threshold -= adjustment
                        requiredEquity = max(0.0, requiredEquity - 0.08 * aggScore)
                        if gameState.pot > player.chips {
                            threshold -= 0.05
                        }
                    }
                }

                threshold = min(threshold, requiredEquity + 0.10)
                
                // --- SNG 策略模拟器深积分接推门槛增强 ---
                // 如果这是早期的超深积分全押（例如超过 40BB），接推的门槛必须极高，绝不能只用 requiredEquity + 0.10 作为上限
                // 因为 22 的胜率有 0.70，会导致 AI 用小口袋对接 100BB 的全押！
                if amountToCallBB > 40 && gameState.bbAmount <= 50 {
                    // 深积分接推保护
                    var deepStackThreshold = 0.80
                    
                    if let human = humanPlayers.first {
                        let aggScore = opponentAggressionScore(for: human.id, gameState: gameState)
                        
                        if let stats = opponentStats[human.id], stats.isManiac {
                            // 如果人类连续 2 次 All-in 或 连续 3 次大于 5BB 的投入，被标记为疯鱼，彻底放弃深筹保护，用前 60% 的牌（牌力 > 0.40）直接接推制裁
                            deepStackThreshold = 0.40
                        } else if aggScore > 0.6 {
                            // 如果是疯推的人类，适当放宽深积分接推门槛（用 TT+, AQ+ 去接他）
                            deepStackThreshold -= min(0.08, 0.12 * aggScore)
                            
                            // 1v1 单挑时，人类如果是疯推，大幅度放宽深筹接推底线，避免被无脑剥削
                            if activeCount == 2 {
                                deepStackThreshold -= 0.15 
                            }
                        }
                    }
                    
                    threshold = max(threshold, deepStackThreshold)
                } else {
                    if let human = humanPlayers.first {
                        if let stats = opponentStats[human.id], stats.isManiac {
                            // 如果不是深筹且是疯鱼，也同样用前 60% 的牌强接
                            threshold = min(threshold, 0.40)
                        } else {
                            threshold = max(requiredEquity, threshold)
                        }
                    } else {
                        threshold = max(requiredEquity, threshold)
                    }
                }

                // AI 自身牌力如果是翻前，也必须做修正（防止小口袋对虚高评分通过阈值）
                var finalHandStrength = handStrength
                if gameState.phase == .preflop && amountToCallBB > 40 && gameState.bbAmount <= 50 {
                    // 如果手牌是小/中口袋对（22-88），它们的实际对抗 All-in 范围非常差
                    let ranks = holeCards.map { $0.numericValue }.sorted(by: >)
                    if ranks[0] == ranks[1] && ranks[0] <= 8 {
                        // 1v1 对抗极度激进的玩家时，不惩罚口袋对，鼓励用它们抓鸡
                        let isHeadsUpVsManiac = (activeCount == 2) && (opponentAggressionScore(for: humanPlayers.first?.id ?? UUID(), gameState: gameState) > 0.6)
                        
                        if let humanId = humanPlayers.first?.id, let stats = opponentStats[humanId] {
                            if !isHeadsUpVsManiac && !stats.isManiac {
                                finalHandStrength -= 0.15 // 强行降低小口袋对在面对深积分 All-in 时的牌力评分，避免接推
                            }
                        } else {
                            if !isHeadsUpVsManiac {
                                finalHandStrength -= 0.15
                            }
                        }
                    }
                }
                
                // 在SNG 策略模拟器后期（2-3人），面临对手突然超池全下（诈唬可能极高）
                if activeCount <= 3 && amountToCallBB > 20 {
                    let investedRatio = Double(player.totalInvested) / Double(player.totalInvested + player.chips)
                    // 如果 AI 已经投入较多（比如 > 25%积分），且牌力大于 0.65，强行增加牌力，防被推死
                    if investedRatio > 0.25 && finalHandStrength > 0.65 {
                        finalHandStrength += 0.15
                    }
                }

                if finalHandStrength < threshold {
                    // 修正：在直接判定 Fold 之前检查套池比例（已投入 >= 50% 积分，SNG 策略模拟器后期放宽到 35%）
                    let investedRatio = Double(player.totalInvested) / Double(player.totalInvested + player.chips)
                    let commitThreshold = activeCount <= 3 ? 0.35 : 0.50
                    if investedRatio >= commitThreshold {
                        return validActions.canCall ? .call(amount: validActions.callAmount) : .allIn(amount: validActions.allInAmount)
                    }
                    return .fold
                }
            }
        }

        if gameState.phase == .preflop {
            // --- [修改] 全局统筹：每一局中，安排牌力最强的 1-2 个 AI 玩家与人类对抗 ---
            if let human = gameState.players.first(where: { $0.isHuman }) {
                let allAIsInHand = gameState.players.filter { !$0.isHuman && ($0.chips + $0.totalInvested) > 0 }
                if allAIsInHand.count > 2 {
                    var aiStrengths: [(UUID, Double)] = []
                    for ai in allAIsInHand {
                        if let holeCards = ai.holeCards {
                            let str = calculatePreflopStrength(holeCards: holeCards, gameState: gameState)
                            aiStrengths.append((ai.id, str))
                        }
                    }
                    aiStrengths.sort { $0.1 > $1.1 }
                    
                    // 用所有玩家的总积分之和生成一个同一手牌内稳定的伪随机数，决定这把选 1 个还是 2 个最强 AI
                    let totalChipsInPlay = gameState.players.map { $0.chips + $0.totalInvested }.reduce(0, +)
                    let topCount = (totalChipsInPlay % 2 == 0) ? 2 : 1
                    let topAIs = aiStrengths.prefix(topCount).map { $0.0 }
                    
                    if !topAIs.contains(player.id) {
                        // 不是天选之子，直接弃牌给队友让路（除非已经套池）
                        let investedRatio = Double(player.totalInvested) / Double(player.totalInvested + player.chips)
                        if validActions.canFold && investedRatio < 0.50 {
                            return .fold
                        }
                    } else {
                        // 我是全桌牌最好的 1-2 个 AI 之一
                        // 如果我的牌力 < 0.30，依然选择弃牌，保证牌太烂时不强行送死
                        if handStrength < 0.30 {
                            let investedRatio = Double(player.totalInvested) / Double(player.totalInvested + player.chips)
                            if validActions.canFold && investedRatio < 0.50 {
                                return .fold
                            }
                        } else {
                            // 我的牌力 >= 0.30，且我是全桌最强的！必须站出来跟注或加注！
                            if validActions.callAmount == 0 && validActions.canCheck {
                                if validActions.canRaise && Double.random(in: 0...1) < 0.5 {
                                    let raiseAmount = min(validActions.minRaise + bb * Int.random(in: 0...2), validActions.allInAmount)
                                    return .raise(amount: raiseAmount)
                                } else {
                                    return .check
                                }
                            } else if validActions.canRaise && Double.random(in: 0...1) < 0.4 {
                                let raiseAmount = min(validActions.minRaise + bb * Int.random(in: 0...3), validActions.allInAmount)
                                return .raise(amount: raiseAmount)
                            } else if validActions.canCall {
                                return .call(amount: validActions.callAmount)
                            } else if validActions.canAllIn {
                                return .allIn(amount: validActions.allInAmount)
                            }
                        }
                    }
                }
            }
            
            // --- [新增] 底分位防守与反抢（Re-steal）机制 ---
            // 如果 AI 在大底分或小底分，面临人类玩家在晚位（Button 或 CO）的单次加注（偷盲），AI 应该扩大 3Bet 范围反击
            let currentRaiseDepth = preflopRaiseDepth(players: gameState.players, bbAmount: bb)
            if (player.position == .bb || player.position == .sb) && currentRaiseDepth == 1 && highestBet <= bb * 4 {
                if let human = gameState.players.first(where: { $0.isHuman }), !human.isFolded, human.currentBet == highestBet {
                    if human.position == .button || human.position == .co || human.position == .sb {
                        let aggScore = opponentAggressionScore(for: human.id, gameState: gameState)
                        // 如果人类激进且在偷盲，AI 只要手牌 > 0.50（前 50%），就有 30-50% 概率直接 3Bet
                        if handStrength > 0.50 && validActions.canRaise {
                            let prob = min(0.60, 0.20 + 0.30 * aggScore)
                            if Double.random(in: 0..<1) < prob {
                                let raiseAmount = min(validActions.minRaise + bb * Int.random(in: 0...2), validActions.allInAmount)
                                return .raise(amount: raiseAmount)
                            }
                        }
                    }
                }
            }
            if let human = gameState.players.first(where: { $0.isHuman }), !human.isFolded {
                if let stats = opponentStats[human.id], stats.isTightFish {
                    // 如果人类是紧鱼，且目前没有出现大额加注（pot未被疯抬），AI 用前 70% 的手牌（牌力 > 0.30）主动加注剥削
                    if handStrength > 0.30 && validActions.canRaise && highestBet <= bb * 3 {
                        // 统计当前翻前阶段已经有几个 AI 进行了加注或大额投入
                        let aiRaisersCount = Set(gameState.actionHistory.filter { record in
                            if record.phase != .preflop || record.playerId == human.id { return false }
                            switch record.action {
                            case .raise, .allIn, .bet: return true
                            default: return false
                            }
                        }.map { $0.playerId }).count
                        
                        // 保证每手牌只有 1-2 个 AI 去剥削他，避免全桌疯狂加注
                        if aiRaisersCount < 2 {
                            // 给定一定的概率触发（避免每次都在固定位置机械式加注）
                            if Double.random(in: 0...1) < 0.6 {
                                let raiseAmount = min(max(validActions.minRaise, bb * 2) + bb * Int.random(in: 0...2), validActions.allInAmount)
                                return .raise(amount: raiseAmount)
                            }
                        }
                    }
                }
            }
            
            let raiseDepth = preflopRaiseDepth(players: gameState.players, bbAmount: bb)
            if raiseDepth >= 2 {
                let pos = positionAggression(position: player.position)
                let isFacing4BetOrMore = raiseDepth >= 3
                
                var aggScore = 0.0
                var isHumanManiac = false
                let humanPlayer = gameState.players.first(where: { $0.isHuman })
                if let human = humanPlayer {
                    aggScore = opponentAggressionScore(for: human.id, gameState: gameState)
                    // 如果人类玩家极其激进（疯鱼），且依然在局内没有弃牌，我们需要降低门槛来制裁他
                    isHumanManiac = aggScore > 0.65 && !human.isFolded
                }
                
                // --- [核心修改] 强制拦截 3Bet/4Bet 乱跟 ---
                // 面对前面的激烈加注大战，如果牌力不属于前 10%-15% (约 0.85，即 TT+, AQs+)，直接弃牌。
                var hardBlockThreshold = 0.85
                
                // SNG 后期单挑/三人时，放宽阻截线
                if activeCount <= 3 {
                    hardBlockThreshold = 0.75
                }
                
                // 如果人类是疯鱼在乱推，AI 需要扮演“警察”的角色。
                // 我们通过座位号或随机性分配，让每局至少有 1-2 个 AI 愿意用稍宽的范围（如任何对子或两张高牌，约 0.65~0.70+）接战
                if isHumanManiac {
                    // 放宽拦截线，允许更多的牌（前 30% 左右）进入后续评估
                    hardBlockThreshold = 0.70
                }
                
                if handStrength < hardBlockThreshold {
                    if validActions.canFold && !validActions.canCheck {
                        // 修正：如果已经严重套池（投入 >= 50% 积分，SNG 策略模拟器后期放宽到 35%），强制不弃牌，改为跟注或全押
                        let investedRatio = Double(player.totalInvested) / Double(player.totalInvested + player.chips)
                        let commitThreshold = activeCount <= 3 ? 0.35 : 0.50
                        if investedRatio >= commitThreshold {
                            return validActions.canCall ? .call(amount: validActions.callAmount) : .allIn(amount: validActions.allInAmount)
                        }
                        return .fold
                    }
                }
                
                // 在 SNG 策略模拟器早期，极其不鼓励翻前频繁的 3Bet/4Bet 全押大战，除非拿着极强牌
                let isEarlyStage = bb <= 50
                let earlyStagePenalty = isEarlyStage ? 0.08 : 0.0

                if isFacing4BetOrMore, validActions.canAllIn {
                    // 如果有人 4Bet/5Bet，那接推/再推的门槛需要极高
                    var threshold = 0.90 // 仅用 Top 10% 的极强牌应对正常 4Bet+
                    
                    // 如果人类是疯鱼，AI 敢于直接 5Bet 或 All-in 反击
                    if isHumanManiac {
                        // 极大降低全押对抗的门槛到 0.75（包含 88+, ATs+, KJs+ 等）
                        threshold = 0.75 
                    }
                    
                    if handStrength >= threshold {
                        let p = min(0.95, 0.40 + 0.20 * pos + 0.20 * tilt + 0.20 * aggScore) // 面对激进人类，通过率也提升
                        if Double.random(in: 0..<1) < p {
                            return .allIn(amount: validActions.allInAmount)
                        }
                    }
                } else {
                    if validActions.canRaise {
                        var threshold = 0.90 // 面对 3Bet 时，仅用 Top 10% 的极强牌进行 4Bet
                        
                        if isHumanManiac {
                            // 敢于对疯鱼进行 4Bet 压制
                            threshold = 0.75
                            // 单挑时，放宽对疯鱼的容忍度，不要用中等牌（如 AT）盲目 4Bet 拼方差，更多选择平跟
                            if activeCount == 2 && stackBB > 20 {
                                threshold = 0.86 // 需要极化范围（如 AK, QQ+）才去 4Bet
                            }
                        }
                        
                        if handStrength >= threshold {
                            let p = min(0.70, 0.20 + 0.15 * pos + 0.10 * tilt + 0.15 * aggScore)
                            // 对抗疯鱼时，AI 加大 4bet/5bet 反打频率
                            let finalProb = isHumanManiac ? min(0.95, p + 0.30) : p
                            
                            if Double.random(in: 0..<1) < finalProb {
                                if validActions.minRaise >= validActions.allInAmount, validActions.canAllIn {
                                    return .allIn(amount: validActions.allInAmount)
                                }
                                return .raise(amount: validActions.minRaise)
                            }
                        }
                    }

                    if validActions.canAllIn, stackBB <= 20 {
                        var threshold = 0.90 // 短积分时，应对深层加注同样保持极高要求
                        if isHumanManiac {
                            threshold = 0.70 // 针对短积分疯鱼推盘，极大放宽接推范围
                        }
                        
                        if handStrength >= threshold {
                            let p = min(0.75, 0.16 + 0.14 * pos + 0.14 * tilt + (20 - stackBB) * 0.02 + 0.15 * aggScore)
                            let finalProb = isHumanManiac ? min(0.95, p + 0.20) : p
                            if Double.random(in: 0..<1) < finalProb {
                                return .allIn(amount: validActions.allInAmount)
                            }
                        }
                    }
                }
                
                // 如果面临 4Bet+，又没有达到推盘门槛，强制拦截普通跟注，交由兜底机制或大概率折叠
                if isFacing4BetOrMore && validActions.canFold && !validActions.canCheck {
                    let allowRandomDefense = handStrength >= (isHumanManiac ? 0.76 : 0.82)
                    if allowRandomDefense {
                        let rand = Double.random(in: 0..<1)
                        let shoveP = isHumanManiac ? 0.12 : 0.06
                        let callP = isHumanManiac ? 0.20 : 0.10
                        if rand < shoveP {
                            if validActions.canAllIn {
                                return .allIn(amount: validActions.allInAmount)
                            } else if validActions.canRaise {
                                return .raise(amount: validActions.minRaise)
                            }
                        } else if rand < (shoveP + callP) {
                            if validActions.canCall {
                                return .call(amount: validActions.callAmount)
                            }
                        }
                    }
                    return .fold
                }
            }
        }

        // --- 短积分（Short Stack）策略增强 (包含 HU Nash 近似) ---
        if stackBB <= 15, validActions.canAllIn, gameState.phase == .preflop {
            if activeCount == 2 {
                // Heads-Up All-in/Fold Nash 近似
                let isSB = player.position == .sb || player.position == .button // HU 中 Button 是小底分
                let isFacingShove = highestBet >= Int(Double(bb) * stackBB * 0.8) || highestBet >= player.chips
                
                var aggScore = 0.0
                if let human = gameState.players.first(where: { $0.isHuman }) {
                    aggScore = opponentAggressionScore(for: human.id, gameState: gameState)
                }
                
                if isSB && !isFacingShove {
                    // Open Shove (SB) - Nash Equilibrium 近似
                    var shoveThreshold = 0.45 // default ~top 40%
                    if stackBB <= 5 { shoveThreshold = 0.25 } // ~top 80% (almost any two)
                    else if stackBB <= 8 { shoveThreshold = 0.35 } // ~top 60%
                    else if stackBB <= 12 { shoveThreshold = 0.40 } // ~top 50%
                    else { shoveThreshold = 0.45 }
                    
                    // 针对对手的剥削调整：
                    // 如果对手打得紧（不激进），扩大偷盲范围
                    if aggScore < 0.4 { shoveThreshold -= 0.10 }
                    // 如果对手是疯鱼（逢推必接或极爱全押），收紧偷盲范围，只拿好牌去推
                    if aggScore > 0.7 { shoveThreshold += 0.10 }
                    
                    if handStrength >= shoveThreshold {
                        return .allIn(amount: validActions.allInAmount)
                    }
                } else if !isSB && isFacingShove {
                    // Call Shove (BB facing All-in) - Nash Equilibrium 近似
                    var callThreshold = 0.50 // default tight
                    if stackBB <= 5 { callThreshold = 0.35 } // ~top 60%
                    else if stackBB <= 8 { callThreshold = 0.42 } // ~top 45%
                    else if stackBB <= 12 { callThreshold = 0.48 } // ~top 35%
                    else { callThreshold = 0.52 }
                    
                    // 针对疯鱼的剥削调整：大幅度降低接推门槛，用任意两张高牌或任意对子抓鸡
                    if aggScore > 0.7 { 
                        callThreshold -= 0.15 
                    } else if aggScore > 0.5 {
                        callThreshold -= 0.08
                    }
                    
                    if handStrength >= callThreshold {
                        return validActions.canCall ? .call(amount: validActions.callAmount) : .allIn(amount: validActions.allInAmount)
                    } else if validActions.canFold {
                        // 修正：短积分拦截前检查套池比例
                        let investedRatio = Double(player.totalInvested) / Double(player.totalInvested + player.chips)
                        if investedRatio >= 0.50 {
                            return validActions.canCall ? .call(amount: validActions.callAmount) : .allIn(amount: validActions.allInAmount)
                        }
                        return .fold
                    }
                }
            } else if stackBB <= 10 {
                // 多人局短积分（原有逻辑保留作为兜底）
                var threshold = allInEquityThreshold(difficulty: player.aiDifficulty, activeCount: activeCount, tilt: tilt)
                if stackBB <= 5 {
                    threshold = 0.20 // SNG 策略模拟器调低多人局短积分推盘门槛（从0.50大幅下调，绝不被盲死）
                    if handStrength >= threshold { return .allIn(amount: validActions.allInAmount) }
                } else {
                    let urgency = max(0.0, min(1.0, (10.0 - stackBB) / 5.0))
                    threshold -= 0.15 * urgency // 增加紧迫感带来的阈值下调
                    let prob = max(0.0, min(0.95, 0.40 + 0.30 * urgency + 0.10 * tilt)) // 增加推盘随机概率
                    if handStrength >= threshold || Double.random(in: 0..<1) < prob * max(0.0, handStrength - (threshold - 0.10)) {
                        // 防止早期 100BB 时进入短积分逻辑误判
                        if stackBB <= 15 { 
                            return .allIn(amount: validActions.allInAmount)
                        }
                    }
                }
            }
        }

        if gameState.phase == .preflop, tilt > 0.55, validActions.canAllIn {
            // SNG 策略模拟器中禁止因为 Tilt 直接无脑 All-in（送人头）
            // 降低这个概率或者彻底屏蔽
            let prob: Double
            switch player.aiDifficulty {
            case .easy: prob = 0.005
            case .medium: prob = 0.01
            case .hard: prob = 0.01
            case .loose: prob = 0.02
            }
            if Double.random(in: 0..<1) < prob * tilt {
                if stackBB <= 40 {
                    return .allIn(amount: validActions.allInAmount)
                }
            }
        }

        // 计算有效总分 (Effective Pot)
        // 防止深积分玩家全押时，虚高的 gameState.pot 导致 EV 计算错误
        let effectivePot = calculateEffectivePot(for: player, gameState: gameState)
        
        // Calculate pot odds
        let potOdds = calculatePotOdds(
            callAmount: validActions.callAmount,
            pot: effectivePot
        )

        // Use GTO-inspired strategy
        let action = selectGTOAction(
            handStrength: handStrength,
            potOdds: potOdds,
            validActions: validActions,
            player: player,
            gameState: gameState,
            effectivePot: effectivePot,
            tilt: tilt,
            allInThreshold: allInEquityThreshold(difficulty: player.aiDifficulty, activeCount: activeCount, tilt: tilt),
            randomOffset: randomOffset
        )

        return action
    }

    // MARK: - Hand Strength Calculation

    private func calculateHandStrength(
        heroPlayerId: UUID,
        holeCards: [Card],
        communityCards: [Card],
        players: [Player],
        evaluator: HandEvaluator,
        maxSimulations: Int,
        deadline: CFAbsoluteTime,
        gameState: GameState
    ) -> Double {
        let opponents = players
            .filter { $0.id != heroPlayerId && $0.isActive && !$0.isFolded }

        guard !opponents.isEmpty else { return 1.0 }

        var totalEquity = 0.0
        var performed = 0
        let simulations = max(1, maxSimulations)

        for _ in 0..<simulations {
            if CFAbsoluteTimeGetCurrent() > deadline {
                break
            }

            var used = Set<Card>(holeCards + communityCards)
            var sampledOpponents: [[Card]] = []
            sampledOpponents.reserveCapacity(opponents.count)

            var ok = true
            for opp in opponents {
                let range = opponentRangeSpec(player: opp, heroPlayerId: heroPlayerId, gameState: gameState)
                guard let oppHole = sampleHoleCardsFromRange(range: range, excluding: used) else {
                    ok = false
                    break
                }
                used.insert(oppHole[0])
                used.insert(oppHole[1])
                sampledOpponents.append(oppHole)
            }

            if !ok {
                continue
            }

            var deck = Deck()
            deck.reset()
            deck.cards.removeAll { used.contains($0) }
            deck.shuffle()

            var board = communityCards
            if board.count < 5 {
                board.append(contentsOf: deck.draw(count: 5 - board.count))
            }

            let heroHand = evaluator.evaluateBestHand(holeCards: holeCards, communityCards: board)

            var bestHands: [CardCombination] = [heroHand]
            bestHands.reserveCapacity(sampledOpponents.count + 1)

            for oppHole in sampledOpponents {
                bestHands.append(evaluator.evaluateBestHand(holeCards: oppHole, communityCards: board))
            }

            let best = bestHands.max()!
            let winners = bestHands.filter { $0 == best }.count
            if heroHand == best {
                totalEquity += 1.0 / Double(winners)
            }
            performed += 1
        }

        guard performed > 0 else { return 0.5 }
        return totalEquity / Double(performed)
    }

    private func calculatePreflopStrength(holeCards: [Card], gameState: GameState? = nil) -> Double {
        let ranks = holeCards.map { $0.numericValue }.sorted(by: >)
        let sameSuit = holeCards[0].suit == holeCards[1].suit

        var strength = 0.0

        if ranks[0] == ranks[1] {
            // Pocket pairs: 22 is ~0.50, AA is ~0.85
            strength = 0.50 + Double(ranks[0] - 2) * 0.029
        } else {
            // Non-pairs
            let high = Double(ranks[0])
            let low = Double(ranks[1])
            
            strength = 0.30 + (high - 2) * 0.020 + (low - 2) * 0.007
            
            if sameSuit {
                strength += 0.035
            }
            
            let gap = ranks[0] - ranks[1]
            if gap == 1 {
                strength += 0.030
            } else if gap == 2 {
                strength += 0.015
            } else if gap == 3 {
                strength += 0.005
            }
        }
        
        // --- 动态调整对抗极度激进的玩家 ---
        if let state = gameState {
            let humanPlayers = state.players.filter { $0.isHuman }
            if let human = humanPlayers.first {
                let aggScore = opponentAggressionScore(for: human.id, gameState: state)
                // 如果人类玩家非常激进（疯狂 3bet/all-in）
                if aggScore > 0.6 {
                    // 放宽“抓鸡”价值牌的认定范围：从 88+ 和 AJ+ 放宽到 77+, AT+, KJs+
                    let isGoodPair = ranks[0] == ranks[1] && ranks[0] >= 7
                    let isGoodHighCards = (ranks[0] >= 14 && ranks[1] >= 10) || (ranks[0] >= 13 && ranks[1] >= 11 && sameSuit)
                    
                    if strength > 0.55 && (isGoodPair || isGoodHighCards) {
                        strength += 0.12 * aggScore // 提升面对激进玩家的胜率评价，鼓励用价值牌接全押
                    }
                    
                    if let currentPlayer = state.currentPlayer, !currentPlayer.isHuman {
                        if state.pot > currentPlayer.chips && strength > 0.55 && (isGoodPair || isGoodHighCards) {
                            strength += 0.08
                        }
                    }
                }
            }
        }

        return min(1.0, max(0.0, strength))
    }

    private func generateRandomHoleCards(excluding: [Card]) -> [Card] {
        var deck = Deck()
        deck.reset()
        deck.cards.removeAll { card in excluding.contains(card) }
        deck.shuffle()

        return [deck.draw()!, deck.draw()!]
    }

    private struct RangeSpec {
        let vpip: Double
        let raiseDepth: Int
        let positionAggression: Double
    }

    private func opponentRangeSpec(player: Player, heroPlayerId: UUID, gameState: GameState) -> RangeSpec {
        let base: Double
        switch player.aiDifficulty {
        case .easy: base = 0.18
        case .medium: base = 0.30
        case .hard: base = 0.26
        case .loose: base = 0.52
        }

        let pos = positionAggression(position: player.position)
        var vpip = base + 0.10 * pos

        let raiseDepth = preflopRaiseDepth(players: gameState.players, bbAmount: max(1, gameState.bbAmount))
        if gameState.phase != .preflop {
            let preAgg = lastPreflopAggressionByPlayer(playerId: player.id, gameState: gameState)
            if preAgg >= 2 {
                vpip -= 0.12
            } else if preAgg == 1 {
                vpip -= 0.07
            }
        }

        vpip = min(0.95, max(0.08, vpip))
        
        if player.isHuman {
            let aggScore = opponentAggressionScore(for: player.id, gameState: gameState)
            if let stats = opponentStats[player.id], stats.isManiac {
                vpip = 0.95 // 针对疯推人类，极度放宽预估范围
            } else if aggScore > 0.6 {
                vpip = min(0.95, vpip + 0.35)
            } else if aggScore > 0.4 {
                vpip = min(0.85, vpip + 0.15)
            }
        }
        
        return RangeSpec(vpip: vpip, raiseDepth: raiseDepth, positionAggression: pos)
    }

    private func lastPreflopAggressionByPlayer(playerId: UUID, gameState: GameState) -> Int {
        let actions = gameState.actionHistory
            .filter { $0.phase == .preflop && $0.playerId == playerId }
            .sorted { $0.timestamp < $1.timestamp }

        var raises = 0
        for a in actions {
            switch a.action {
            case .raise, .bet, .allIn:
                raises += 1
            default:
                break
            }
        }
        return raises
    }

    private func sampleHoleCardsFromRange(range: RangeSpec, excluding: Set<Card>) -> [Card]? {
        var deck = Deck()
        deck.reset()
        deck.cards.removeAll { excluding.contains($0) }

        let combos = allHoleCombos(from: deck.cards)
        if combos.isEmpty { return nil }

        let threshold = preflopScoreCutoff(top: range.vpip)
        var weights: [Double] = []
        weights.reserveCapacity(combos.count)
        var sum = 0.0

        for (a, b) in combos {
            let s = preflopComboScore(a: a, b: b)
            let w = 1.0 / (1.0 + exp(-(s - threshold) / 0.045))
            weights.append(w)
            sum += w
        }

        if sum <= 0 { return nil }

        var r = Double.random(in: 0..<sum)
        for i in 0..<combos.count {
            r -= weights[i]
            if r <= 0 {
                let (a, b) = combos[i]
                return [a, b]
            }
        }

        let (a, b) = combos.last!
        return [a, b]
    }

    private func allHoleCombos(from cards: [Card]) -> [(Card, Card)] {
        guard cards.count >= 2 else { return [] }
        var result: [(Card, Card)] = []
        result.reserveCapacity(cards.count * (cards.count - 1) / 2)
        for i in 0..<(cards.count - 1) {
            for j in (i + 1)..<cards.count {
                result.append((cards[i], cards[j]))
            }
        }
        return result
    }

    private func preflopComboScore(a: Card, b: Card) -> Double {
        let r1 = a.numericValue
        let r2 = b.numericValue
        let hi = max(r1, r2)
        let lo = min(r1, r2)
        let suited = a.suit == b.suit

        if hi == lo {
            return 0.58 + Double(hi - 2) * 0.03
        }

        let gap = hi - lo
        var score = 0.20
        score += Double(hi - 2) * 0.02
        score += Double(lo - 2) * 0.01
        if suited {
            score += 0.06
        }
        if gap == 1 {
            score += suited ? 0.05 : 0.02
        } else if gap == 2 {
            score += suited ? 0.02 : 0.0
        } else if gap >= 4 {
            score -= 0.03
        }
        return min(1.0, max(0.0, score))
    }

    private func preflopScoreCutoff(top vpip: Double) -> Double {
        let p = min(0.85, max(0.05, vpip))
        return 0.78 - 0.55 * p
    }

    private func adjustEquityWithEQRAndAdvantages(
        heroPlayerId: UUID,
        equity: Double,
        holeCards: [Card],
        communityCards: [Card],
        gameState: GameState
    ) -> Double {
        if communityCards.isEmpty {
            return equity
        }

        let ip = isInPosition(heroPlayerId: heroPlayerId, gameState: gameState)
        let draw = drawQuality(holeCards: holeCards, communityCards: communityCards)
        let eqr = eqrFactor(isInPosition: ip, draw: draw)

        let adv = rangeAndNutAdvantage(heroPlayerId: heroPlayerId, communityCards: communityCards, gameState: gameState)
        let adjusted = equity * eqr + 0.03 * adv.rangeAdvantage + 0.02 * adv.nutAdvantage
        return min(1.0, max(0.0, adjusted))
    }

    private func isInPosition(heroPlayerId: UUID, gameState: GameState) -> Bool {
        guard let hero = gameState.players.first(where: { $0.id == heroPlayerId }) else { return false }
        let order = gameState.actionOrder
        guard let idx = order.firstIndex(of: hero.seatId) else { return false }
        return idx == order.count - 1
    }

    private enum DrawQuality {
        case none
        case weak
        case strong
        case nut
    }

    private func drawQuality(holeCards: [Card], communityCards: [Card]) -> DrawQuality {
        let all = holeCards + communityCards
        let suits = Dictionary(grouping: all, by: { $0.suit }).mapValues { $0.count }
        let maxSuitCount = suits.values.max() ?? 0

        var flushDraw = false
        var nutFlushDraw = false
        if maxSuitCount == 4 {
            flushDraw = holeCards.contains { c in suits[c.suit] == 4 }
            nutFlushDraw = flushDraw && holeCards.contains { $0.rank == .ace && suits[$0.suit] == 4 }
        }

        let ranks = Array(Set(all.map(\.numericValue))).sorted()
        var straightDraw = false
        for i in 0..<ranks.count {
            var window: [Int] = [ranks[i]]
            for j in (i + 1)..<ranks.count where ranks[j] - window[0] <= 4 {
                window.append(ranks[j])
            }
            if window.count >= 4 {
                straightDraw = true
                break
            }
        }

        if nutFlushDraw {
            return .nut
        }
        if flushDraw && straightDraw {
            return .strong
        }
        if flushDraw || straightDraw {
            return .weak
        }
        return .none
    }

    private func eqrFactor(isInPosition: Bool, draw: DrawQuality) -> Double {
        switch (isInPosition, draw) {
        case (true, .nut): return 1.12
        case (true, .strong): return 1.08
        case (true, .weak): return 1.03
        case (true, .none): return 1.00
        case (false, .nut): return 1.05
        case (false, .strong): return 0.98
        case (false, .weak): return 0.92
        case (false, .none): return 0.90
        }
    }

    private struct BoardAdvantage {
        let rangeAdvantage: Double
        let nutAdvantage: Double
    }

    private func rangeAndNutAdvantage(heroPlayerId: UUID, communityCards: [Card], gameState: GameState) -> BoardAdvantage {
        guard let hero = gameState.players.first(where: { $0.id == heroPlayerId }) else {
            return BoardAdvantage(rangeAdvantage: 0, nutAdvantage: 0)
        }

        let texture = boardTexture(communityCards: communityCards)
        let preflopAggressor = lastPreflopAggressor(gameState: gameState)
        let isAggressor = preflopAggressor == heroPlayerId

        var rangeAdv = 0.0
        if isAggressor && texture.isHighDry {
            rangeAdv = 0.9
        } else if isAggressor && texture.isDry {
            rangeAdv = 0.6
        }

        let pos = positionAggression(position: hero.position)
        var nutAdv = 0.0
        if texture.isConnectedWet {
            nutAdv = min(1.0, 0.35 + 0.75 * pos)
        } else if texture.isTwoTone {
            nutAdv = min(1.0, 0.25 + 0.65 * pos)
        }

        return BoardAdvantage(rangeAdvantage: rangeAdv, nutAdvantage: nutAdv)
    }

    private func lastPreflopAggressor(gameState: GameState) -> UUID? {
        let actions = gameState.actionHistory
            .filter { $0.phase == .preflop }
            .sorted { $0.timestamp < $1.timestamp }

        var last: UUID?
        for a in actions {
            switch a.action {
            case .raise, .bet, .allIn:
                last = a.playerId
            default:
                break
            }
        }
        return last
    }

    private struct BoardTexture {
        let isTwoTone: Bool
        let isConnectedWet: Bool
        let isDry: Bool
        let isHighDry: Bool
    }

    private func boardTexture(communityCards: [Card]) -> BoardTexture {
        let suits = Dictionary(grouping: communityCards, by: { $0.suit }).mapValues { $0.count }
        let maxSuit = suits.values.max() ?? 0
        let isTwoTone = maxSuit == 2

        let ranks = communityCards.map(\.numericValue).sorted()
        let gaps = zip(ranks.dropFirst(), ranks).map { $0.0 - $0.1 }
        let maxGap = gaps.max() ?? 99
        let isConnectedWet = ranks.count >= 3 && maxGap <= 3

        let isDry = maxSuit == 1 && maxGap >= 4
        let isHighDry = isDry && (ranks.contains(14) || ranks.contains(13))

        return BoardTexture(isTwoTone: isTwoTone, isConnectedWet: isConnectedWet, isDry: isDry, isHighDry: isHighDry)
    }

    // MARK: - ICM Calculator

    private func calculateICM(stacks: [Int], payouts: [Double]) -> [Double] {
        let totalChips = stacks.reduce(0, +)
        guard totalChips > 0 else { return Array(repeating: 0.0, count: stacks.count) }
        
        var results = Array(repeating: 0.0, count: stacks.count)
        
        func icmRecursive(remainingStacks: [Int], currentPayoutIndex: Int, currentProb: Double) {
            if currentPayoutIndex >= payouts.count { return }
            
            let sum = remainingStacks.reduce(0, +)
            guard sum > 0 else { return }
            
            for i in 0..<remainingStacks.count {
                if remainingStacks[i] > 0 {
                    let probFirst = Double(remainingStacks[i]) / Double(sum)
                    results[i] += currentProb * probFirst * payouts[currentPayoutIndex]
                    
                    var nextStacks = remainingStacks
                    nextStacks[i] = 0
                    
                    icmRecursive(remainingStacks: nextStacks, currentPayoutIndex: currentPayoutIndex + 1, currentProb: currentProb * probFirst)
                }
            }
        }
        
        icmRecursive(remainingStacks: stacks, currentPayoutIndex: 0, currentProb: 1.0)
        
        return results
    }

    private func calculateICMRiskPremium(hero: Player, validActions: BettingManager.ValidActions, gameState: GameState) -> Double {
        let activePlayers = gameState.players.filter { !$0.isEliminated && ($0.chips + $0.totalInvested) > 0 }
        guard activePlayers.count >= 2 else { return 0.0 }
        
        guard let heroIndex = activePlayers.firstIndex(where: { $0.id == hero.id }) else { return 0.0 }
        
        let callAmount = validActions.callAmount
        guard callAmount > 0 else { return 0.0 }
        
        // Find main villain (the one who made the highest bet)
        let highestBet = gameState.players.map { $0.currentBet }.max() ?? 0
        let villains = activePlayers.filter { $0.id != hero.id && $0.currentBet == highestBet && !$0.isFolded }
        let villainIndex = villains.first.flatMap { v in activePlayers.firstIndex(where: { $0.id == v.id }) } ?? (heroIndex == 0 ? 1 : 0)
        
        // Stacks for folded scenario
        var foldStacks = activePlayers.map { $0.chips }
        // If hero folds, villain wins the current pot
        foldStacks[villainIndex] += gameState.pot
        
        // Stacks for win scenario
        var winStacks = activePlayers.map { $0.chips }
        winStacks[heroIndex] += gameState.pot + callAmount
        // Villain's stack is just their chips (their bet is already in the pot and they lose it)
        
        // Stacks for lose scenario
        var loseStacks = activePlayers.map { $0.chips }
        loseStacks[heroIndex] = max(0, loseStacks[heroIndex] - callAmount)
        loseStacks[villainIndex] += gameState.pot + callAmount
        
        let payouts = [0.75, 0.25]
        
        let icmFold = calculateICM(stacks: foldStacks, payouts: payouts)[heroIndex]
        let icmWin = calculateICM(stacks: winStacks, payouts: payouts)[heroIndex]
        let icmLose = calculateICM(stacks: loseStacks, payouts: payouts)[heroIndex]
        
        guard icmWin > icmLose else { return 0.0 }
        
        let eqICM = (icmFold - icmLose) / (icmWin - icmLose)
        let eqCEV = Double(callAmount) / Double(gameState.pot + callAmount * 2) // pot + hero's call amount + villain's matching amount?
        // Wait, pot already includes villain's bet. Hero calls `callAmount`, so total pot to win is `pot + callAmount`.
        // EqCEV = callAmount / (pot + callAmount)
        let eqCEV_real = Double(callAmount) / Double(gameState.pot + callAmount)
        
        let riskPremium = eqICM - eqCEV_real
        return max(0.0, min(0.35, riskPremium)) // Cap risk premium
    }

    private func calculateEffectivePot(for player: Player, gameState: GameState) -> Int {
        // 当其他玩家投入额远超 AI 的积分时，AI 实际能赢到的总分（Effective Pot）只包括：
        // 1. AI 之前投入的积分
        // 2. 其他玩家匹配 AI 投入的积分（包括 AI 即将跟注的全部积分）
        // 3. 已弃牌玩家的死钱
        
        let aiMaxPossibleInvestment = player.totalInvested + player.chips
        
        var effective = 0
        for p in gameState.players {
            if p.totalInvested > aiMaxPossibleInvestment {
                effective += aiMaxPossibleInvestment
            } else {
                effective += p.totalInvested
            }
        }
        
        return max(1, effective)
    }

    private func calculatePotOdds(callAmount: Int, pot: Int) -> Double {
        guard callAmount > 0 else { return 1.0 }
        return 1.0 - Double(callAmount) / Double(pot + callAmount)
    }

    private func opponentAggressionScore(for playerId: UUID, gameState: GameState) -> Double {
        let oppActions = gameState.actionHistory.filter { $0.playerId == playerId }
        var aggressionScore = 0.0
        
        let recentActions = oppActions.suffix(5)
        for act in recentActions {
            switch act.action {
            case .raise, .allIn:
                aggressionScore += 0.35
            case .bet:
                aggressionScore += 0.15
            default:
                break
            }
        }
        
        if let stats = opponentStats[playerId], stats.handsPlayed > 0 {
            let allInRate = Double(stats.allInPreflopCount) / Double(stats.handsPlayed)
            if allInRate > 0.20 {
                aggressionScore += (allInRate * 2.0)
            }
            let vpipRate = Double(stats.vpipCount) / Double(stats.handsPlayed)
            if vpipRate > 0.60 {
                aggressionScore += 0.20
            }
        }
        
        return min(1.0, aggressionScore)
    }

    // MARK: - GTO Action Selection

    private func selectGTOAction(
        handStrength: Double,
        potOdds: Double,
        validActions: BettingManager.ValidActions,
        player: Player,
        gameState: GameState,
        effectivePot: Int,
        tilt: Double,
        allInThreshold: Double,
        randomOffset: Double
    ) -> PlayerAction {
        let difficulty = player.aiDifficulty
        let position = positionAggression(position: player.position)
        // 结合难度、位置、上头情绪以及本局分配的随机底色（避免完全可预测）
        let aggression = difficulty.aggressionFactor * (1.0 + 0.15 * position + 0.35 * tilt + randomOffset)

        if handStrength > 0.78, validActions.canRaise, Double.random(in: 0..<1) < (0.18 + 0.12 * aggression) {
            let isHumanFolded = gameState.players.first(where: { $0.isHuman })?.isFolded ?? true
            if !isHumanFolded || handStrength > 0.92 {
                return .raise(amount: validActions.minRaise)
            }
        }

        if gameState.phase != .preflop {
            let activeCount = gameState.players.filter { $0.isActive && !$0.isFolded }.count
            let weakness = opponentWeaknessScore(for: player.id, gameState: gameState)
            let baseBluffP = bluffProbability(difficulty: difficulty, positionAggression: position, tilt: tilt, activeCount: activeCount)
            var bluffP = min(0.35, baseBluffP * (1.0 + 1.35 * weakness))
            
            let isHumanFolded = gameState.players.first(where: { $0.isHuman })?.isFolded ?? true
            if isHumanFolded {
                bluffP = 0.0 // 人类弃牌后，AI 之间绝对不诈唬
            }

            // --- 动态调整对抗紧弱玩家（Tight-Weak Exploitation） ---
            let humanPlayers = gameState.players.filter { $0.isHuman }
            if let human = humanPlayers.first {
                let aggScore = opponentAggressionScore(for: human.id, gameState: gameState)
                // 如果人类玩家极其被动/紧弱（近期极少主动投入或加注）
                if aggScore <= 0.20 {
                    // 大幅增加 AI 的各种投入剥削概率（偷池）
                    bluffP = min(0.70, bluffP + 0.35)
                } else if aggScore <= 0.35 {
                    bluffP = min(0.50, bluffP + 0.15)
                }
            }

            // --- C-bet 增强 (Flop Continuation Bet) ---
            if gameState.phase == .flop && validActions.canBet {
                // 判断 AI 是否是翻牌前的激进者 (Preflop Aggressor)
                // 简化判断：如果在 preflop 中做过 raise
                let aiPreflopActions = gameState.actionHistory.filter { 
                    guard $0.playerId == player.id && $0.phase == .preflop else { return false }
                    if case .raise = $0.action { return true }
                    if case .allIn = $0.action { return true }
                    return false
                }
                if !aiPreflopActions.isEmpty && !isHumanFolded {
                    var cbetProb = 0.45 + 0.15 * aggression
                    
                    // 如果是对抗单个人类，且人类比较 weak 或被动，提高 C-bet
                    if activeCount == 2 && weakness > 0.4 {
                        cbetProb += 0.20
                    }
                    
                    if Double.random(in: 0..<1) < cbetProb {
                        // 1/3 到 1/2 pot，这样被跟注的风险更低，收益更高
                        let cbetSize = max(validActions.betAmount, Int(Double(gameState.pot) * Double.random(in: 0.33...0.5)))
                        let clamped = min(cbetSize, validActions.allInAmount)
                        return .bet(amount: clamped)
                    }
                }
            }

            if validActions.canBet, handStrength >= 0.14, handStrength <= 0.48, Double.random(in: 0..<1) < bluffP, !isHumanFolded {
                let bb = max(1, gameState.bbAmount)
                var amount = bluffBetAmount(pot: gameState.pot, bbAmount: bb, chips: validActions.allInAmount, positionAggression: position, difficulty: difficulty, activeCount: activeCount)
                
                // --- 河牌极端诈唬（River Polarized Bluffing） ---
                if gameState.phase == .river && Double.random(in: 0..<1) < 0.30 {
                    // 河牌有 30% 概率做超大尺度诈唬，逼迫人类弃牌
                    amount = min(validActions.allInAmount, Int(Double(gameState.pot) * 1.2))
                }
                
                return .bet(amount: amount)
            }

            if validActions.canRaise, validActions.minRaise < validActions.allInAmount, handStrength >= 0.16, handStrength <= 0.30, Double.random(in: 0..<1) < bluffP * 0.75, !isHumanFolded {
                return .raise(amount: validActions.minRaise)
            }
        }

        var actionEVs: [(PlayerAction, Double)] = []
        
        let isEarlyStage = gameState.bbAmount <= 50 // 假设底分比较小是早期
        let activePlayersCount = gameState.players.filter { $0.isActive && $0.chips > 0 }.count
        let isBubble = activePlayersCount == 3
        
        let bbAmountForDepth = max(1, gameState.bbAmount)
        let raiseDepth = preflopRaiseDepth(players: gameState.players, bbAmount: bbAmountForDepth)
        let isFacing4BetOrMore = gameState.phase == .preflop && raiseDepth >= 3
        
        let isHumanFolded = gameState.players.first(where: { $0.isHuman })?.isFolded ?? true
        
        let totalInvestedThisHand = player.totalInvested
        let remainingChips = player.chips
        let totalStack = totalInvestedThisHand + remainingChips
        let investedRatio = Double(totalInvestedThisHand) / Double(max(1, totalStack))
        
        // 核心参数：翻牌后，如果人类玩家尚未弃牌且已经投入（AI 面临跟注），且 AI 的套池深度 > 50%
        let isPostFlopPotCommittedVsHuman = gameState.phase != .preflop && !isHumanFolded && validActions.callAmount > 0 && investedRatio > 0.50

        // 如果人类弃牌，并且 AI 正在考虑是否走 GTO 判断
        if isHumanFolded && handStrength < 0.90 && Double.random(in: 0..<1) < 0.85 {
            // 当人类弃牌，AI 之间有极高概率主动降低攻击性，直接进入保守评估（快速推进牌局）
        }

        // --- SNG 策略模拟器 ICM / 生存意识调整 ---
        // 使用独立积分模型（ICM）计算风险溢价，评估真实比赛收益
        var riskPremium = 0.0
        if gameState.phase == .preflop || validActions.callAmount >= player.chips / 2 {
            riskPremium = calculateICMRiskPremium(hero: player, validActions: validActions, gameState: gameState)
        } else {
            // 对于非关键决策的后续轮次小投入，ICM 影响较小，退回到简单的经验溢价
            if validActions.callAmount >= player.chips / 3 {
                if isBubble {
                    riskPremium = 0.10
                } else if isEarlyStage {
                    riskPremium = 0.08
                } else {
                    riskPremium = 0.03
                }
            }
        }
        
        // --- [新增] 泡沫期防滥用（Bubble Abuse Defense） ---
        let humanPlayers = gameState.players.filter { $0.isHuman }
        var isHumanAbusingBubble = false
        if let human = humanPlayers.first {
            let aggScore = opponentAggressionScore(for: human.id, gameState: gameState)
            if isBubble && aggScore > 0.55 {
                isHumanAbusingBubble = true
                // 如果人类在泡沫期极其激进（利用大积分施压），AI 大幅削减风险溢价，准备反击抓鸡
                riskPremium *= 0.3
            }
        }

        if validActions.canFold {
            if validActions.canCheck {
                // 如果可以免费过牌，AI 绝不主动弃牌
                actionEVs.append((.fold, -99999.0))
            } else {
                var foldEV = 0.0 - 0.03 * tilt
                
                // 强制套池判断：如果 AI 已经投入了其积分的 50% 及以上，绝不弃牌
                if investedRatio >= 0.50 {
                    // 强制赋予极低 EV，让 AI 绝对不会选择弃牌，只能 Call 或 All-in
                    foldEV = -99999.0
                } else {
                    // 削弱套池惩罚，避免 AI 因为稍微套池就用烂牌接全押
                    if remainingChips < effectivePot / 2 || validActions.callAmount >= remainingChips / 2 {
                        if handStrength > (0.30 + riskPremium) { // 提高套池死磕的门槛
                            let commitmentFactor = Double(effectivePot) / Double(max(1, remainingChips))
                            // 降低惩罚力度，从 100 降到 40，但针对 SNG 策略模拟器后期加重
                            var penaltyMultiplier = 40.0
                            if activePlayersCount <= 3 && validActions.callAmount >= remainingChips / 2 {
                                penaltyMultiplier = 120.0 // 后期大比例跟注时，套池极难弃牌
                            }
                            foldEV -= (penaltyMultiplier * commitmentFactor)
                        }
                    }
                    
                    // --- 动态调整对抗极度激进玩家时的弃牌 EV ---
                    let humanPlayers = gameState.players.filter { $0.isHuman }
                    if let human = humanPlayers.first {
                        let aggScore = opponentAggressionScore(for: human.id, gameState: gameState)
                        if aggScore > 0.6 {
                            // 降低针对疯鱼的过度死磕（防止用烂牌去接疯鱼的全押）
                            foldEV -= (80.0 * aggScore) 
                            
                            if effectivePot > player.chips {
                                foldEV -= 200.0 // 从 800 降到 200，允许 AI 弃掉中等偏下的牌
                            }
                        }
                    }
                    
                    // 泡沫期生存奖励：如果不是必须跟注，给弃牌加一点正向 EV，鼓励苟活
                    if isBubble && validActions.callAmount >= player.chips / 3 {
                        if !isHumanAbusingBubble {
                            foldEV += 50.0 
                        } else {
                            // 人类疯狂施压时，不仅不苟活，甚至要降低弃牌 EV 鼓励接战
                            foldEV -= 20.0
                        }
                    }
                }
                
                actionEVs.append((.fold, foldEV))
            }
        }

        if validActions.canCheck {
            var checkEV = 0.0
            
            // --- 慢打/过牌-加注（Trapping / Check-Raise Setup） ---
            // 当 AI 拿到绝对强牌（>0.88），不再无脑投入，有概率故意过牌给人类下套
            if handStrength > 0.88 && gameState.phase != .preflop {
                let humanPlayers = gameState.players.filter { $0.isHuman }
                if let human = humanPlayers.first {
                    let aggScore = opponentAggressionScore(for: human.id, gameState: gameState)
                    // 对手越激进，AI 越倾向于埋伏
                    // 但如果对手极其紧弱（aggScore < 0.25），我们绝不慢打，因为对手极大概率也会过牌
                    if aggScore >= 0.25 && Double.random(in: 0..<1) < (0.2 + 0.5 * aggScore) {
                        checkEV += Double(effectivePot) * 0.8 * aggression
                    }
                }
            }
            
            // --- 翻前坚果牌诱捕陷阱 (Pre-flop Trapping with Monsters) ---
            if handStrength > 0.83 && gameState.phase == .preflop {
                let humanPlayers = gameState.players.filter { $0.isHuman }
                if let human = humanPlayers.first {
                    let aggScore = opponentAggressionScore(for: human.id, gameState: gameState)
                    // 如果人类玩家极其激进（疯推），我们在大盲位拿到强牌可以选择过牌（埋伏）而不是加注
                    if aggScore > 0.6 && Double.random(in: 0..<1) < 0.4 {
                        checkEV += Double(effectivePot) * 0.9 * aggression
                    }
                }
            }
            
                if isHumanFolded {
                    // 如果人类玩家已经弃牌，AI 之间应该大幅增加彼此 check-down 的倾向，避免内部残杀让弃牌的人类坐收渔利
                    checkEV += Double(effectivePot) * 1.5 
                }
                
                actionEVs.append((.check, checkEV))
        }

        if validActions.canCall {
            // 在 SNG 策略模拟器中，跟注大额投入需要扣除风险溢价，避免频繁用边缘牌抓诈唬
            let adjustedHandStrength = handStrength - riskPremium
            var callEV = (adjustedHandStrength * Double(effectivePot + validActions.callAmount)) - Double(validActions.callAmount)
            
            // --- 防持续投入（C-bet Defense / Floating）增强 ---
            // 如果是在翻牌圈（Flop），面对人类的 C-bet，即使胜率不占绝对优势，也该有韧性（比如用底对或高张 Float）
            if gameState.phase == .flop {
                let humanPlayers = gameState.players.filter { $0.isHuman }
                if let human = humanPlayers.first {
                    let aggScore = opponentAggressionScore(for: human.id, gameState: gameState)
                    // 放宽到 0.20，允许两张高牌、卡顺等有任何潜力的牌去 Float 激进玩家
                    if aggScore > 0.4 && handStrength > 0.20 {
                        // 对于有一定潜力的牌，增加 Float 的 EV 权重，防止人类 100% C-bet 收割
                        // 但如果面临巨大的超额投入 (Overbet)，必须大幅度衰减补偿，防止用弱牌死抓大注诈唬
                        let betToPotRatio = Double(validActions.callAmount) / Double(max(1, effectivePot))
                        var floatMultiplier = 0.40
                        if betToPotRatio > 0.8 {
                            floatMultiplier = 0.10 // 面对接近满池或超池投入，大幅削弱 Float 补偿
                        } else if betToPotRatio > 0.5 {
                            floatMultiplier = 0.25
                        }
                        callEV += (Double(effectivePot) * floatMultiplier * aggScore)
                    }
                    
                    let smallRaise = validActions.callAmount <= Int(Double(effectivePot) * 0.45)
                    if smallRaise && handStrength > 0.22 {
                        callEV += (Double(effectivePot) * (0.12 + 0.08 * aggScore))
                    }
                }
            }
            
            // --- 转牌圈防连开两枪（Turn Double Barrel Defense）增强 ---
            if gameState.phase == .turn {
                let humanPlayers = gameState.players.filter { $0.isHuman }
                if let human = humanPlayers.first {
                    let aggScore = opponentAggressionScore(for: human.id, gameState: gameState)
                    // 如果人类连开两枪，且玩家胜率 > 0.45（中等牌力以上），强行增加跟注 EV
                    if aggScore > 0.5 && handStrength > 0.45 {
                        let betToPotRatio = Double(validActions.callAmount) / Double(max(1, effectivePot))
                        var callMultiplier = 0.35
                        if betToPotRatio > 0.8 {
                            callMultiplier = 0.10 // 如果第二枪打得很重，削减跟注倾向
                        } else if betToPotRatio > 0.5 {
                            callMultiplier = 0.20
                        }
                        callEV += (Double(effectivePot) * callMultiplier * aggScore)
                    }
                }
            }
            
            // --- 河牌抓诈唬（Hero Call）增强 ---
            // 当面临河牌极大的投入（如总分大小或全押），传统 EV 计算会导致 AI 频繁弃牌
            // 针对激进玩家，AI 如果手牌具备中等以上摊牌价值（如顶对弱踢脚/中对），应该增加抓诈的倾向
            if gameState.phase == .river && validActions.callAmount >= effectivePot / 2 {
                let humanPlayers = gameState.players.filter { $0.isHuman }
                if let human = humanPlayers.first {
                    let aggScore = opponentAggressionScore(for: human.id, gameState: gameState)
                    // 如果对手打法激进，且 AI 牌力大于 0.65（通常代表中等到顶对），强行提升 Call EV
                    if aggScore > 0.5 && handStrength > 0.65 {
                        callEV += (Double(effectivePot) * 0.45 * aggScore)
                    }
                }
            }
            
            // --- 翻前防剥削 (Pre-flop Anti-Exploit) ---
            if gameState.phase == .preflop && validActions.callAmount > gameState.bbAmount * 3 {
                let humanPlayers = gameState.players.filter { $0.isHuman }
                if let human = humanPlayers.first {
                    let aggScore = opponentAggressionScore(for: human.id, gameState: gameState)
                    if aggScore > 0.6 {
                        // 针对疯鱼在翻前的瞎加注（如直接全押或 10xBB 的大加注）
                        // 提升优质牌（例如 88+, AJs+，大致牌力在 0.55 以上）跟注的 EV
                        if handStrength > 0.55 {
                            callEV += Double(effectivePot) * 1.5 * aggScore
                        } else {
                            // 坚决弃掉边缘牌和垃圾牌（惩罚其跟注 EV）
                            callEV -= (Double(effectivePot) * 0.8)
                        }
                    }
                }
            }
            
            actionEVs.append((.call(amount: validActions.callAmount), callEV + 0.15 * Double(validActions.callAmount) * potOdds))
        }

        if validActions.canBet {
            // --- 动态价值投入尺度（Value Bet Sizing） ---
            // 根据牌力计算不同的投入尺度（半池、满池、超池），而不是永远下最小注
            let halfPot = max(validActions.betAmount, effectivePot / 2)
            let fullPot = max(validActions.betAmount, effectivePot)
            let overPot = max(validActions.betAmount, Int(Double(effectivePot) * 1.5))
            
            var isTightWeak = false
            let humanPlayers = gameState.players.filter { $0.isHuman }
            if let human = humanPlayers.first {
                let aggScore = opponentAggressionScore(for: human.id, gameState: gameState)
                if aggScore <= 0.25 { isTightWeak = true }
            }
            
            let sizes = [halfPot, fullPot, overPot]
            for size in sizes {
                let safeSize = min(size, validActions.allInAmount)
                var betEV = (handStrength * Double(effectivePot + safeSize)) - Double(safeSize)
                
                // 牌力越强，越大尺度的投入附加更高的 EV 权重
                var sizingBonus = 1.0
                if handStrength > 0.85 && safeSize == overPot {
                    // 对紧弱玩家不要打超大注，会把他们吓跑；正常玩家则可以重锤
                    sizingBonus = isTightWeak ? 0.8 : 1.2
                } else if handStrength > 0.65 && safeSize == halfPot {
                    // 面对紧弱玩家，倾向于打半池拿薄价值（引诱他们跟注）
                    sizingBonus = isTightWeak ? 1.3 : 1.0
                }
                
                if isHumanFolded && safeSize > halfPot {
                    // 如果人类弃牌了，AI 之间避免在非绝佳牌力时打大注互锤
                    if handStrength < 0.90 {
                        betEV -= Double(effectivePot) * 1.0
                    }
                }
                
                actionEVs.append((.bet(amount: safeSize), betEV * aggression * sizingBonus))
            }
        }

        if validActions.canRaise && !isFacing4BetOrMore {
            // --- 动态价值加注尺度（Value Raise Sizing） ---
            // 不要总是只做最小加注（Min Raise），这极易被人类识破并剥削
            let minRaise = validActions.minRaise
            let potRaise = max(minRaise, effectivePot + validActions.callAmount * 2)
            
            var isTightWeak = false
            let humanPlayers = gameState.players.filter { $0.isHuman }
            if let human = humanPlayers.first {
                let aggScore = opponentAggressionScore(for: human.id, gameState: gameState)
                if aggScore <= 0.25 { isTightWeak = true }
            }
            
            let sizes = [minRaise, potRaise]
            for size in sizes {
                let safeSize = min(size, validActions.allInAmount)
                
                var expectedEquity = handStrength
                // --- 翻前加注胜率折损 ---
                // AI 加注后，对手跟注或反加的范围会变强，导致 AI 真实胜率下降
                if gameState.phase == .preflop {
                    let depth = preflopRaiseDepth(players: gameState.players, bbAmount: max(1, gameState.bbAmount))
                    if depth >= 1 {
                        expectedEquity *= (1.0 - 0.08 * Double(depth))
                    } else {
                        expectedEquity *= 0.90 // Open Raise 被跟注的范围也比随机牌强
                    }
                }
                
                var raiseEV = (expectedEquity * Double(effectivePot + safeSize * 2)) - Double(safeSize)
                
                var sizingBonus = 1.0
                if handStrength > 0.85 {
                    if safeSize == potRaise {
                        sizingBonus = isTightWeak ? 0.9 : 1.2
                    } else if safeSize == minRaise {
                        sizingBonus = isTightWeak ? 1.3 : 1.0 // 对紧弱玩家，小加注更容易得到跟注
                    }
                }
                
                if isHumanFolded {
                    // 如果人类弃牌，AI 之间避免在非坚果牌力时做 Raise 互相伤害
                    if handStrength < 0.95 {
                        raiseEV -= Double(effectivePot) * 1.5
                    }
                }
                
                // 翻牌后套池反击机制
                if isPostFlopPotCommittedVsHuman && handStrength > 0.40 {
                    // 如果套池>50%且面对人类投入，极大提升加注的反击意愿，降低被动跟注的倾向
                    sizingBonus += 1.5
                    raiseEV += Double(effectivePot) * 1.5
                }
                
                actionEVs.append((.raise(amount: safeSize), raiseEV * aggression * sizingBonus))
            }
        }

        if validActions.canAllIn {
            let allInAmount = validActions.allInAmount
            let bb = max(1, gameState.bbAmount)
            let allInBB = Double(allInAmount) / Double(bb)
            
            // SNG 早期阶段深积分（大于 40BB）时，全押的门槛需要极高，过滤掉中等强牌的无脑推盘
            var adjustedAllInThreshold = allInThreshold
            if isEarlyStage && allInBB > 40 {
                adjustedAllInThreshold = min(0.82, allInThreshold + 0.10)
                
                // 1v1 单挑应对深积分人类疯推
                let humanPlayers = gameState.players.filter { $0.isHuman }
                let activeCount = gameState.players.filter { $0.isActive && !$0.isFolded }.count
                if activeCount == 2, let human = humanPlayers.first {
                    if opponentAggressionScore(for: human.id, gameState: gameState) > 0.6 {
                        adjustedAllInThreshold -= 0.15 // 单挑放宽深筹推盘底线
                    }
                }
            }
            
            // 如果面临 4Bet+，进一步提高 EV 计算中的 AllIn 门槛
            if isFacing4BetOrMore {
                adjustedAllInThreshold = max(adjustedAllInThreshold, 0.85) // 极度限制乱推
                
                // 剥削调整：如果是被极度激进的玩家 4bet，稍微降低底线，防止被无限 steal
                let humanPlayers = gameState.players.filter { $0.isHuman }
                if let human = humanPlayers.first {
                    let aggScore = opponentAggressionScore(for: human.id, gameState: gameState)
                    if aggScore > 0.6 {
                        adjustedAllInThreshold -= (0.08 * aggScore)
                    }
                }
            }
            
            if isHumanFolded {
                // 如果人类已经弃牌，AI 之间绝对不再互相 All-in（除非拿着绝对坚果，胜率 > 0.98）
                adjustedAllInThreshold = max(adjustedAllInThreshold, 0.98)
            }
            
            if isPostFlopPotCommittedVsHuman {
                // 翻牌后套池反击机制：如果套池>50%且面对人类投入，极大放宽全押门槛
                adjustedAllInThreshold = min(adjustedAllInThreshold, 0.40)
            }
            
            let allowAllIn = allInBB < 6 || handStrength >= adjustedAllInThreshold
            if allowAllIn {
                // 深积分主动全押 EV 折损：对手只会用极强牌接推，所以你的真实胜率会大幅下降
                let expectedEquity = (isEarlyStage && allInBB > 40) ? (handStrength * 0.75) : handStrength
                var allInEV = (expectedEquity * Double(effectivePot + allInAmount * 2)) - Double(allInAmount)
                
                if isPostFlopPotCommittedVsHuman && handStrength > 0.40 {
                    // 套池情况下，大幅增加全押的 EV
                    allInEV += Double(effectivePot) * 2.0
                }
                
                // SNG 策略模拟器后期（2-3人），如果在翻牌后已经深度套池（投入 > 30% 总积分），或者面临大额投入且牌力尚可
                if activePlayersCount <= 3 && gameState.phase != .preflop && handStrength > 0.60 && investedRatio > 0.30 {
                    allInEV += Double(effectivePot) * 1.5 // 强行拉高推盘意愿，防止被推死
                }
                
                // 如果是深积分强行 All-in，增加惩罚，迫使 AI 优先选择 normal Raise 或 Bet
                let penaltyMultiplier = (isEarlyStage && allInBB > 40) ? 0.4 : 1.0
                actionEVs.append((.allIn(amount: allInAmount), allInEV * aggression * (0.65 + 0.25 * tilt) * penaltyMultiplier))
            }
        }

        let temperature: Double
        switch difficulty {
        case .easy: temperature = 0.16 + 0.10 * tilt
        case .medium: temperature = 0.22 + 0.12 * tilt
        case .hard: temperature = 0.20 + 0.10 * tilt
        case .loose: temperature = 0.30 + 0.18 * tilt
        }

        // --- 加入实时决策随机扰动 ---
        // 即使是同一局的同一个 AI，每次决策时的温度也会有微小的随机波动（+/- 0.05）
        // 这会让 softmax 采样的结果不那么死板，增加打法的不可预测性
        let dynamicTemperature = max(0.05, temperature + Double.random(in: -0.05...0.05))

        return sampleAction(actionEVs: actionEVs, temperature: dynamicTemperature, fallback: fallbackAction(validActions: validActions))
    }

    private func fallbackAction(validActions: BettingManager.ValidActions) -> PlayerAction {
        if validActions.canCheck {
            return .check
        }
        if validActions.canCall {
            return .call(amount: validActions.callAmount)
        }
        if validActions.canAllIn {
            return .allIn(amount: validActions.allInAmount)
        }
        return .check
    }

    private func sampleAction(actionEVs: [(PlayerAction, Double)], temperature: Double, fallback: PlayerAction) -> PlayerAction {
        guard !actionEVs.isEmpty else { return fallback }

        let maxEV = actionEVs.map(\.1).max() ?? 0
        var weights: [Double] = []
        weights.reserveCapacity(actionEVs.count)

        for (_, ev) in actionEVs {
            let x = (ev - maxEV) / max(0.05, temperature)
            weights.append(exp(x))
        }

        let sum = weights.reduce(0, +)
        if sum <= 0 {
            return actionEVs.max(by: { $0.1 < $1.1 })?.0 ?? fallback
        }

        var r = Double.random(in: 0..<sum)
        for i in 0..<actionEVs.count {
            r -= weights[i]
            if r <= 0 {
                return actionEVs[i].0
            }
        }
        return actionEVs.last?.0 ?? fallback
    }

    private func positionAggression(position: Player.Position) -> Double {
        switch position {
        case .utg: return 0.0
        case .mp: return 0.25
        case .co: return 0.55
        case .button: return 0.75
        case .sb: return 0.45
        case .bb: return 0.35
        }
    }

    private func allInEquityThreshold(difficulty: Player.AIDifficulty, activeCount: Int, tilt: Double) -> Double {
        let base: Double
        switch difficulty {
        case .easy: base = 0.78
        case .medium: base = 0.76
        case .hard: base = 0.74
        case .loose: base = 0.70
        }

        let multiwayPenalty = max(0.0, Double(activeCount - 2) * 0.025)
        let tiltAdjustment = -min(0.02, 0.02 * tilt)
        return min(0.88, max(0.65, base + multiwayPenalty + tiltAdjustment))
    }

    private func preflopRaiseDepth(players: [Player], bbAmount: Int) -> Int {
        let levels = Set(players.map(\.currentBet)).filter { $0 > bbAmount }
        return levels.count
    }

    private func fourBetRaiseThreshold(difficulty: Player.AIDifficulty, positionAggression: Double, tilt: Double, activeCount: Int) -> Double {
        let base: Double
        switch difficulty {
        case .easy: base = 0.82
        case .medium: base = 0.80
        case .hard: base = 0.78
        case .loose: base = 0.75
        }
        let posAdj = -0.02 * positionAggression
        let tiltAdj = -0.03 * tilt
        let multiwayPenalty = max(0.0, Double(activeCount - 2) * 0.020)
        return min(0.90, max(0.72, base + posAdj + tiltAdj + multiwayPenalty))
    }

    private func fiveBetAllInThreshold(difficulty: Player.AIDifficulty, positionAggression: Double, tilt: Double, activeCount: Int) -> Double {
        let base: Double
        switch difficulty {
        case .easy: base = 0.85
        case .medium: base = 0.83
        case .hard: base = 0.81
        case .loose: base = 0.78
        }
        let posAdj = -0.01 * positionAggression
        let tiltAdj = -0.02 * tilt
        let multiwayPenalty = max(0.0, Double(activeCount - 2) * 0.020)
        return min(0.92, max(0.75, base + posAdj + tiltAdj + multiwayPenalty))
    }

    private func bluffProbability(difficulty: Player.AIDifficulty, positionAggression: Double, tilt: Double, activeCount: Int) -> Double {
        let base: Double
        switch difficulty {
        case .easy: base = 0.040
        case .medium: base = 0.070
        case .hard: base = 0.060
        case .loose: base = 0.165
        }

        let posBoost = 1.0 + 0.70 * positionAggression
        let tiltBoost = 1.0 + 0.70 * tilt
        let headsUpBoost = activeCount == 2 ? 1.55 : 1.0
        let multiwayPenalty = 1.0 / (1.0 + 0.85 * Double(max(0, activeCount - 2)))

        return min(0.30, max(0.0, base * posBoost * tiltBoost * headsUpBoost * multiwayPenalty))
    }

    private func bluffBetAmount(pot: Int, bbAmount: Int, chips: Int, positionAggression: Double, difficulty: Player.AIDifficulty, activeCount: Int) -> Int {
        let baseRatio: Double
        switch difficulty {
        case .easy: baseRatio = 0.45
        case .medium: baseRatio = 0.55
        case .hard: baseRatio = 0.58
        case .loose: baseRatio = 0.68
        }

        let posAdj = 0.08 * positionAggression
        let multiwayAdj = -0.08 * Double(max(0, activeCount - 2))
        let ratio = min(0.75, max(0.35, baseRatio + posAdj + multiwayAdj))

        let target = max(bbAmount, Int(Double(pot) * ratio))
        return min(chips, target)
    }

    private func opponentWeaknessScore(for playerId: UUID, gameState: GameState) -> Double {
        let currentRound = gameState.bettingRound
        let currentPhase = gameState.phase

        let roundActions = gameState.actionHistory
            .filter { $0.phase == currentPhase && $0.bettingRound == currentRound }
            .sorted { $0.timestamp < $1.timestamp }

        let oppActions = roundActions.filter { $0.playerId != playerId }
        guard let lastOpp = oppActions.last else { return 0.0 }

        let lastOppIsCheck: Double = (lastOpp.action == .check) ? 1.0 : 0.0

        var consecutiveCheck: Double = 0.0
        if lastOpp.action == .check {
            let prevRoundActions = gameState.actionHistory
                .filter { $0.bettingRound == currentRound - 1 }
                .sorted { $0.timestamp < $1.timestamp }
            if let prevOppLast = prevRoundActions.last(where: { $0.playerId != playerId }), prevOppLast.action == .check {
                consecutiveCheck = 1.0
            }
        }

        var smallBetWeakness: Double = 0.0
        if case .bet(let amt) = lastOpp.action, amt > 0 {
            let bb = max(1, gameState.bbAmount)
            let smallByBB = amt <= bb * 2
            let smallByPot = Double(amt) <= Double(max(1, gameState.pot)) * 0.25
            if smallByBB || smallByPot {
                smallBetWeakness = 1.0
            }
        } else if case .raise(let amt) = lastOpp.action, amt > 0 {
            let bb = max(1, gameState.bbAmount)
            let smallByBB = amt <= bb * 2
            let smallByPot = Double(amt) <= Double(max(1, gameState.pot)) * 0.25
            if smallByBB || smallByPot {
                smallBetWeakness = 1.0
            }
        }

        let score = 0.55 * lastOppIsCheck + 0.25 * consecutiveCheck + 0.35 * smallBetWeakness
        return min(1.0, max(0.0, score))
    }

    private func actionAmount(_ action: PlayerAction) -> Int? {
        switch action {
        case .fold, .check:
            return nil
        case .call(let amount):
            return amount
        case .bet(let amount):
            return amount
        case .raise(let amount):
            return amount
        case .allIn(let amount):
            return amount
        }
    }
}
