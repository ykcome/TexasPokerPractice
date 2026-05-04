import SwiftUI

@MainActor
struct CoachCommentView: View {
    let action: HandAction
    let round: BettingRoundRecord
    let history: HandHistory
    let isHugeLoss: Bool
    @Binding var evaluatedTags: [String: CoachAdvice]
    
    // 我们将 showingCoachComment 移到了外部的列表中，改为使用回调，避免直接双向绑定导致更新冲突
    var onShowComment: (String) -> Void
    
    var body: some View {
        let customName = PlayerProfileManager.shared.profile.customName ?? "玩家"
        let isHuman = action.playerId == "human" || action.playerId == "HUMAN" || history.players.first(where: { $0.playerId == action.playerId })?.playerName == "玩家" || history.players.first(where: { $0.playerId == action.playerId })?.playerName == customName || history.players.first(where: { $0.playerId == action.playerId })?.isHuman == true
        
        if isHuman {
            let actionKey = "\(round.phase)_\(action.playerId)_\(action.action.rawValue)_\(action.amount)_\(action.totalInvested)"
            
            if let advice = action.coachAdvice, advice.tag != .none {
                Button(action: {
                    let localizedComment = CoachCommentary.getLocalizedComment(from: advice.comment)
                    onShowComment("[\(advice.tag.localizedName)]\n\(localizedComment)")
                }) {
                    let colorStr = CoachCommentary.getColor(for: advice.tag)
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(colorStr == "green" ? .green : (colorStr == "orange" ? .orange : (colorStr == "red" ? .red : .gray)))
                        .font(.headline)
                }
                .buttonStyle(.plain)
                .frame(width: 18, height: 18)
            } else if let advice = evaluatedTags[actionKey], advice.tag != .none {
                Button(action: {
                    let localizedComment = CoachCommentary.getLocalizedComment(from: advice.comment)
                    onShowComment("[\(advice.tag.localizedName)]\n\(localizedComment)")
                }) {
                    let colorStr = CoachCommentary.getColor(for: advice.tag)
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(colorStr == "green" ? .green : (colorStr == "orange" ? .orange : (colorStr == "red" ? .red : .gray)))
                        .font(.headline)
                }
                .buttonStyle(.plain)
                .frame(width: 18, height: 18)
            } else {
                Color.clear.frame(width: 0)
            }
        } else {
            Color.clear.frame(width: 0)
        }
    }
}





@MainActor
struct HandHistoryRowView: View {
        let history: HandHistory
        let profit: Int
        let onShowComment: (String) -> Void
        
        @State private var comments: [(tag: PlayTag, comment: String)] = []
        @State private var hasEvaluated: Bool = false
        
        private func formatHandTime(_ isoString: String) -> String {
            let fmt = ISO8601DateFormatter()
            if let date = fmt.date(from: isoString) {
                let out = DateFormatter()
                out.dateFormat = "yyyy-MM-dd HH:mm:ss"
                return out.string(from: date)
            }
            return isoString
        }
        
        var body: some View {
            NavigationLink(destination: HandHistoryDetailView(history: history)) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(formatHandTime(history.timestamp))
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button(action: {
                            var combined = ""
                            if let pf = history.practiceFeedback {
                                combined += "💡 \(String(localized: "教练点评"))\n\(String(localized: LocalizedStringResource(stringLiteral: pf)))\n\n"
                            }
                            
                            if !comments.isEmpty {
                                combined += comments.map { "[\($0.tag.localizedName)]\n\($0.comment)" }.joined(separator: "\n\n")
                            } else if combined.isEmpty {
                                combined = String(localized: "这手牌打得不错，没有什么明显的问题。")
                            } else {
                                // 如果只有 practiceFeedback，需要去掉尾部的换行
                                combined = combined.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                            
                            onShowComment(combined)
                        }) {
                            let colorStr = history.practiceFeedback != nil ? "orange" : (comments.isEmpty ? "gray" : CoachCommentary.getColor(for: comments.first!.tag))
                            
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(colorStr == "green" ? .green : (colorStr == "orange" ? .orange : (colorStr == "red" ? .red : .gray)))
                                .font(.subheadline)
                                .padding(.horizontal, 4)
                        }
                        .buttonStyle(.borderless)
                        
                        Text(String(localized: "L\(history.blindLevel) \(history.sbAmount)/\(history.bbAmount)"))
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.yellow)
                    }
                    
                    HStack {
                        let shortHandId = history.handId.count > 6 ? String(history.handId.suffix(6)) : history.handId
                        Text("Hand \(shortHandId)")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if profit != 0 {
                            Text(profit > 0 ? "+\(profit)" : "\(profit)")
                                .font(.caption.weight(.bold))
                                .foregroundColor(profit > 0 ? .green : .red)
                        } else {
                            Text("0")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .task {
                if !hasEvaluated {
                    let isHugeLoss = profit < -(history.bbAmount * 10) // 同步改成10
                    let calculatedComments: [(tag: PlayTag, comment: String)]
                    
                    var storedComments: [(tag: PlayTag, comment: String)] = []
                    for round in history.actionSequence {
                        for a in round.actions {
                            let customName = PlayerProfileManager.shared.profile.customName ?? "玩家"
                            let isHuman = a.playerId == "human" || a.playerId == "HUMAN" || history.players.first(where: { $0.playerId == a.playerId })?.playerName == "玩家" || history.players.first(where: { $0.playerId == a.playerId })?.playerName == customName || history.players.first(where: { $0.playerId == a.playerId })?.isHuman == true
                            
                            if isHuman {
                                if let advice = a.coachAdvice, advice.tag != .none {
                                    let localizedComment = CoachCommentary.getLocalizedComment(from: advice.comment)
                                    storedComments.append((tag: advice.tag, comment: localizedComment))
                                }
                            }
                        }
                    }
                    
                    if !storedComments.isEmpty {
                        calculatedComments = storedComments
                    } else {
                        let customName = PlayerProfileManager.shared.profile.customName ?? "玩家"
                        calculatedComments = await Task.detached(priority: .utility) { () -> [(tag: PlayTag, comment: String)] in
                            var results: [(tag: PlayTag, comment: String)] = []
                            for round in history.actionSequence {
                                for a in round.actions {
                                    let isHuman = a.playerId == "human" || a.playerId == "HUMAN" || history.players.first { $0.playerId == a.playerId }?.playerName == "玩家" || history.players.first { $0.playerId == a.playerId }?.playerName == customName || history.players.first { $0.playerId == a.playerId }?.isHuman == true
                                    
                                    if isHuman {
                                        if let advice = a.coachAdvice, advice.tag != .none {
                                            continue
                                        }
                                        let hole = history.players.first(where: { $0.playerId == a.playerId })?.holeCards ?? history.showdown?.first(where: { $0.playerId == a.playerId })?.holeCards
                                        let advice = PokerCoachEngine.shared.evaluateFromHistory(action: a, round: round, playerHoleCards: hole, isHugeLoss: isHugeLoss, history: history)
                                        if advice.tag != .none {
                                            let localizedComment = CoachCommentary.getLocalizedComment(from: advice.comment)
                                            results.append((tag: advice.tag, comment: localizedComment))
                                        }
                                    }
                                }
                            }
                            return results
                        }.value
                    }
                    
                    await MainActor.run {
                        self.comments = calculatedComments
                        self.hasEvaluated = true
                    }
                }
            }
        }
    }


@MainActor
struct HandHistoryDetailView: View {
        let history: HandHistory
        
        @ObservedObject private var profileManager = PlayerProfileManager.shared
        @State private var showingCoachComment: String? = nil
        
        // Cache for evaluated tags to prevent heavy synchronous re-evaluation during view updates
        @State private var evaluatedTags: [String: CoachAdvice] = [:]
        @State private var handNameCache: [String: String] = [:]
        @State private var hasPrecomputed: Bool = false
        
        @MainActor
        private func calcProfit(history: HandHistory) -> Int {
            let customName = PlayerProfileManager.shared.profile.customName ?? "玩家"
            
            // 查找目标玩家，如果有 playerKey 则匹配 UUID，否则退而求其次匹配名字
            let targetPlayer = history.players.first(where: {
                $0.playerName == "玩家" || $0.playerName == customName || $0.playerId == "human" || $0.playerId == "HUMAN" || $0.isHuman == true
            })
            
            guard let target = targetPlayer else { return 0 }
            guard let result = history.result else { return 0 }
            
            let initial = target.initialChips
            let final = result.chipsAfter[target.playerId] ?? initial
            
            return final - initial
        }
        
        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    players
                    actions
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(String(localized: "手牌详情"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        profileManager.toggleFavorite(handId: history.handId)
                    }) {
                        Image(systemName: profileManager.isFavorite(handId: history.handId) ? "star.fill" : "star")
                            .foregroundColor(.yellow)
                    }
                }
            }
            .alert(String(localized: "教练点评"), isPresented: Binding<Bool>(
                get: { showingCoachComment != nil },
                set: { isPresented in
                    if !isPresented {
                        showingCoachComment = nil
                    }
                }
            ), presenting: showingCoachComment) { _ in
                Button(String(localized: "明白"), role: .cancel) {
                    showingCoachComment = nil
                }
            } message: { comment in
                Text(comment)
            }
            .task {
                await precomputeCoachDataIfNeeded()
            }
        }
        
        private var header: some View {
            VStack(alignment: .leading, spacing: 8) {
                let shortHandId = history.handId.count > 6 ? String(history.handId.suffix(6)) : history.handId
                Text("Hand \(shortHandId)")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.primary)
                
                HStack {
                    Text(String(localized: "底分 L\(history.blindLevel) \(history.sbAmount)/\(history.bbAmount) 前分 \(history.anteAmount)"))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Spacer()
                    Text(formatTimestamp(history.timestamp))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                if let practiceFeedback = history.practiceFeedback {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.orange)
                        Text(String(localized: LocalizedStringResource(stringLiteral: practiceFeedback)))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.top, 4)
                }
            }
            .padding(.bottom, 6)
        }
        
        private var players: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "座位"))
                    .font(.headline.weight(.bold))
                    .foregroundColor(.primary)
                
                VStack(spacing: 6) {
                    ForEach(history.players.sorted(by: { $0.seat < $1.seat }), id: \.playerId) { p in
                        HStack {
                            Text(String(localized: "座位\(p.seat)"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.primary)
                                .frame(width: 56, alignment: .leading)
                            
                            Text(p.playerName ?? p.playerId)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                            
                            if let holeCards = p.holeCards, !holeCards.isEmpty {
                                HStack(spacing: 2) {
                                    ForEach(holeCards, id: \.self) { cardStr in
                                        Text(cardStr)
                                            .font(.subheadline.weight(.bold))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 2)
                                            .background(Color(UIColor.secondarySystemGroupedBackground))
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                            .cornerRadius(4)
                                              .foregroundColor(cardStr.contains("♥") || cardStr.contains("♦") ? .red : .primary)
                                    }
                                }
                                .padding(.leading, 4)
                            }
                            
                            Spacer()
                            
                            if let result = history.result, let finalChips = result.chipsAfter[p.playerId] {
                                let profit = finalChips - p.initialChips
                                let handNameStr = handNameCache[p.playerId] ?? getHandNameForPlayer(p.playerId, holeCards: p.holeCards)
                                
                                if profit > 0 {
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("+\(profit)")
                                            .font(.subheadline.weight(.bold))
                                            .foregroundColor(.green)
                                        if let name = handNameStr {
                                            Text(LocalizedStringKey(name))
                                                .font(.system(size: 11))
                                                .foregroundColor(.green.opacity(0.8))
                                        }
                                    }
                                } else if profit < 0 {
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("\(profit)")
                                            .font(.subheadline.weight(.bold))
                                            .foregroundColor(.red)
                                        if let name = handNameStr {
                                            Text(LocalizedStringKey(name))
                                                .font(.system(size: 11))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                } else {
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("0")
                                            .font(.subheadline.weight(.bold))
                                            .foregroundColor(.gray)
                                        if let name = handNameStr {
                                            Text(LocalizedStringKey(name))
                                                .font(.system(size: 11))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                            }
                            
                            Text(formatPosition(p.position))
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.yellow)
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.06))
                .cornerRadius(12)
            }
        }
        
        private func formatPosition(_ pos: String) -> LocalizedStringKey {
            switch pos {
            case "Button": return LocalizedStringKey("BTN")
            case "Small Blind": return LocalizedStringKey("SB")
            case "Big Blind": return LocalizedStringKey("BB")
            case "SB", "Small Base", "小盲": return LocalizedStringKey("SB")
            case "BB", "Big Base", "大盲": return LocalizedStringKey("BB")
            default:
                return LocalizedStringKey(pos)
            }
        }
        
        private var actions: some View {
            let profit = calcProfit(history: history)
            let isHugeLoss = profit < -(history.bbAmount * 20) // 输掉超过20个大底分视为大输
            
            return VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "行动"))
                    .font(.headline.weight(.bold))
                    .foregroundColor(.primary)
                
                ForEach(history.actionSequence.indices, id: \.self) { idx in
                    let round = history.actionSequence[idx]
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(phaseTitle(round.phase))
                                .font(.headline.weight(.bold))
                                .foregroundColor(.primary)
                            Spacer()
                            if !round.communityCards.isEmpty {
                                HStack(spacing: 2) {
                                    ForEach(round.communityCards, id: \.self) { cardStr in
                                        Text(cardStr)
                                            .font(.subheadline.weight(.bold))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 2)
                                            .background(Color(UIColor.secondarySystemGroupedBackground))
                                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                            .cornerRadius(4)
                                            .foregroundColor(cardStr.contains("♥") || cardStr.contains("♦") ? .red : .primary)
                                    }
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(round.actions.indices, id: \.self) { aIdx in
                                let a = round.actions[aIdx]
                                HStack(spacing: 12) {
                                    let p = history.players.first(where: { $0.playerId == a.playerId })
                                    HStack {
                                        Text(formatPosition(p?.position ?? ""))
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(.yellow)
                                            .frame(width: 32, alignment: .leading)
                                        
                                        Text(p?.playerName ?? String(localized: "座位\(a.seat)"))
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                    }
                                    .frame(width: 104, alignment: .leading)
                                    
                                    Text(actionTitle(a.action))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(actionColor(a.action))
                                        .frame(width: 56, alignment: .leading)
                                    
                                    if a.amount > 0 {
                                        Text("\(a.amount)")
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                            .monospacedDigit()
                                            .frame(width: 46, alignment: .leading)
                                    } else {
                                        Text("-")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                            .frame(width: 46, alignment: .leading)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(String(localized: "投入 \(a.totalInvested)"))
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                        .monospacedDigit()
                                        .frame(width: 80, alignment: .trailing)
                                    
                                    // Extract logic to a smaller component to help compiler
                                    let customName = PlayerProfileManager.shared.profile.customName ?? "玩家"
                                    let isHuman = a.playerId == "human" || a.playerId == "HUMAN" || history.players.first(where: { $0.playerId == a.playerId })?.playerName == "玩家" || history.players.first(where: { $0.playerId == a.playerId })?.playerName == customName || history.players.first(where: { $0.playerId == a.playerId })?.isHuman == true
                                    let actionKey = "\(round.phase)_\(a.playerId)_\(a.action.rawValue)_\(a.amount)_\(a.totalInvested)"
                                    let hasAdvice = (a.coachAdvice != nil && a.coachAdvice!.tag != .none) || (evaluatedTags[actionKey] != nil && evaluatedTags[actionKey]!.tag != .none)
                                    
                                    if isHuman && hasAdvice {
                                        CoachCommentView(
                                            action: a,
                                            round: round,
                                            history: history,
                                            isHugeLoss: isHugeLoss,
                                            evaluatedTags: $evaluatedTags,
                                            onShowComment: { comment in
                                                showingCoachComment = comment
                                            }
                                        )
                                        .frame(width: 18)
                                    } else {
                                        // 始终提供一个相同宽度的透明占位符，保证右侧“投入 xxx”对齐不受干扰
                                        Color.clear.frame(width: 18)
                                    }
                                }
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(12)
                }
            }
        }
        
        private func formatTimestamp(_ isoString: String) -> String {
            let fmt = ISO8601DateFormatter()
            if let date = fmt.date(from: isoString) {
                let out = DateFormatter()
                out.dateFormat = "yyyy-MM-dd HH:mm"
                return out.string(from: date)
            }
            return isoString
        }
        
        private func phaseTitle(_ phase: String) -> String {
            switch phase {
            case "preflop": return String(localized: "翻牌前")
            case "flop": return String(localized: "翻牌圈")
            case "turn": return String(localized: "转牌圈")
            case "river": return String(localized: "河牌圈")
            default: return phase
            }
        }
        
        private func getHandNameForPlayer(_ playerId: String, holeCards: [String]?) -> String? {
            var finalCommunityCards: [String] = []
            for round in history.actionSequence {
                for card in round.communityCards {
                    if !finalCommunityCards.contains(card) {
                        finalCommunityCards.append(card)
                    }
                }
            }
            
            let cards = holeCards ?? history.showdown?.first(where: { $0.playerId == playerId })?.holeCards
            
            if let cards = cards, cards.count == 2, !finalCommunityCards.isEmpty {
                return PokerCoachEngine.shared.getHandName(holeCards: cards, communityCards: finalCommunityCards) ?? history.showdown?.first(where: { $0.playerId == playerId })?.handName
            }
            
            return history.showdown?.first(where: { $0.playerId == playerId })?.handName
        }
        
        private func precomputeCoachDataIfNeeded() async {
            if hasPrecomputed {
                return
            }
            hasPrecomputed = true
            
            let profit = calcProfit(history: history)
            let isHugeLoss = profit < -(history.bbAmount * 10)
            let customName = PlayerProfileManager.shared.profile.customName ?? "玩家"
            
            let computed = await Task.detached(priority: .utility) { () -> (advice: [String: CoachAdvice], handNames: [String: String]) in
                var advice: [String: CoachAdvice] = [:]
                var handNames: [String: String] = [:]
                
                var finalCommunityCards: [String] = []
                for r in history.actionSequence {
                    for c in r.communityCards where !finalCommunityCards.contains(c) {
                        finalCommunityCards.append(c)
                    }
                }
                
                for p in history.players {
                    let cards = history.showdown?.first(where: { $0.playerId == p.playerId })?.holeCards ?? p.holeCards
                    if let hole = cards, hole.count == 2, !finalCommunityCards.isEmpty {
                        handNames[p.playerId] = PokerCoachEngine.shared.getHandName(holeCards: hole, communityCards: finalCommunityCards) ?? history.showdown?.first(where: { $0.playerId == p.playerId })?.handName
                    } else if let s = history.showdown?.first(where: { $0.playerId == p.playerId }) {
                        handNames[p.playerId] = s.handName
                    }
                }
                
                for r in history.actionSequence {
                    for a in r.actions {
                        let isHuman = a.playerId == "human" || a.playerId == "HUMAN" || history.players.first(where: { $0.playerId == a.playerId })?.playerName == "玩家" || history.players.first(where: { $0.playerId == a.playerId })?.playerName == customName || history.players.first(where: { $0.playerId == a.playerId })?.isHuman == true
                        
                        if isHuman {
                            if let advice = a.coachAdvice, advice.tag != .none {
                                continue
                            }
                            let key = "\(r.phase)_\(a.playerId)_\(a.action.rawValue)_\(a.amount)_\(a.totalInvested)"
                            let hole = history.players.first(where: { $0.playerId == a.playerId })?.holeCards ?? history.showdown?.first(where: { $0.playerId == a.playerId })?.holeCards
                            let v = PokerCoachEngine.shared.evaluateFromHistory(action: a, round: r, playerHoleCards: hole, isHugeLoss: isHugeLoss, history: history)
                            if v.tag != .none {
                                advice[key] = v
                            }
                        }
                    }
                }
                
                return (advice, handNames)
            }.value
            
            await MainActor.run {
                evaluatedTags.merge(computed.advice) { _, new in new }
                handNameCache.merge(computed.handNames) { _, new in new }
            }
        }
        
        
        private func actionTitle(_ action: HandActionType) -> String {
            switch action {
            case .POST_ANTE: return String(localized: "前分")
            case .POST_SB: return "SB"
            case .POST_BB: return "BB"
            case .FOLD: return String(localized: "弃牌")
            case .CHECK: return String(localized: "过牌")
            case .CALL: return String(localized: "跟注")
            case .BET: return String(localized: "下注")
            case .RAISE: return String(localized: "加注")
            case .ALL_IN: return String(localized: "全押")
            case .WIN: return String(localized: "赢得")
            }
        }
        
        private func actionColor(_ action: HandActionType) -> Color {
            switch action {
            case .FOLD: return .red
            case .CHECK: return .blue
            case .CALL: return .green
            case .BET, .RAISE: return .orange
            case .ALL_IN: return .purple
            case .WIN: return .yellow
            default: return .gray
            }
        }
    }
