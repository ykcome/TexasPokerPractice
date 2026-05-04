import SwiftUI
import PhotosUI

@MainActor
struct PlayerProfileView: View {
    @Binding var selectedTab: Int
    @ObservedObject var gameManager: GameManager
    @StateObject private var profileManager = PlayerProfileManager.shared
    @StateObject private var economyManager = EconomyManager.shared
    
    @State private var showingNameEdit = false
    @State private var newName = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var allHistories: [HandHistory] = []
    @State private var groupedHistories: [String: [HandHistory]] = [:]
    @State private var isLoadingHistories = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header / Avatar / Name
                    VStack(spacing: 16) {
                        PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                            ZStack(alignment: .bottomTrailing) {
                                if let data = profileManager.profile.customAvatarData,
                                   let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 2))
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .frame(width: 100, height: 100)
                                        .foregroundColor(.gray)
                                }
                                
                                Image(systemName: "camera.circle.fill")
                                    .resizable()
                                    .frame(width: 28, height: 28)
                                    .foregroundColor(.blue)
                                    .background(Circle().fill(Color(UIColor.systemBackground)))
                                    .offset(x: 0, y: 0)
                            }
                        }
                        .onChange(of: selectedItem) { newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    profileManager.updateCustomAvatar(data)
                                }
                            }
                        }
                        
                        HStack {
                            Text(profileManager.profile.customName ?? "Player")
                                .font(.title2.weight(.bold))
                                .foregroundColor(.primary)
                            
                            Button(action: {
                                newName = profileManager.profile.customName ?? ""
                                showingNameEdit = true
                            }) {
                                Image(systemName: "pencil.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.top, 20)
                    
                    // Stats Grid
                    let stats = profileManager.stats
                    let favorites = Set(profileManager.profile.favoriteHandIds)
                    let favoriteHistories = allHistories
                        .filter { favorites.contains($0.handId) }
                        .sorted { $0.timestamp > $1.timestamp }
                        
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        StatCard(title: String(localized: "体力值"), value: "\(stats.currentStamina)", icon: "bolt.fill", color: .green) {
                            economyManager.presentEarnCoins()
                        }
                        
                        // Count total hands from histories instead of games
                        let totalHandsCount = groupedHistories.values.reduce(0) { $0 + $1.count }
                        StatCard(title: String(localized: "训练手牌"), value: "\(totalHandsCount)", icon: "brain.head.profile", color: .blue)
                        
                        NavigationLink(destination: FavoriteHandsListView(histories: favoriteHistories, allHistories: allHistories, economyManager: economyManager, gameManager: gameManager, selectedTab: $selectedTab)) {
                            StatCard(title: String(localized: "收藏手牌"), value: "\(favoriteHistories.count)", icon: "star.fill", color: .orange)
                        }
                        .buttonStyle(.plain)
                        
                        NavigationLink(destination: RangeChartsView()) {
                            StatCard(title: String(localized: "概率表"), value: "\(RangeChartsData.defaultCharts.count)", icon: "percent", color: .indigo)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                    
                    // History
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "练习记录"))
                            .font(.headline)
                            .foregroundColor(.primary)
                            .padding(.horizontal)
                        
                        if isLoadingHistories {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else if groupedHistories.isEmpty {
                            Text(String(localized: "暂无记录"))
                                .foregroundColor(.gray)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            // Sort categories
                            let categories = groupedHistories.keys.sorted()
                            ForEach(categories, id: \.self) { category in
                                NavigationLink(destination: PracticeCategoryDetailView(categoryName: category, histories: groupedHistories[category] ?? [])) {
                                    CategoryRow(categoryKey: category, count: groupedHistories[category]?.count ?? 0)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.bottom, 30)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(String(localized: "个人主页"))
            .navigationBarTitleDisplayMode(.inline)
            .alert(String(localized: "修改昵称"), isPresented: $showingNameEdit) {
                TextField(String(localized: "输入新昵称"), text: $newName)
                Button(String(localized: "取消"), role: .cancel) {}
                Button(String(localized: "保存")) {
                    let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                    profileManager.updateCustomName(trimmed.isEmpty ? nil : trimmed)
                }
            }
            .task {
                await loadHandHistories()
            }
        }
    }
    
    @MainActor
    private func loadHandHistories() async {
        guard !isLoadingHistories else { return }
        isLoadingHistories = true
        defer { isLoadingHistories = false }
        
        // Load in background
        let histories = await Task.detached {
            HandHistoryExporter.shared.loadAllHandHistories()
        }.value
        
        var dict: [String: [HandHistory]] = [:]
        for history in histories {
            let typeKey = history.practiceType ?? "6人 SNG 练习"
            dict[typeKey, default: []].append(history)
        }
        self.allHistories = histories
        self.groupedHistories = dict
    }
    
    @MainActor
    private func calcProfit(history: HandHistory) -> Int {
        let customName = PlayerProfileManager.shared.profile.customName ?? "玩家"
        let targetPlayer = history.players.first(where: {
            $0.playerName == "玩家" || $0.playerName == customName || $0.playerId == "human" || $0.playerId == "HUMAN" || $0.isHuman == true
        })
        
        guard let target = targetPlayer else { return 0 }
        guard let result = history.result else { return 0 }
        
        let initial = target.initialChips
        let final = result.chipsAfter[target.playerId] ?? initial
        return final - initial
    }
}

struct FavoriteHandRowView: View {
    let history: HandHistory
    let profit: Int
    let onReplay: () -> Void
    
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
        HStack(spacing: 12) {
            NavigationLink(destination: HandHistoryDetailView(history: history)) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(formatHandTime(history.timestamp))
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
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
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            
            Button(action: onReplay) {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var action: (() -> Void)? = nil
    
    var body: some View {
        if let act = action {
            Button(action: act) {
                cardContent
            }
            .buttonStyle(.plain)
        } else {
            cardContent
        }
    }
    
    private var cardContent: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                HStack {
                    Text(value)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    
                    if action != nil {
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
            Spacer()
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .cornerRadius(12)
        .contentShape(Rectangle()) // Make the whole area tappable
    }
}

struct CategoryRow: View {
    let categoryKey: String
    let count: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: String.LocalizationValue(categoryKey)))
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(String(format: String(localized: "共 %lld 手牌"), Int64(count)))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.caption)
                .padding(.leading, 8)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

@MainActor
struct FavoriteHandsListView: View {
    let histories: [HandHistory]
    let allHistories: [HandHistory] // Passed down if we need it later, but not strictly required
    @ObservedObject var economyManager: EconomyManager
    @ObservedObject var gameManager: GameManager
    @Binding var selectedTab: Int
    
    var body: some View {
        List {
            if histories.isEmpty {
                Text(String(localized: "暂无收藏"))
                    .foregroundColor(.gray)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(Array(histories.enumerated()), id: \.element.handId) { index, history in
                    FavoriteHandRowView(
                        history: history,
                        profit: calcProfit(history: history),
                        onReplay: {
                            economyManager.startPractice(isFree: true) {
                                gameManager.startPracticeReplay(from: history, playlist: histories, index: index)
                                selectedTab = 1
                            }
                        }
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(String(localized: "收藏手牌"))
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @MainActor
    private func calcProfit(history: HandHistory) -> Int {
        let customName = PlayerProfileManager.shared.profile.customName ?? "玩家"
        let targetPlayer = history.players.first(where: {
            $0.playerName == "玩家" || $0.playerName == customName || $0.playerId == "human" || $0.playerId == "HUMAN" || $0.isHuman == true
        })
        
        guard let target = targetPlayer else { return 0 }
        guard let result = history.result else { return 0 }
        
        let initial = target.initialChips
        let final = result.chipsAfter[target.playerId] ?? initial
        return final - initial
    }
}

@MainActor
struct PracticeCategoryDetailView: View {
    let categoryName: String
    let histories: [HandHistory]
    
    @State private var showingCoachComment: String? = nil
    
    var body: some View {
        List {
            ForEach(histories, id: \.handId) { history in
                HandHistoryRowView(
                    history: history,
                    profit: calcProfit(history: history),
                    onShowComment: { combinedComment in
                        showingCoachComment = combinedComment
                    }
                )
                .listRowBackground(Color.white.opacity(0.05))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(String(localized: String.LocalizationValue(categoryName)))
        .navigationBarTitleDisplayMode(.inline)
        .alert(String(localized: "本局教练点评"), isPresented: Binding<Bool>(
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
    }
    
    @MainActor
    private func calcProfit(history: HandHistory) -> Int {
        let customName = PlayerProfileManager.shared.profile.customName ?? "玩家"
        let targetPlayer = history.players.first(where: {
            $0.playerName == "玩家" || $0.playerName == customName || $0.playerId == "human" || $0.playerId == "HUMAN" || $0.isHuman == true
        })
        
        guard let target = targetPlayer else { return 0 }
        guard let result = history.result else { return 0 }
        
        let initial = target.initialChips
        let final = result.chipsAfter[target.playerId] ?? initial
        return final - initial
    }
}

struct RangeChart: Identifiable, Hashable, Decodable {
    let id: String
    let titleKey: String
    let tableText: String
}

fileprivate enum RangeTier: Int, Hashable {
    case early
    case middle
    case late
    case button
    case punt
    
    var color: Color {
        switch self {
        case .early:
            return Color(red: 0.74, green: 0.23, blue: 0.23)
        case .middle:
            return Color(red: 0.92, green: 0.63, blue: 0.25)
        case .late:
            return Color(red: 0.95, green: 0.88, blue: 0.30)
        case .button:
            return Color(red: 0.55, green: 0.70, blue: 0.84)
        case .punt:
            return Color(UIColor.systemGray4)
        }
    }
}

fileprivate struct RangeChartsConfig: Decodable {
    let version: Int?
    let sourceURL: String
    let beginnerRangeTiers: [[String]]
    let charts: [RangeChart]
}

private extension RangeTier {
    init(string: String) {
        switch string {
        case "early":
            self = .early
        case "middle":
            self = .middle
        case "late":
            self = .late
        case "button":
            self = .button
        default:
            self = .punt
        }
    }
}

enum RangeChartsData {
    fileprivate static let config: RangeChartsConfig = loadConfig()
    
    static var sourceURL: URL {
        URL(string: config.sourceURL) ?? URL(string: "https://zhuanlan.zhihu.com/p/567967774")!
    }
    
    static var defaultCharts: [RangeChart] {
        config.charts
    }
    
    fileprivate static var beginnerRangeTiers: [[RangeTier]] {
        config.beginnerRangeTiers.map { $0.map(RangeTier.init(string:)) }
    }
    
    fileprivate static func loadConfig() -> RangeChartsConfig {
        guard let url = Bundle.main.url(forResource: "RangeCharts", withExtension: "json") else {
            return RangeChartsConfig(version: 1, sourceURL: "https://zhuanlan.zhihu.com/p/567967774", beginnerRangeTiers: [], charts: [])
        }
        
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(RangeChartsConfig.self, from: data)
        } catch {
            return RangeChartsConfig(version: 1, sourceURL: "https://zhuanlan.zhihu.com/p/567967774", beginnerRangeTiers: [], charts: [])
        }
    }
}

struct RangeChartsView: View {
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(RangeChartsData.defaultCharts) { chart in
                    let title = String(localized: String.LocalizationValue(chart.titleKey))
                    NavigationLink(destination: RangeChartDetailView(chartId: chart.id, title: title, tableText: chart.tableText)) {
                        RangeChartCardView(chartId: chart.id, title: title)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(String(localized: "概率表"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct RangeChartCardView: View {
    let chartId: String
    let title: String
    
    var body: some View {
        let style = cardStyle(chartId: chartId)
        
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: style.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: style.symbol)
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.white)
            }
            .frame(height: 86)
            .frame(maxWidth: .infinity)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func cardStyle(chartId: String) -> (symbol: String, gradientColors: [Color]) {
        switch chartId {
        case "1":
            return ("percent", [Color.indigo, Color.purple])
        case "2":
            return ("square.grid.3x3.fill", [Color.red, Color.orange])
        case "3":
            return ("person.3.fill", [Color.blue, Color.cyan])
        case "4":
            return ("person.2.square.stack.fill", [Color.teal, Color.green])
        case "5":
            return ("a.circle.fill", [Color.pink, Color.purple])
        case "6":
            return ("rectangle.stack.badge.minus", [Color.gray, Color.black.opacity(0.7)])
        case "7":
            return ("suit.spade.fill", [Color.black.opacity(0.9), Color.gray])
        case "8":
            return ("crown.fill", [Color.yellow, Color.orange])
        case "9":
            return ("target", [Color.mint, Color.teal])
        case "10":
            return ("arrow.up.right", [Color.green, Color.mint])
        case "11":
            return ("arrow.right", [Color.blue, Color.indigo])
        case "12":
            return ("arrow.down.right", [Color.orange, Color.red])
        case "13":
            return ("shuffle", [Color.brown, Color.orange])
        default:
            return ("tablecells", [Color(UIColor.tertiarySystemGroupedBackground), Color(UIColor.secondarySystemGroupedBackground)])
        }
    }
}

private struct DataTable: Hashable {
    let columns: [String]
    var rows: [[String]]
    let footnote: String?
}

private struct DataTableView: View {
    let table: DataTable
    
    var body: some View {
        let colCount = table.columns.count
        
        ScrollView(.horizontal) {
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    ForEach(0..<colCount, id: \.self) { colIndex in
                        headerCell(text: table.columns[colIndex])
                    }
                }
                
                ForEach(Array(table.rows.enumerated()), id: \.offset) { rowIndex, row in
                    GridRow {
                        ForEach(0..<colCount, id: \.self) { colIndex in
                            let text = colIndex < row.count ? row[colIndex] : ""
                            dataCell(text: text, rowIndex: rowIndex, isFirstColumn: colIndex == 0)
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.12), lineWidth: 1))
            .padding(.horizontal, 1)
        }
        .scrollIndicators(.hidden)
    }
    
    private func headerCell(text: String) -> some View {
        Text(text)
            .font(.system(.footnote, design: .monospaced))
            .foregroundColor(.primary)
            .frame(width: 132, height: 36, alignment: .center)
            .padding(.horizontal, 8)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .overlay(Rectangle().stroke(Color.black.opacity(0.12), lineWidth: 1))
    }
    
    private func dataCell(text: String, rowIndex: Int, isFirstColumn: Bool) -> some View {
        Text(text)
            .font(.system(.footnote, design: .monospaced))
            .foregroundColor(.primary)
            .frame(width: 132, height: 34, alignment: isFirstColumn ? .leading : .center)
            .padding(.horizontal, 8)
            .background(rowIndex.isMultiple(of: 2) ? Color(UIColor.systemGroupedBackground) : Color(UIColor.secondarySystemGroupedBackground))
            .overlay(Rectangle().stroke(Color.black.opacity(0.12), lineWidth: 1))
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct RangeMatrixView: View {
    private let ranks = ["A", "K", "Q", "J", "T", "9", "8", "7", "6", "5", "4", "3", "2"]
    private let tiers = RangeChartsData.beginnerRangeTiers
    private let cellSize = CGSize(width: 42, height: 32)
    
    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    legendItem(color: RangeTier.early.color, title: String(localized: "前位"))
                    legendItem(color: RangeTier.middle.color, title: String(localized: "中位"))
                    legendItem(color: RangeTier.late.color, title: String(localized: "后位"))
                    legendItem(color: RangeTier.button.color, title: String(localized: "庄位"))
                    legendItem(color: RangeTier.punt.color, title: String(localized: "作死位"))
                }
                .font(.caption)
                
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        cornerCell
                        ForEach(ranks, id: \.self) { r in
                            headerCell(text: r)
                        }
                    }
                    
                    ForEach(0..<ranks.count, id: \.self) { row in
                        HStack(spacing: 0) {
                            headerCell(text: ranks[row])
                            
                            ForEach(0..<ranks.count, id: \.self) { col in
                                let tier = tiers[row][col]
                                let label = handLabel(row: row, col: col)
                                ZStack {
                                    tier.color
                                    Text(label)
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundColor(tierTextColor(tier))
                                        .minimumScaleFactor(0.6)
                                        .lineLimit(1)
                                }
                                .frame(width: cellSize.width, height: cellSize.height)
                                .overlay(Rectangle().stroke(Color.black.opacity(0.12), lineWidth: 1))
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.12), lineWidth: 1))
            }
            .padding()
        }
    }
    
    private var cornerCell: some View {
        Color(UIColor.secondarySystemGroupedBackground)
            .frame(width: cellSize.width, height: cellSize.height)
            .overlay(Rectangle().stroke(Color.black.opacity(0.12), lineWidth: 1))
    }
    
    private func headerCell(text: String) -> some View {
        ZStack {
            Color(UIColor.secondarySystemGroupedBackground)
            Text(text)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
        }
        .frame(width: cellSize.width, height: cellSize.height)
        .overlay(Rectangle().stroke(Color.black.opacity(0.12), lineWidth: 1))
    }
    
    private func legendItem(color: Color, title: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 12, height: 12)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.black.opacity(0.12), lineWidth: 1))
            Text(title)
                .foregroundColor(.secondary)
        }
    }
    
    private func tierTextColor(_ tier: RangeTier) -> Color {
        switch tier {
        case .early:
            return .white
        default:
            return .black.opacity(0.85)
        }
    }
    
    private func handLabel(row: Int, col: Int) -> String {
        let r = ranks[row]
        let c = ranks[col]
        if row == col {
            return r + c
        }
        if row < col {
            return r + c + "s"
        }
        return c + r + "o"
    }
}

private struct RangeChartDetailView: View {
    let chartId: String
    let title: String
    let tableText: String
    
    @Environment(\.locale) private var locale
    
    var body: some View {
        Group {
            if chartId == "2" {
                RangeMatrixView()
                    .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            } else {
                let rawTable = RangeChartsData.parseTable(chartId: chartId, tableText: tableText)
                let table = RangeChartsData.localizedTable(chartId: chartId, table: rawTable, locale: locale)
                
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 12) {
                        DataTableView(table: table)
                        
                        if let footnote = table.footnote, !footnote.isEmpty {
                            Text(footnote)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding()
                }
                .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension RangeChartsData {
    static func parseTable(chartId: String, tableText: String) -> DataTable {
        switch chartId {
        case "1":
            return pairTable(tableText: tableText, columns: [String(localized: "起手牌"), String(localized: "概率%")], headerLinesToSkip: 2)
        case "2":
            return rangeGroupsTable(tableText: tableText)
        case "3":
            var table = matrixTable(
                tableText: tableText,
                columns: [String(localized: "你的起手牌")] + (1...9).map(playerPercentHeader),
                rowLabels: ["KK", "QQ", "JJ", "TT", "99", "88", "77", "66", "55", "44", "33", "22"],
                valuesPerRow: 9
            )
            appendPercentToMatrixValues(table: &table)
            return table
        case "4":
            var table = matrixTable(
                tableText: tableText,
                columns: [String(localized: "你的起手牌")] + (2...9).map(playerPercentHeader),
                rowLabels: ["KK", "QQ", "JJ", "TT", "99", "88", "77", "66", "55", "44", "33", "22"],
                valuesPerRow: 8
            )
            appendPercentToMatrixValues(table: &table)
            
            let lines = cleanedLines(tableText)
            if let i = lines.firstIndex(of: "大致倍率关系") {
                let rest = lines[(i + 1)...]
                var values: [String] = []
                for line in rest {
                    for v in extractMatrixValues(line) {
                        values.append(v)
                        if values.count >= 8 { break }
                    }
                    if values.count >= 8 { break }
                }
                if !values.isEmpty {
                    while values.count < 8 { values.append("") }
                    table.rows.append([String(localized: "大致倍率关系")] + values)
                }
            }
            
            return table
        case "5":
            var table = matrixTable(
                tableText: tableText,
                columns: [String(localized: "你的起手牌")] + (1...9).map(playerPercentHeader),
                rowLabels: ["AK", "AQ", "AJ", "AT", "A9", "A8", "A7", "A6", "A5", "A4", "A3", "A2"],
                valuesPerRow: 9
            )
            appendPercentToMatrixValues(table: &table)
            return table
        case "6":
            return matrixTable(
                tableText: tableText,
                columns: [String(localized: "你的起手牌"), String(localized: "翻牌圈"), String(localized: "转牌圈"), String(localized: "河牌圈")],
                rowLabels: ["KK", "QQ", "JJ", "TT", "99", "88", "77", "66", "55", "44", "33"],
                valuesPerRow: 3
            )
        case "7":
            return tripleTable(tableText: tableText, columns: [String(localized: "牌型"), String(localized: "组合数"), String(localized: "概率%")], headerLinesToSkip: 3)
        case "8":
            return tripleTable(tableText: tableText, columns: [String(localized: "牌型"), String(localized: "组合数"), String(localized: "概率%")], headerLinesToSkip: 3)
        case "9":
            return tripleTableWithFootnote(tableText: tableText, columns: [String(localized: "起手牌"), String(localized: "提高到"), String(localized: "概率%")], headerLinesToSkip: 3)
        case "10":
            return tripleTableWithFootnote(tableText: tableText, columns: [String(localized: "翻牌圈你的牌"), String(localized: "在转牌提高到"), String(localized: "概率%")], headerLinesToSkip: 3)
        case "11":
            return tripleTableWithFootnote(tableText: tableText, columns: [String(localized: "转牌圈你的牌"), String(localized: "在河牌提高到"), String(localized: "概率%")], headerLinesToSkip: 3)
        case "12":
            return tripleTableWithFootnote(tableText: tableText, columns: [String(localized: "翻牌圈你的牌"), String(localized: "到河牌圈提高到"), String(localized: "概率%")], headerLinesToSkip: 3)
        case "13":
            return pairTable(tableText: tableText, columns: [String(localized: "翻牌圈牌面"), String(localized: "概率%")], headerLinesToSkip: 2)
        default:
            return DataTable(columns: [], rows: [], footnote: nil)
        }
    }

    static func playerPercentHeader(_ n: Int) -> String {
        String(format: String(localized: "%lld玩家(%)"), Int64(n))
    }
    
    static func appendPercentToMatrixValues(table: inout DataTable) {
        for rowIndex in table.rows.indices {
            for colIndex in table.rows[rowIndex].indices {
                if colIndex == 0 { continue }
                let v = table.rows[rowIndex][colIndex]
                if v.isEmpty { continue }
                if v.hasSuffix("%") { continue }
                table.rows[rowIndex][colIndex] = v + "%"
            }
        }
    }
    
    static func localizedTable(chartId: String, table: DataTable, locale: Locale) -> DataTable {
        let lang = locale.language.languageCode?.identifier ?? locale.identifier
        guard lang.hasPrefix("en") else { return table }
        
        var out = table
        out.rows = table.rows.map { row in
            translateRow(chartId: chartId, row: row)
        }
        return out
    }
    
    static func translateRow(chartId: String, row: [String]) -> [String] {
        guard !row.isEmpty else { return row }
        switch chartId {
        case "1":
            return [translateKey(row[0], map: enMap1)] + row.dropFirst()
        case "7", "8":
            var r = row
            r[0] = translateKey(r[0], map: enMap78)
            return r
        case "9":
            var r = row
            if r.count > 0 { r[0] = translateKey(r[0], map: enMap9Col1) }
            if r.count > 1 { r[1] = translateKey(r[1], map: enMap9Col2) }
            return r
        case "10", "11", "12":
            var r = row
            if r.count > 0 { r[0] = translateKey(r[0], map: enMap101112Col1) }
            if r.count > 1 { r[1] = translateKey(r[1], map: enMap101112Col2) }
            return r
        case "13":
            var r = row
            if r.count > 0 { r[0] = translateKey(r[0], map: enMap13) }
            return r
        default:
            return row
        }
    }
    
    static func translateKey(_ key: String, map: [String: String]) -> String {
        map[key] ?? key
    }
    
    static let enMap1: [String: String] = [
        "特定的口袋对子（例如AA或55）": "Specific pocket pair (e.g. AA or 55)",
        "口袋对子 QQ+": "Pocket pair QQ+",
        "口袋对子J+": "Pocket pair JJ+",
        "口袋对子 TT+": "Pocket pair TT+",
        "任何口袋对子": "Any pocket pair",
        "特定的非对子牌": "Specific offsuit hand",
        "特定的同花牌": "Specific suited hand",
        "同花牌": "Suited hand",
        "同花连张": "Suited connectors",
        "同花两高张（两张牌都大于等于T）": "Suited two broadways (both ≥ T)",
        "连牌": "Connectors",
        "T或更大的连牌": "Connectors T+",
        "两张Q+": "Two cards Q+",
        "两张J＋": "Two cards J+"
    ]
    
    static let enMap78: [String: String] = [
        "皇家同花顺": "Royal flush",
        "同花顺": "Straight flush",
        "四条": "Four of a kind",
        "葫芦": "Full house",
        "同花": "Flush",
        "顺子": "Straight",
        "三条": "Three of a kind",
        "两对": "Two pair",
        "两对（包含牌面两对）": "Two pair (incl. board two pair)",
        "一对（包含翻牌圈公对）": "One pair (incl. board pair)",
        "一对（包含牌面公对）": "One pair (incl. board pair)",
        "高牌": "High card"
    ]
    
    static let enMap9Col1: [String: String] = [
        "口袋对子": "Pocket pair",
        "两张单牌": "Two unpaired cards",
        "同花连张": "Suited connectors",
        "连牌54o-JTo": "Connectors 54o–JTo",
        "连牌43o或QJo": "Connectors 43o or QJo",
        "连牌32o或KQo": "Connectors 32o or KQo",
        "隔张53o-QTo": "1-gap 53o–QTo",
        "隔张75o-T8o": "2-gap 75o–T8o",
        "隔张64o、53o、J9o、Qto": "1-gap 64o/53o/J9o/QTo"
    ]
    
    static let enMap9Col2: [String: String] = [
        "暗三条或更好": "Set or better",
        "暗三条": "Set",
        "一对": "One pair",
        "两对": "Two pair",
        "明三": "Trips",
        "四条": "Quads",
        "同花": "Flush",
        "葫芦": "Full house",
        "同花听牌": "Flush draw",
        "两端顺子听牌": "Open-ended straight draw",
        "顺子": "Straight"
    ]
    
    static let enMap101112Col1: [String: String] = [
        "同花听牌": "Flush draw",
        "后门同花听牌": "Backdoor flush draw",
        "两端顺子听牌": "Open-ended straight draw",
        "后门顺子听牌": "Backdoor straight draw",
        "内听顺子": "Gutshot straight draw",
        "三条": "Trips",
        "两对": "Two pair",
        "一对": "One pair",
        "两张单牌": "Two unpaired cards"
    ]
    
    static let enMap101112Col2: [String: String] = [
        "同花": "Flush",
        "顺子": "Straight",
        "四条": "Quads",
        "葫芦": "Full house",
        "三条": "Trips",
        "对子（与底牌形成）": "Pair (with hole card)"
    ]
    
    static let enMap13: [String: String] = [
        "三条面": "Trips board",
        "公对面": "Paired board",
        "三张同花": "Monotone (3 suited)",
        "两张同花": "Two-tone (2 suited)",
        "杂色": "Rainbow",
        "三张相连的顺子（包含A23）": "3 connected (incl. A23)",
        "两张相连的顺子（包含公对）": "2 connected (incl. paired)",
        "互不相连的牌": "Disconnected"
    ]
    
    
    static func cleanedLines(_ tableText: String) -> [String] {
        tableText
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { line in
                if line.contains("@") { return false }
                if line.contains("知乎") { return false }
                if line.contains("德扑") { return false }
                if line.contains("资讯") { return false }
                return true
            }
    }
    
    static func pairTable(tableText: String, columns: [String], headerLinesToSkip: Int) -> DataTable {
        let lines = cleanedLines(tableText)
        let content = Array(lines.dropFirst(headerLinesToSkip))
        var rows: [[String]] = []
        var i = 0
        while i + 1 < content.count {
            rows.append([content[i], content[i + 1]])
            i += 2
        }
        return DataTable(columns: columns, rows: rows, footnote: nil)
    }
    
    static func tripleTable(tableText: String, columns: [String], headerLinesToSkip: Int) -> DataTable {
        let lines = cleanedLines(tableText)
        let content = Array(lines.dropFirst(headerLinesToSkip))
        var rows: [[String]] = []
        var i = 0
        while i + 2 < content.count {
            rows.append([content[i], content[i + 1], content[i + 2]])
            i += 3
        }
        return DataTable(columns: columns, rows: rows, footnote: nil)
    }
    
    static func tripleTableWithFootnote(tableText: String, columns: [String], headerLinesToSkip: Int) -> DataTable {
        let lines = cleanedLines(tableText)
        let content = Array(lines.dropFirst(headerLinesToSkip))
        var rows: [[String]] = []
        var i = 0
        while i + 2 < content.count {
            let a = content[i]
            let b = content[i + 1]
            let c = content[i + 2]
            rows.append([a, b, c])
            i += 3
        }
        let rest = i < content.count ? content[i...].joined(separator: "\n") : ""
        return DataTable(columns: columns, rows: rows, footnote: rest.isEmpty ? nil : rest)
    }
    
    static func matrixTable(tableText: String, columns: [String], rowLabels: [String], valuesPerRow: Int) -> DataTable {
        let lines = cleanedLines(tableText)
        let labelSet = Set(rowLabels)
        
        var rows: [[String]] = []
        rows.reserveCapacity(rowLabels.count)
        
        var pos = 0
        if let first = rowLabels.first, let firstIndex = lines.firstIndex(of: first) {
            pos = firstIndex + 1
        }
        
        for label in rowLabels {
            if let i = lines[pos...].firstIndex(of: label) {
                pos = i + 1
            }
            
            var values: [String] = []
            values.reserveCapacity(valuesPerRow)
            
            while pos < lines.count && values.count < valuesPerRow {
                let line = lines[pos]
                if labelSet.contains(line) { break }
                for v in extractMatrixValues(line) {
                    if values.count < valuesPerRow {
                        values.append(v)
                    }
                }
                pos += 1
            }
            
            while values.count < valuesPerRow {
                values.append("")
            }
            
            rows.append([label] + values)
        }
        
        return DataTable(columns: columns, rows: rows, footnote: nil)
    }
    
    static func rangeGroupsTable(tableText: String) -> DataTable {
        let lines = cleanedLines(tableText)
        var groups: [(String, [String])] = []
        var currentTitle: String? = nil
        var currentHands: [String] = []
        
        func flush() {
            guard let t = currentTitle else { return }
            if !currentHands.isEmpty {
                groups.append((t, currentHands))
            } else {
                groups.append((t, []))
            }
        }
        
        for line in lines {
            let isGroup = line.contains("前位") || line.contains("中位") || line.contains("后位") || line.contains("庄位") || line.contains("作死位")
            if isGroup {
                flush()
                currentTitle = line
                currentHands = []
            } else {
                if currentTitle == nil {
                    currentTitle = String(localized: "范围")
                }
                currentHands.append(line)
            }
        }
        flush()
        
        let rows = groups.map { title, hands in
            [title, hands.joined(separator: " ")]
        }
        
        return DataTable(columns: [String(localized: "位置"), String(localized: "范围")], rows: rows, footnote: nil)
    }
    
    static func extractMatrixValues(_ text: String) -> [String] {
        let pattern = "[<≤]?\\s*[-]?\\d+(?:\\.\\d+)?"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: range)
        return matches.compactMap { match in
            guard let r = Range(match.range, in: text) else { return nil }
            var s = String(text[r]).replacingOccurrences(of: " ", with: "")
            if s.hasPrefix("≤-") {
                s = "≤" + s.dropFirst(2)
            } else if s.hasPrefix("<-") {
                s = "<" + s.dropFirst(2)
            } else if s.hasPrefix("-") {
                s = String(s.dropFirst(1))
            }
            return s
        }
    }
}
