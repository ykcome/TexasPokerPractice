import Foundation

// MARK: - Betting Manager

final class BettingManager {

    static let shared = BettingManager()

    private init() {}

    // MARK: - Pot Calculation

    func calculateTotalPot(players: [Player]) -> Int {
        players.reduce(0) { $0 + $1.currentBet }
    }

    func calculateMainPot(players: [Player], highestBet: Int) -> Int {
        var pot = 0
        for player in players {
            pot += min(player.currentBet, highestBet)
        }
        return pot
    }

    func calculateSidePots(players: [Player], highestBet: Int) -> [Int] {
        var sidePots: [Int] = []
        var sortedPlayers = players.filter { $0.currentBet > highestBet }
            .sorted { $0.currentBet < $1.currentBet }

        var remainingPlayers = Set(players.map { $0.id })
        var currentBetLevel = highestBet

        while !sortedPlayers.isEmpty {
            let minBet = sortedPlayers.first!.currentBet
            var potAmount = 0

            for player in players {
                if remainingPlayers.contains(player.id) {
                    potAmount += min(player.currentBet - currentBetLevel, minBet - currentBetLevel)
                }
            }

            if potAmount > 0 {
                sidePots.append(potAmount)
            }

            currentBetLevel = minBet
            sortedPlayers.removeAll { $0.currentBet == minBet }
        }

        return sidePots
    }

    // MARK: - Valid Actions

    struct ValidActions {
        let canFold: Bool
        let canCheck: Bool
        let canCall: Bool
        let callAmount: Int
        let canBet: Bool
        let betAmount: Int
        let canRaise: Bool
        let minRaise: Int
        let canAllIn: Bool
        let allInAmount: Int
    }

    func getValidActions(
        for player: Player,
        highestBet: Int,
        lastRaiseAmount: Int,
        phase: GamePhase,
        minBet: Int,
        sbAmount: Int,
        bbAmount: Int,
        isFirstBettor: Bool
    ) -> ValidActions {
        let playerBet = player.currentBet
        let amountToCall = highestBet - playerBet


        // 强制all-in规则（仅preflop阶段适用）：
        // - SB位置：剩余积分 < 小底分金额时，必须全下，不能弃牌
        // - BB位置：剩余积分 < 大底分金额时，必须全下，不能弃牌
        // - flop/turn/river阶段：不适用此规则，玩家可正常弃牌
        let isShortStackedBlind = phase == .preflop && ((player.position == .sb && player.chips < sbAmount) || (player.position == .bb && player.chips < bbAmount))

        // canFold: 只要不是短积分底分强制all-in，随时可以弃牌（即使可以免费过牌）
        let canFold = !isShortStackedBlind
        let canCheck = amountToCall == 0
        // canCall: 能付得起完整跟注金额；付不起只能all-in
        let canCall = amountToCall > 0 && amountToCall <= player.chips

        let minRaiseAmount: Int
        if isFirstBettor || highestBet == 0 {
            minRaiseAmount = minBet
        } else {
            minRaiseAmount = highestBet + lastRaiseAmount
        }

        let canBet = isFirstBettor && amountToCall == 0 && minBet <= player.chips
        
        let isPreflopBlindWithNoRaise = phase == .preflop && amountToCall == 0 && !isFirstBettor
        // minRaiseAmount is the total amount that should be committed, but player.chips is the *remaining* chips.
        // Therefore, player needs to be able to afford (minRaiseAmount - player.currentBet) from their remaining chips.
        let amountNeededToRaise = minRaiseAmount - player.currentBet
        let canRaise = !isFirstBettor && (amountToCall > 0 || isPreflopBlindWithNoRaise) && amountNeededToRaise <= player.chips
        
        let canAllIn = player.chips > 0

        return ValidActions(
            canFold: canFold,
            canCheck: canCheck,
            canCall: canCall,
            callAmount: min(amountToCall, player.chips),
            canBet: canBet,
            betAmount: min(minBet, player.chips),
            canRaise: canRaise,
            minRaise: min(minRaiseAmount, player.chips + player.currentBet),
            canAllIn: canAllIn,
            allInAmount: player.chips
        )
    }

    // MARK: - Process Action

    struct ActionResult {
        let action: PlayerAction
        let amount: Int
        let success: Bool
    }

    func processAction(
        action: PlayerAction,
        for player: inout Player,
        gameState: inout GameState
    ) -> ActionResult {
        let highestBet = gameState.players.map { $0.currentBet }.max() ?? 0
        let validActions = getValidActions(
            for: player,
            highestBet: highestBet,
            lastRaiseAmount: gameState.lastRaiseAmount,
            phase: gameState.phase,
            minBet: gameState.bbAmount,
            sbAmount: gameState.sbAmount,
            bbAmount: gameState.bbAmount,
            isFirstBettor: highestBet == 0  // Same logic as AIAgent
        )

        switch action {
        case .fold:
            // 积分不够跟注时不能弃牌，只能all-in
            if !validActions.canFold {
                return ActionResult(action: action, amount: 0, success: false)
            }
            player.isFolded = true
            return ActionResult(action: action, amount: 0, success: true)

        case .check:
            if validActions.canCheck {
                return ActionResult(action: action, amount: 0, success: true)
            }
            return ActionResult(action: action, amount: 0, success: false)

        case .call(let amount):
            if !validActions.canCall {
                return ActionResult(action: action, amount: 0, success: false)
            }
            let callAmount = min(amount, player.chips)
            if callAmount <= 0 {
                return ActionResult(action: action, amount: 0, success: false)
            }
            player.chips -= callAmount
            player.currentBet += callAmount
            player.totalInvested += callAmount
            if player.chips == 0 {
                player.isAllIn = true
            }
            gameState.pot += callAmount
            return ActionResult(action: action, amount: callAmount, success: true)

        case .bet(let amount):
            if !validActions.canBet {
                return ActionResult(action: action, amount: 0, success: false)
            }
            let betAmount = min(amount, player.chips)
            if betAmount <= 0 {
                return ActionResult(action: action, amount: 0, success: false)
            }
            player.chips -= betAmount
            player.currentBet += betAmount
            player.totalInvested += betAmount
            if player.chips == 0 {
                player.isAllIn = true
            }
            gameState.pot += betAmount
            if player.currentBet > highestBet {
                gameState.lastRaiseAmount = player.currentBet - highestBet
            }
            return ActionResult(action: action, amount: betAmount, success: true)

        case .raise(let amount):
            if !validActions.canRaise {
                return ActionResult(action: action, amount: 0, success: false)
            }
            
            let totalNeeded = amount
            if player.chips + player.currentBet < totalNeeded {
                return ActionResult(action: action, amount: 0, success: false)
            }
            
            let additionalAmount = totalNeeded - player.currentBet
            if additionalAmount <= 0 || player.chips < additionalAmount {
                return ActionResult(action: action, amount: 0, success: false)
            }
            
            player.chips -= additionalAmount
            player.currentBet += additionalAmount
            player.totalInvested += additionalAmount
            if player.chips == 0 {
                player.isAllIn = true
            }
            gameState.pot += additionalAmount
            
            // Calculate actual raise difference above the previous highest bet
            let currentRaiseDiff = player.currentBet - highestBet
            if currentRaiseDiff > 0 {
                // We only update lastRaiseAmount if this is a valid new raise size
                if currentRaiseDiff > gameState.lastRaiseAmount {
                    gameState.lastRaiseAmount = currentRaiseDiff
                } else if highestBet == 0 {
                    // Special case for the first bet in a round
                    gameState.lastRaiseAmount = currentRaiseDiff
                }
            }
            
            return ActionResult(action: action, amount: additionalAmount, success: true)

        case .allIn(let amount):
            if !validActions.canAllIn {
                return ActionResult(action: action, amount: 0, success: false)
            }
            
            let allInAmount = min(amount, player.chips)
            if allInAmount <= 0 {
                return ActionResult(action: action, amount: 0, success: false)
            }
            
            player.chips -= allInAmount
            player.currentBet += allInAmount
            player.totalInvested += allInAmount
            player.isAllIn = true
            gameState.pot += allInAmount
            if player.currentBet > highestBet {
                let raiseDiff = player.currentBet - highestBet
                if raiseDiff >= gameState.lastRaiseAmount {
                    gameState.lastRaiseAmount = raiseDiff
                }
            }
            return ActionResult(action: action, amount: allInAmount, success: true)
        }
    }

    // MARK: - Betting Round Complete

    // 追踪本轮中当前最高投入（用于检测加注）
    private var roundHighestBet: Int = 0
    // 追踪每个玩家是否已在当前投入轮中完成过行动（加注后重置为false）
    private var hasActedThisRound: Set<UUID> = []

    func isBettingRoundComplete(players: [Player], highestBet: Int, currentPlayerIndex: Int) -> Bool {
        let activePlayers = players.filter { $0.isActive && !$0.isFolded && !$0.isAllIn }

        if activePlayers.isEmpty {
            resetBettingRoundTracking()
            return true
        }

        if activePlayers.count == 1 {
            let onlyPlayer = activePlayers[0]
            if highestBet == 0 || onlyPlayer.currentBet == highestBet {
                resetBettingRoundTracking()
                return true
            }
            return false
        }

        // 无人投入时（highestBet == 0）：所有活跃玩家按顺序过牌即可
        if highestBet == 0 {
            if roundHighestBet > 0 {
                // 如果 roundHighestBet 之前有值，说明进入了新的投入圈（如发牌后），需要重置追踪
                resetBettingRoundTracking()
            }
            if hasActedThisRound.isEmpty {
            }

            // 当前玩家已过牌
            if currentPlayerIndex < players.count {
                hasActedThisRound.insert(players[currentPlayerIndex].id)
            }

            let allActed = activePlayers.allSatisfy { hasActedThisRound.contains($0.id) }
            if allActed {
                resetBettingRoundTracking()
                return true
            }
            return false
        }

        // 有投入时（highestBet > 0）
        // 初始化 roundHighestBet（当没有人初始化过时）
        if roundHighestBet == 0 {
            roundHighestBet = highestBet
            hasActedThisRound.removeAll()
            
            // 不能盲目把所有 currentBet == highestBet 的人都算作已行动，
            // 因为 preflop 时大底分的 currentBet 就是 highestBet，但他还没行动！
            // 只有当前真正执行动作的玩家才算已行动。
            if currentPlayerIndex < players.count {
                hasActedThisRound.insert(players[currentPlayerIndex].id)
            }
        }

        // --- 核心修复 ---
        // 在 GameManager 调用此方法时，其实是想检查整个牌局状态
        // 1. 如果有人加注了（currentBet > roundHighestBet），更新 roundHighestBet 并重置所有人的行动状态
        if highestBet > roundHighestBet {
            roundHighestBet = highestBet
            hasActedThisRound.removeAll()
            // 将当前具有最高投入的玩家标记为已行动
            if let p = players.first(where: { $0.currentBet == highestBet }) {
                hasActedThisRound.insert(p.id) // 加注者视为已行动
            }
        }
        
        // 2. 特殊处理：如果是外层刚发生过行动传进来的 currentPlayerIndex，
        // 说明这个人刚刚做出了行动（跟注/过牌/加注），那么他一定被视为已行动（只要他当前的 currentBet 匹配了 highestBet）。
        // 这解决了“当我是最后一个行动并选择跟注时，虽然满足了匹配，但由于 currentPlayerIndex 未被纳入而未触发结束”的问题。
        // 同时删除了盲目循环遍历并把所有 currentBet == highestBet 的玩家标记为已行动的逻辑，避免把还没行动的大底分直接标记跳过。
        if currentPlayerIndex < players.count {
            let actualCurrentPlayerId = players[currentPlayerIndex].id
            // 只要他还在活跃状态，且他的投入确实匹配了当前的最高投入，就强制记录为已行动
            if let p = activePlayers.first(where: { $0.id == actualCurrentPlayerId }) {
                if p.currentBet == highestBet {
                    hasActedThisRound.insert(p.id)
                }
            }
        }

        // 打印所有人的状态
        for player in activePlayers {
            let hasActed = hasActedThisRound.contains(player.id)
            let betMatched = player.currentBet == highestBet
        }

        // 投入轮结束条件：
        // 1. 所有活跃玩家的 currentBet 都等于 highestBet（所有人都匹配了当前最高投入）
        // 2. 所有活跃玩家都已在本轮行动过（hasActedThisRound 包含所有人）
        // 3. 特殊情况：如果是大盲位，且没人加注（highestBet == bbAmount），大盲需要有一次过牌（或加注）的机会
        //    因此需要确保大底分被正确记录到 hasActedThisRound 中
        let allActed = activePlayers.allSatisfy { hasActedThisRound.contains($0.id) }
        let allMatched = activePlayers.allSatisfy { $0.currentBet == highestBet }

        if allActed && allMatched {
            // 最后确认一遍：是不是所有人都匹配了 roundHighestBet
            if roundHighestBet > 0 && activePlayers.contains(where: { $0.currentBet < roundHighestBet }) {
                return false
            }
            
            resetBettingRoundTracking()
            return true
        }

        return false
    }

    func resetBettingRoundTracking() {
        roundHighestBet = 0
        hasActedThisRound.removeAll()
    }

    // MARK: - Distribute Pot

    struct PotDistribution {
        let playerId: UUID
        let amount: Int
    }

    struct PotLayer {
        let amount: Int
        let eligiblePlayerIds: [UUID]
    }

    func calculatePotLayers(players: [Player]) -> [PotLayer] {
        let contributors = players.filter { $0.totalInvested > 0 }
        let levels = Array(Set(contributors.map { $0.totalInvested })).sorted()
        guard !levels.isEmpty else { return [] }

        let seatById = Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0.seatId) })

        var layers: [PotLayer] = []
        var previous = 0

        for level in levels {
            let layerContributors = contributors.filter { $0.totalInvested >= level }
            let amount = (level - previous) * layerContributors.count
            if amount > 0 {
                let eligible = layerContributors
                    .filter { !$0.isFolded && $0.holeCards != nil }
                    .map { $0.id }
                    .sorted { (seatById[$0] ?? 0) < (seatById[$1] ?? 0) }
                layers.append(PotLayer(amount: amount, eligiblePlayerIds: eligible))
            }
            previous = level
        }

        var merged: [PotLayer] = []
        for layer in layers {
            if let last = merged.last, last.eligiblePlayerIds == layer.eligiblePlayerIds {
                merged[merged.count - 1] = PotLayer(amount: last.amount + layer.amount, eligiblePlayerIds: last.eligiblePlayerIds)
            } else {
                merged.append(layer)
            }
        }

        return merged
    }

    func distributePot(
        players: [Player],
        communityCards: [Card],
        evaluator: HandEvaluator
    ) -> (distributions: [PotDistribution], layers: [(layer: PotLayer, winners: [UUID])]) {
        let layers = calculatePotLayers(players: players)
        guard !layers.isEmpty else { return ([], []) }

        var payoutsByPlayer: [UUID: Int] = [:]
        var layerWinners: [(layer: PotLayer, winners: [UUID])] = []

        for layer in layers {
            let eligiblePlayers = players.filter { layer.eligiblePlayerIds.contains($0.id) }
            let winners = evaluator.determineWinner(players: eligiblePlayers, communityCards: communityCards)
            layerWinners.append((layer: layer, winners: winners))

            guard !winners.isEmpty else { continue }

            let perWinner = layer.amount / winners.count
            let remainder = layer.amount % winners.count
            let orderedWinners = winners.sorted { lhs, rhs in
                let lSeat = eligiblePlayers.first(where: { $0.id == lhs })?.seatId ?? 0
                let rSeat = eligiblePlayers.first(where: { $0.id == rhs })?.seatId ?? 0
                return lSeat < rSeat
            }

            for (idx, winnerId) in orderedWinners.enumerated() {
                let extra = idx < remainder ? 1 : 0
                payoutsByPlayer[winnerId, default: 0] += perWinner + extra
            }
        }

        let distributions = payoutsByPlayer.map { PotDistribution(playerId: $0.key, amount: $0.value) }
        return (distributions, layerWinners)
    }
}
