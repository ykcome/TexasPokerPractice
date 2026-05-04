import SwiftUI

// MARK: - Game View

struct GameView: View {
    @ObservedObject var gameManager: GameManager
    @StateObject private var economyManager = EconomyManager.shared
    @StateObject private var profileManager = PlayerProfileManager.shared
    @State private var betSliderAmount: Double = 0
    @State private var raiseSliderAmount: Double = 0
    @State private var isShowingProfile: Bool = false
    @State private var showingCoachComment: String? = nil
    
    private var isPostGame: Bool {
        gameManager.tournamentState.isFinished
    }

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            ZStack {
                // Background
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                if isLandscape {
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            // Main Game Area
                            VStack(spacing: 0) {
                                tournamentInfoBar(isLandscape: true)
                                Spacer(minLength: 2)
                                communityCardsView(isLandscape: true)
                                potView(isLandscape: true)
                                Spacer(minLength: 2)
                                
                                // 使 AI 玩家卡片靠上，不要被底部状态栏挡住
                                playerSeatsView(isLandscape: true)
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .frame(width: geometry.size.width * 0.70)
                            .clipped() // 确保内容不溢出到右侧面板
                            
                            // Right Side Panel
                            VStack(spacing: 0) {
                                Spacer()
                                
                                seatView(seatId: 4, isLandscape: true)
                                
                                Spacer()
                                    
                                actionButtonsView(isLandscape: true)
                                    .padding(.horizontal, 6)
                                
                                Spacer(minLength: 5)
                            }
                            .frame(width: geometry.size.width * 0.30)
                            .background(Color(UIColor.secondarySystemGroupedBackground).ignoresSafeArea())
                        }
                        
                        gameMessageView
                    }
                } else {
                    VStack(spacing: 0) {
                        // Top bar with tournament info
                        tournamentInfoBar(isLandscape: false)

                        Spacer(minLength: 10)

                        // Community cards
                        communityCardsView(isLandscape: false)

                        // Pot display
                        potView(isLandscape: false)

                        Spacer(minLength: 10)

                        // Player seats
                        playerSeatsView(isLandscape: false)

                        Spacer(minLength: 10)

                        // Action buttons
                        actionButtonsView(isLandscape: false)
                            .padding(.horizontal)
                            .padding(.bottom, 20)

                        // Game message
                        gameMessageView
                            .padding(.bottom, 10)
                            
                        // Player Profile Button
                        if !isHumanActing && !isPostGame {
                            Spacer().frame(height: 16)
                        } else {
                            Spacer().frame(height: 16)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .sheet(isPresented: $isShowingProfile) {
            PlayerProfileView(selectedTab: .constant(1), gameManager: gameManager)
        }
        .alert(String(localized: "教练点评"), isPresented: Binding<Bool>(
            get: { gameManager.practiceFeedback != nil },
            set: { if !$0 { gameManager.practiceFeedback = nil } }
        ), presenting: gameManager.practiceFeedback) { _ in
            Button(String(localized: "明白"), role: .cancel) {
                gameManager.practiceFeedback = nil
            }
        } message: { feedback in
            Text(feedback)
        }
        .alert(String(localized: "本手牌点评"), isPresented: Binding<Bool>(
            get: { showingCoachComment != nil },
            set: { if !$0 { showingCoachComment = nil } }
        ), presenting: showingCoachComment) { _ in
            Button(String(localized: "明白"), role: .cancel) {
                showingCoachComment = nil
            }
        } message: { feedback in
            Text(feedback)
        }
        
    }

    // MARK: - Tournament Info Bar

    private func tournamentInfoBar(isLandscape: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: isLandscape ? 0 : 2) {
                Text(String(localized: String.LocalizationValue(gameManager.currentMode.rawValue)))
                    .font(isLandscape ? .subheadline : .headline)
                    .foregroundColor(.primary)

                Text(String(localized: "级别: \(gameManager.tournamentState.currentLevel)"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Text("\(String(localized: "体力值")): \(profileManager.profile.stamina)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        economyManager.presentEarnCoins()
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }

            Spacer()

            VStack(alignment: .center, spacing: isLandscape ? 0 : 2) {
                Text(String(localized: "小底分/大底分"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\(gameManager.tournamentState.currentBlindLevel.sb)/\(gameManager.tournamentState.currentBlindLevel.bb)")
                            .font(isLandscape ? .headline : .title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: isLandscape ? 0 : 2) {
                Text(String(localized: "前分"))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\(gameManager.tournamentState.currentBlindLevel.ante)")
                    .font(isLandscape ? .headline : .title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, isLandscape ? 4 : 16)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(Color(UIColor.secondarySystemGroupedBackground))
          .shadow(color: Color.primary.opacity(0.05), radius: 3, x: 0, y: 2)
    }

    // MARK: - Community Cards

    private func communityCardsView(isLandscape: Bool) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { index in
                if index < gameManager.gameState.communityCards.count {
                    CardView(card: gameManager.gameState.communityCards[index])
                        .transition(.scale.combined(with: .opacity))
                } else {
                    CardBackView()
                }
            }
        }
        .scaleEffect(isLandscape ? 0.75 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: gameManager.gameState.communityCards.count)
        .padding(.vertical, isLandscape ? 0 : 12)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Pot View

    private func potView(isLandscape: Bool) -> some View {
        HStack(spacing: 6) {
            Text(String(localized: "总分"))
                .font(isLandscape ? .system(size: 10) : .caption)
                .foregroundColor(.secondary)

            Text("\(gameManager.gameState.pot)")
                .font(isLandscape ? .title3 : .title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, isLandscape ? 12 : 16)
        .padding(.vertical, isLandscape ? 4 : 6)
        .background(Color(UIColor.secondarySystemGroupedBackground))
            .shadow(color: Color.primary.opacity(0.05), radius: 3, x: 0, y: 2)
        .cornerRadius(isLandscape ? 10 : 15)
        .overlay(
            RoundedRectangle(cornerRadius: isLandscape ? 10 : 15)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .padding(.bottom, isLandscape ? 0 : 5)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Player Seats

    /// 6人桌顺时针布局：
    /// - 下排(左→右): Button(0) --- SB(1) --- BB(2)
    /// - 上排(左→右): CO(5) --- MP(4) --- UTG(3)
    ///
    /// 完整顺时针环: Button(0) → SB(1) → BB(2) → UTG(3) → MP(4) → CO(5) → Button(0)
    @ViewBuilder
    private func playerSeatsView(isLandscape: Bool) -> some View {
        if isLandscape {
            HStack(spacing: 20) {
                seatView(seatId: 5, isLandscape: true)
                seatView(seatId: 2, isLandscape: true)
                seatView(seatId: 1, isLandscape: true)
                seatView(seatId: 0, isLandscape: true)
                seatView(seatId: 3, isLandscape: true)
                // 人类玩家 (seatId: 4) 在横屏时被挪到了右侧面板
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.bottom, 20) // 确保不会贴底
        } else {
            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    Spacer()
                    seatView(seatId: 2, isLandscape: false)
                    Spacer()
                    seatView(seatId: 1, isLandscape: false)
                    Spacer()
                    seatView(seatId: 0, isLandscape: false)
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 6)

                HStack(spacing: 8) {
                    Spacer()
                    seatView(seatId: 5, isLandscape: false)
                    Spacer()
                    seatView(seatId: 4, isLandscape: false) // Hero
                    Spacer()
                    seatView(seatId: 3, isLandscape: false)
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 6)
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func displayPlayerForSeat(seatId: Int) -> Player? {
        var player = gameManager.tournamentState.players.first(where: { $0.seatId == seatId })
        guard var p = player else { return nil }

        if let gPlayer = gameManager.gameState.players.first(where: { $0.seatId == seatId }) {
            p.holeCards = gPlayer.holeCards
            p.currentBet = gPlayer.currentBet
            p.isFolded = gPlayer.isFolded
            p.isAllIn = gPlayer.isAllIn
            p.isActive = gPlayer.isActive
            p.isEliminated = gPlayer.isEliminated
            p.showHoleCards = gPlayer.showHoleCards
            player = p
        }

        return player
    }

    @ViewBuilder
    private func seatView(seatId: Int, isLandscape: Bool) -> some View {
        let slotWidth: CGFloat = isLandscape ? (seatId == 4 ? 140 : 96) : (seatId == 4 ? 150 : 92)
        let slotHeight: CGFloat = isLandscape ? (seatId == 4 ? 180 : 130) : (seatId == 4 ? 190 : 150)
        
        if let player = displayPlayerForSeat(seatId: seatId) {
            let isDealer = (gameManager.tournamentState.buttonSeat == seatId) && !player.isEliminated && player.chips > 0
            let isCurrent = gameManager.gameState.currentPlayer?.seatId == seatId
            let isHero = seatId == 4
            let lastAct = gameManager.gameState.actionHistory.last(where: { $0.playerId == player.id && $0.phase == gameManager.gameState.phase })?.action
            let content = PlayerSeatView(
                player: player,
                isCurrentPlayer: isCurrent,
                isDealer: isDealer,
                revealHoleCards: player.isHuman || player.showHoleCards || gameManager.gameState.phase == .showdown || gameManager.gameState.phase == .finished || gameManager.gameState.isAllInRunout,
                isHero: isHero,
                isLandscape: isLandscape,
                lastAction: lastAct
            )
            .frame(width: slotWidth, height: slotHeight)
            
            if player.isHuman {
                Button(action: {
                    isShowingProfile = true
                }) {
                    content
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                content
            }
        } else {
            Color.clear
                .frame(width: slotWidth, height: slotHeight)
        }
    }

    // MARK: - Action Buttons

    private var isHumanActing: Bool {
        let humanOut = gameManager.tournamentState.players.first(where: { $0.isHuman })?.isEliminated ?? false
        if gameManager.isHandFinished || gameManager.tournamentState.isFinished || humanOut || gameManager.gameState.phase == .showdown || gameManager.gameState.phase == .finished {
            return false
        }
        if let player = gameManager.gameState.currentPlayer, player.isHuman, !player.isFolded, !player.isAllIn {
            return true
        }
        return false
    }

    private var activePlayersCount: Int {
        gameManager.tournamentState.players.filter { $0.isActive && !$0.isEliminated }.count
    }

    private func actionButtonsView(isLandscape: Bool) -> some View {
        Group {
            let humanOut = gameManager.tournamentState.players.first(where: { $0.isHuman })?.isEliminated ?? false
            if gameManager.isHandFinished || gameManager.tournamentState.isFinished || humanOut || gameManager.gameState.phase == .showdown || gameManager.gameState.phase == .finished {
                EmptyView()
            } else if let player = gameManager.gameState.currentPlayer, player.isHuman, !player.isFolded, !player.isAllIn {
                let highestBet = gameManager.gameState.players.map { $0.currentBet }.max() ?? 0

                let validActions = BettingManager.shared.getValidActions(
                    for: player,
                    highestBet: highestBet,
                    lastRaiseAmount: gameManager.gameState.lastRaiseAmount,
                    phase: gameManager.gameState.phase,
                    minBet: gameManager.gameState.bbAmount,
                    sbAmount: gameManager.gameState.sbAmount,
                    bbAmount: gameManager.gameState.bbAmount,
                    isFirstBettor: highestBet == 0
                )

                let outerSpacing: CGFloat = isLandscape ? 6 : 8
                let innerSpacing: CGFloat = isLandscape ? 6 : 8
                let rowSpacing: CGFloat = isLandscape ? 6 : 8
                let labelFontSize: CGFloat = isLandscape ? 11 : 12
                let valueFontSize: CGFloat = isLandscape ? 10 : 11
                let sliderHeight: CGFloat = isLandscape ? 14 : 18

                VStack(spacing: outerSpacing) {
                    VStack(spacing: innerSpacing) {
                        HStack(spacing: 6) {
                            if gameManager.currentMode == .pushFold {
                                ActionButton(title: String(localized: "弃牌"), color: Color(UIColor.tertiarySystemGroupedBackground), foregroundColor: .primary) {
                                    gameManager.playerAction(.fold, forPlayerId: player.id)
                                }
                                .disabled(!validActions.canFold)
                                
                                if validActions.canAllIn {
                                    ActionButton(title: String(localized: "全押 \(validActions.allInAmount)"), color: .indigo) {
                                        gameManager.playerAction(.allIn(amount: validActions.allInAmount), forPlayerId: player.id)
                                    }
                                }
                            } else {
                                ActionButton(title: String(localized: "弃牌"), color: Color(UIColor.tertiarySystemGroupedBackground), foregroundColor: .primary) {
                                    gameManager.playerAction(.fold, forPlayerId: player.id)
                                }
                                .disabled(!validActions.canFold)
                                
                                if validActions.canCheck {
                                    ActionButton(title: String(localized: "过牌"), color: Color(UIColor.tertiarySystemGroupedBackground), foregroundColor: .primary) {
                                        gameManager.playerAction(.check, forPlayerId: player.id)
                                    }
                                } else if validActions.canCall {
                                    ActionButton(title: String(localized: "跟注 \(validActions.callAmount)"), color: .blue) {
                                        gameManager.playerAction(.call(amount: validActions.callAmount), forPlayerId: player.id)
                                    }
                                    .disabled(!validActions.canCall)
                                }
                                
                                if validActions.canAllIn {
                                    ActionButton(title: String(localized: "全押 \(validActions.allInAmount)"), color: .indigo) {
                                        gameManager.playerAction(.allIn(amount: validActions.allInAmount), forPlayerId: player.id)
                                    }
                                }
                            }
                        }

                        if validActions.canBet && gameManager.currentMode != .pushFold {
                            let minAmount = validActions.betAmount
                            let maxAmount = max(validActions.betAmount, validActions.allInAmount)
                            let binding = Binding<Double>(
                                get: {
                                    let v = betSliderAmount
                                    if v < Double(minAmount) || v > Double(maxAmount) {
                                        return Double(minAmount)
                                    }
                                    return v
                                },
                                set: { betSliderAmount = $0 }
                            )
                            let current = Int(binding.wrappedValue)
                            let presets = betPresets(min: minAmount, maxAmount: maxAmount, pot: gameManager.gameState.pot)

                            VStack(spacing: innerSpacing) {
                                HStack(spacing: rowSpacing) {
                                    ForEach(presets, id: \.self) { amount in
                                        CompactActionButton(title: "\(amount)") {
                                            betSliderAmount = Double(amount)
                                            gameManager.playerAction(.bet(amount: amount), forPlayerId: player.id)
                                        }
                                    }
                                }

                                HStack(spacing: rowSpacing) {
                                    Text(String(localized: "下注"))
                                        .font(.system(size: labelFontSize, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .frame(width: 34, alignment: .leading)

                                    ZStack {
                                        if maxAmount > minAmount {
                                            let safeStep = min(Double(maxAmount - minAmount), max(1.0, Double(gameManager.gameState.bbAmount)))
                                            
                                            Slider(
                                                 value: binding,
                                                 in: Double(minAmount)...Double(maxAmount),
                                                 step: safeStep > 0 ? safeStep : 1.0
                                             )
                                             .accentColor(.indigo)
                                             .controlSize(.mini)
                                             .frame(height: sliderHeight)
                                        }
                                        Text("\(current)")
                                            .font(.system(size: valueFontSize, weight: .semibold))
                                            .monospacedDigit()
                                            .foregroundColor(.primary)
                                            .allowsHitTesting(false)
                                    }
                                    .frame(maxWidth: .infinity)

                                    ActionButton(title: String(localized: "确认下注"), color: .indigo) {
                                        gameManager.playerAction(.bet(amount: current), forPlayerId: player.id)
                                    }
                                }
                            }
                        } else if validActions.canRaise && gameManager.currentMode != .pushFold {
                            let minAmount = validActions.minRaise
                            let maxAmount = max(validActions.minRaise, validActions.allInAmount)
                            let binding = Binding<Double>(
                                get: {
                                    let v = raiseSliderAmount
                                    if v < Double(minAmount) || v > Double(maxAmount) {
                                        return Double(minAmount)
                                    }
                                    return v
                                },
                                set: { raiseSliderAmount = $0 }
                            )
                            let current = Int(binding.wrappedValue)
                            let presets = raisePresets(min: minAmount, maxAmount: maxAmount)

                            VStack(spacing: innerSpacing) {
                                HStack(spacing: rowSpacing) {
                                    ForEach(presets, id: \.self) { amount in
                                        CompactActionButton(title: "\(amount)") {
                                            raiseSliderAmount = Double(amount)
                                            gameManager.playerAction(.raise(amount: amount), forPlayerId: player.id)
                                        }
                                    }
                                }

                                HStack(spacing: rowSpacing) {
                                    Text(String(localized: "加注"))
                                        .font(.system(size: labelFontSize, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .frame(width: 34, alignment: .leading)

                                    ZStack {
                                        if maxAmount > minAmount {
                                            // The distance between minAmount and maxAmount MUST be a multiple of the step value for Slider
                                            // Ensure step is not larger than the range itself to prevent "max stride must be positive" crashes
                                            let safeStep = min(Double(maxAmount - minAmount), max(1.0, Double(gameManager.gameState.bbAmount)))
                                            
                                            Slider(
                                                value: binding,
                                                in: Double(minAmount)...Double(maxAmount),
                                                step: safeStep > 0 ? safeStep : 1.0
                                            )
                                            .accentColor(.indigo)
                                            .controlSize(.mini)
                                            .frame(height: sliderHeight)
                                        }
                                        Text("\(current)")
                                            .font(.system(size: valueFontSize, weight: .semibold))
                                            .monospacedDigit()
                                            .foregroundColor(.primary)
                                            .allowsHitTesting(false)
                                    }
                                    .frame(maxWidth: .infinity)

                                    ActionButton(title: String(localized: "确认加注"), color: .indigo) {
                                        gameManager.playerAction(.raise(amount: current), forPlayerId: player.id)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, isLandscape ? 4 : 8)
                    .padding(.horizontal, isLandscape ? 4 : 6)
                }
                .padding(.horizontal, 6)
                .padding(.bottom, isLandscape ? 4 : 6)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(UIColor.separator).opacity(0.1), lineWidth: 1)
                )
            } else {
                EmptyView()
            }
        }
    }

    private func raisePresets(min: Int, maxAmount: Int) -> [Int] {
        var values: [Int] = [min]
        let x2 = min * 2
        if x2 > min && x2 <= maxAmount { values.append(x2) }
        let x3 = min * 3
        if x3 > min && x3 <= maxAmount { values.append(x3) }
        let x4 = min * 4
        if x4 > min && x4 <= maxAmount { values.append(x4) }
        return Array(values.prefix(4))
    }

    private func betPresets(min: Int, maxAmount: Int, pot: Int) -> [Int] {
        var values: [Int] = [min]
        let halfPot = Swift.max(min, pot / 2)
        if halfPot > min && halfPot <= maxAmount { values.append(halfPot) }
        let fullPot = Swift.max(min, pot)
        if fullPot > min && fullPot <= maxAmount { values.append(fullPot) }
        return Array(values.prefix(3))
    }


    // MARK: - Game Message

    private var gameMessageView: some View {
        Group {
            let isPostGame = gameManager.tournamentState.isFinished || (gameManager.tournamentState.players.first(where: { $0.isHuman })?.isEliminated ?? false) || (gameManager.tournamentState.players.filter { !$0.isEliminated }.count <= 1)
            if isHumanActing && !isPostGame && !gameManager.isHandFinished {
                EmptyView()
            } else {
                HStack(spacing: 16) {
                    Text(gameManager.gameMessage)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    
                    Spacer()
                    
                    if isPostGame {
                            HStack(spacing: 16) {
                                // Coach Button
                                Button(action: {
                                    if let feedback = gameManager.lastPracticeFeedback {
                                        showingCoachComment = feedback
                                    } else {
                                        showingCoachComment = HandHistoryExporter.shared.getCurrentHandCoachComments()
                                    }
                                }) {
                                    Image(systemName: "lightbulb.fill")
                                        .font(.title2)
                                        .foregroundColor(.orange)
                                        .padding(12)
                                        .background(Color.orange.opacity(0.1))
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.orange.opacity(0.5), lineWidth: 1))
                                }
                                
                                // Replay Button
                                Button(action: {
                                    gameManager.replayCurrentHand()
                                }) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.title2)
                                        .foregroundColor(.primary)
                                        .padding(12)
                                        .background(Color.primary.opacity(0.1))
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 1))
                                }
                                
                                Button(action: {
                                    if gameManager.currentMode == .hu {
                                        economyManager.startPractice(isFree: true) {
                                            gameManager.startPracticeMode(.hu)
                                        }
                                    } else {
                                        economyManager.restartTournament(gameManager: gameManager)
                                    }
                                }) {
                                    Image(systemName: "goforward")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                        .padding(12)
                                        .background(Color.blue.opacity(0.1))
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.blue.opacity(0.3), lineWidth: 1))
                                }
                            }
                        } else if gameManager.isHandFinished {
                        if activePlayersCount > 1 {
                            HStack(spacing: 16) {
                                // Coach Button
                                Button(action: {
                                    if let feedback = gameManager.lastPracticeFeedback {
                                        showingCoachComment = feedback
                                    } else {
                                        showingCoachComment = HandHistoryExporter.shared.getCurrentHandCoachComments()
                                    }
                                }) {
                                    Image(systemName: "lightbulb.fill")
                                        .font(.title2)
                                        .foregroundColor(.orange)
                                        .padding(12)
                                        .background(Color.orange.opacity(0.1))
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.orange.opacity(0.5), lineWidth: 1))
                                }
                                
                                // Replay Button
                                Button(action: {
                                    gameManager.replayCurrentHand()
                                }) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.title2)
                                        .foregroundColor(.primary)
                                        .padding(12)
                                        .background(Color.primary.opacity(0.1))
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 1))
                                }
                                
                                // Next Hand Button
                                let isLastHand = gameManager.isReplayingPlaylist && gameManager.currentReplayIndex == gameManager.replayPlaylist.count - 1
                                Button(action: {
                                    if gameManager.isReplayingPlaylist {
                                        gameManager.playNextInPlaylist()
                                    } else {
                                        gameManager.startNewHand()
                                    }
                                }) {
                                    Image(systemName: isLastHand ? "arrow.triangle.2.circlepath" : "forward.end.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .padding(12)
                                        .background(isLastHand ? Color.green.opacity(0.9) : Color.blue.opacity(0.9))
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(isLastHand ? Color.green.opacity(0.5) : Color.blue.opacity(0.5), lineWidth: 1))
                                }
                            }
                        }
                    } else if let humanPlayer = gameManager.gameState.players.first(where: { $0.isHuman }), humanPlayer.isFolded, activePlayersCount > 1, gameManager.currentMode != .hu {
                        Button(action: {
                            gameManager.fastForwardToEndOfHand()
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.orange.opacity(0.9))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.orange.opacity(0.5), lineWidth: 1))
                        }
                        .disabled(gameManager.isFastForwarding)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
                .layoutPriority(1) // Ensure it gets space
            }
        }
    }
}

// MARK: - Card View

struct CardView: View {
    let card: Card
    
    // 计算牌的颜色
    private var isRed: Bool {
        card.suit.color == "red"
    }
    
    var body: some View {
        ZStack {
            // 白色卡片背景
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 3)

            // 卡片内容
            VStack(spacing: 0) {
                // 左上角 - 数字和花色
                HStack(spacing: 1) {
                    Text(card.rank.symbol)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(isRed ? .red : .black)
                    Text(card.suit.symbol)
                        .font(.system(size: 12))
                        .foregroundColor(isRed ? .red : .black)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                // 中间 - 大花色
                Text(card.suit.symbol)
                    .font(.system(size: 28))
                    .foregroundColor(isRed ? .red : .black)
                
                Spacer()
                
                // 右下角 - 数字和花色 (翻转)
                HStack(spacing: 1) {
                    Text(card.suit.symbol)
                        .font(.system(size: 12))
                        .foregroundColor(isRed ? .red : .black)
                    Text(card.rank.symbol)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(isRed ? .red : .black)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(5)
        }
        .frame(width: 54, height: 75)
    }
}

struct CardBackView: View {
    var body: some View {
        ZStack {
            // 浅蓝色背景 - 作为卡牌主体
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.4, green: 0.6, blue: 0.9))
                .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
            
            // 内部纹理图案 - 与背景底色一致的轻微渐变或边框
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                .padding(4)
            
            // 中心装饰 - 直接展示专为牌背设计的 Logo (背景色已替换为浅蓝色)
            Image("CardBackLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
        }
        .frame(width: 54, height: 75)
    }
}

// MARK: - Player Seat View

struct PlayerSeatView: View {
    let player: Player
    let isCurrentPlayer: Bool
    let isDealer: Bool
    let revealHoleCards: Bool
    let isHero: Bool
    var isLandscape: Bool = false
    var lastAction: PlayerAction? = nil

    private func getActionText(player: Player, lastAction: PlayerAction?) -> String {
        if let lastAct = lastAction {
            switch lastAct {
            case .call: return String(localized: "跟注 \(player.currentBet)")
            case .raise: return String(localized: "加注 \(player.currentBet)")
            case .bet: return String(localized: "下注 \(player.currentBet)")
            case .allIn: return String(localized: "全押 \(player.currentBet)")
            default: return String(localized: "下注 \(player.currentBet)")
            }
        } else {
            if player.position == .sb {
                return String(localized: "SB \(player.currentBet)")
            } else if player.position == .bb {
                return String(localized: "BB \(player.currentBet)")
            } else {
                return String(localized: "下注 \(player.currentBet)")
            }
        }
    }

    private var positionLabel: String {
        switch player.position {
        case .button: return "D"
        case .sb: return "SB"
        case .bb: return "BB"
        case .utg: return "UTG"
        case .mp: return "MP"
        case .co: return "CO"
        }
    }

    private var positionColor: Color {
        switch player.position {
        case .button: return .blue
        case .sb: return .orange
        case .bb: return .yellow
        case .utg, .mp, .co: return .gray
        }
    }
    
    private var isEliminated: Bool {
        player.isEliminated
    }

    @ViewBuilder
    private var statusBadge: some View {
        if isEliminated {
            Text(String(localized: "OUT"))
                .font(.system(size: isHero ? 12 : (isLandscape ? 13 : 11), weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.gray)
                .cornerRadius(4)
        } else if player.isFolded {
            Text(String(localized: "弃牌"))
                .font(.system(size: isHero ? 12 : (isLandscape ? 13 : 11), weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.8))
                .cornerRadius(4)
        } else if player.isAllIn {
            Text(String(localized: "全押"))
                .font(.system(size: isHero ? 12 : (isLandscape ? 13 : 11), weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.indigo)
                .cornerRadius(4)
                .fixedSize()
        } else if player.currentBet > 0 {
            Text(getActionText(player: player, lastAction: lastAction))
                .font(.system(size: isHero ? 12 : (isLandscape ? 13 : 11), weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange)
                .cornerRadius(4)
                .fixedSize()
        } else if let lastAct = lastAction, case .check = lastAct {
            Text(String(localized: "过牌"))
                .font(.system(size: isHero ? 12 : (isLandscape ? 13 : 11), weight: .bold))
                .foregroundColor(.primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
        } else {
            Color.clear
                .frame(height: 18)
        }
    }

    var body: some View {
        let isAiRevealing = !isHero && revealHoleCards && !player.isFolded && player.holeCards != nil
        // 适当减小缩放比例以适应屏幕宽度
        let cardScale = isHero || isAiRevealing ? (isLandscape ? (isHero ? 1.0 : 0.9) : (isHero ? 1.0 : 0.8)) : (isLandscape ? 0.70 : 0.60)
        let cardsSpacing = isHero || isAiRevealing ? 6.0 : (isLandscape ? -8.0 : -6.0)
        // 缩小卡片的宽度，避免三列超出竖屏屏幕
        let slotWidth: CGFloat = isLandscape ? (isHero ? 140 : 104) : (isHero ? 150 : 106)
        let slotHeight: CGFloat = isLandscape ? (isHero ? 180 : 145) : (isHero ? 190 : 155)
        let panelWidth: CGFloat = slotWidth
        let panelPadding: CGFloat = isLandscape ? (isHero ? 12 : 6) : (isHero ? 12 : 6)
        let panelCornerRadius: CGFloat = isLandscape ? (isHero ? 14 : 10) : (isHero ? 14 : 10)

        ZStack(alignment: .topLeading) {
            VStack(spacing: isHero ? 10 : 8) {
                HStack(spacing: cardsSpacing) {
                    if let cards = player.holeCards, revealHoleCards, (isHero || !player.isFolded) {
                        ForEach(cards, id: \.self) { card in
                            CardView(card: card)
                                .scaleEffect(cardScale)
                        }
                    } else {
                        ForEach(0..<2, id: \.self) { _ in
                            CardBackView()
                                .scaleEffect(cardScale)
                        }
                    }
                }
                .zIndex(1) // Ensure cards can cover the card background if scaled up

                VStack(spacing: 4) {
                    Text(player.isHuman ? (PlayerProfileManager.shared.profile.customName ?? player.name) : player.name)
                        .font(.system(size: isHero ? 18 : (isLandscape ? 18 : 16), weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(positionLabel)
                        .font(.system(size: isHero ? 12 : 11, weight: .black, design: .rounded))
                        .foregroundColor(positionColor)

                    Text("\(player.chips)")
                        .font(.system(size: isHero ? 20 : (isLandscape ? 20 : 18), weight: .black, design: .rounded))
                        .foregroundColor(player.isHuman ? .green : .orange)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    statusBadge
                        .padding(.top, 2)
                }
                .zIndex(0)
            }
            .padding(panelPadding)
            .frame(width: panelWidth, height: slotHeight)
            .background(
                RoundedRectangle(cornerRadius: panelCornerRadius)
                    .fill(Color(UIColor.secondarySystemGroupedBackground).opacity(0.95))
                    .shadow(color: Color.black.opacity(0.12), radius: isHero ? 8 : 5, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: panelCornerRadius)
                            .strokeBorder(isCurrentPlayer ? Color.blue.opacity(0.8) : Color.gray.opacity(0.1), lineWidth: isCurrentPlayer ? 2.5 : 0.5)
                    )
            )

            if isDealer {
                    Text(String(localized: "D"))
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.blue)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    .offset(x: 6, y: -6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            
            if player.isHuman {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(2)
                    .background(Circle().fill(Color.blue.opacity(0.8)))
                    .offset(x: -6, y: 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .frame(width: slotWidth, height: slotHeight)
        .opacity(isEliminated ? 0.4 : 1.0)
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let title: String
    let color: Color
    var foregroundColor: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(foregroundColor)
                .frame(minWidth: 50, minHeight: 34)
                .padding(.horizontal, 6)
                .background(color)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                )
        }
    }
}

struct CompactActionButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, minHeight: 32)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
