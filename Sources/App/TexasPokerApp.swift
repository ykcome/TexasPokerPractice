import SwiftUI

@main
struct TexasPokerApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(.indigo) // Clean modern tool look
        }
    }
}

struct RootView: View {
    @State private var isGameVisible = false
    
    var body: some View {
        ZStack {
            SplashScreenView()
                .opacity(isGameVisible ? 0 : 1)
            
            if isGameVisible {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeOut(duration: 0.25)) {
                    isGameVisible = true
                }
            }
        }
    }
}

struct SplashScreenView: View {
    var body: some View {
        ZStack {
            Color("SplashBackground")
                .ignoresSafeArea()
            
            Image("SplashLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0
    @StateObject private var gameManager = GameManager()
    @StateObject private var economyManager = EconomyManager.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab, gameManager: gameManager)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text(String(localized: "首页"))
                }
                .tag(0)

            GameView(gameManager: gameManager)
                .tabItem {
                    Image(systemName: "play.circle.fill")
                    Text(String(localized: "练习场"))
                }
                .tag(1)

            PlayerProfileView(selectedTab: $selectedTab, gameManager: gameManager)
                .tabItem {
                    Image(systemName: "person.fill")
                    Text(String(localized: "主页"))
                }
                .tag(2)
        }
        .accentColor(.green)
        .sheet(item: $economyManager.activeSheet) { sheet in
            EconomySheetView(sheet: sheet, economyManager: economyManager)
        }
        .overlay(alignment: .top) {
            if let message = economyManager.toastMessage {
                Text(LocalizedStringKey(message))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(12)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: economyManager.toastMessage)
        .onChange(of: economyManager.toastMessage) { newValue in
            guard newValue != nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                economyManager.clearToast()
            }
        }
    }
}

struct HomeView: View {
    @Binding var selectedTab: Int
    @ObservedObject var gameManager: GameManager
    @StateObject private var economyManager = EconomyManager.shared
    @StateObject private var profileManager = PlayerProfileManager.shared
    @State private var showingSNGSetup = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Stats
                    HStack {
                        VStack(alignment: .leading) {
                            Text(String(localized: "欢迎练习，\(profileManager.profile.customName ?? "Player")"))
                                .font(.title2.bold())
                                .foregroundColor(.primary)
                            Text(String(localized: "选择一个模式开始提升你的策略"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.yellow)
                            Text("\(profileManager.profile.stamina)")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Button(action: {
                                economyManager.presentEarnCoins()
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color(UIColor.separator).opacity(0.1), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)

                    VStack(spacing: 0) {
                        Text(String(localized: "专业练习模式"))
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.bottom, 12)
                        
                        VStack(spacing: 16) {
                            ModeCardView(
                                title: String(localized: "3Bet 练习"),
                                description: String(localized: "面对前位加注，练习你的3Bet决策。附带教练点评。"),
                                icon: "arrow.up.right.circle.fill",
                                color: .orange
                            ) {
                                economyManager.startPractice(isFree: true) {
                                    gameManager.startPracticeMode(.threeBet)
                                    selectedTab = 1
                                }
                            }

                            Divider()
                                .padding(.leading, 76)

                            ModeCardView(
                                title: String(localized: "Push/Fold 练习"),
                                description: String(localized: "短码阶段(8-15BB)的全押与弃牌决策。"),
                                icon: "bolt.horizontal.fill",
                                color: .red
                            ) {
                                economyManager.startPractice(isFree: true) {
                                    gameManager.startPracticeMode(.pushFold)
                                    selectedTab = 1
                                }
                            }

                            Divider()
                                .padding(.leading, 76)

                            ModeCardView(
                                title: String(localized: "Steal 偷盲练习"),
                                description: String(localized: "在后位或小盲位，通过加注向盲注施压。"),
                                icon: "eye.slash.fill",
                                color: .purple
                            ) {
                                economyManager.startPractice(isFree: true) {
                                    gameManager.startPracticeMode(.steal)
                                    selectedTab = 1
                                }
                            }

                            Divider()
                                .padding(.leading, 76)

                            ModeCardView(
                                title: String(localized: "Defend 防守盲注"),
                                description: String(localized: "在大盲位面对偷盲加注，决定跟注、3Bet或弃牌。"),
                                icon: "shield.fill",
                                color: .teal
                            ) {
                                economyManager.startPractice(isFree: true) {
                                    gameManager.startPracticeMode(.defend)
                                    selectedTab = 1
                                }
                            }
                            
                            Divider()
                                .padding(.leading, 76)
                            
                            ModeCardView(
                                title: String(localized: "1v1 HU 练习"),
                                description: String(localized: "模拟SNG后期单挑阶段，双方以20BB开始对抗。"),
                                icon: "person.2.fill",
                                color: .blue
                            ) {
                                economyManager.startPractice(isFree: true) {
                                    gameManager.startPracticeMode(.hu)
                                    selectedTab = 1
                                }
                            }
                            
                            Divider()
                                .padding(.leading, 76)
                            
                            ModeCardView(
                                title: String(localized: "6人 SNG 练习"),
                                description: String(localized: "完整的6人桌SNG策略模拟。"),
                                icon: "person.3.sequence.fill",
                                color: .green
                            ) {
                                showingSNGSetup = true
                            }
                        }
                        .padding(.vertical, 8)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(UIColor.separator).opacity(0.1), lineWidth: 1)
                        )
                        .padding(.horizontal)
                    }
                }
            }
            .background(Color(UIColor.systemBackground).ignoresSafeArea())
            .navigationTitle("SNG Simulator")
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingSNGSetup) {
            SNGSetupView(selectedTab: $selectedTab, gameManager: gameManager)
        }
    }
}

struct ModeCardView: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    var requiresStamina: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: icon)
                            .font(.title3)
                            .foregroundColor(color)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(title)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            if requiresStamina {
                                HStack(spacing: 2) {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 10, weight: .bold))
                                    Text("-1")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .cornerRadius(4)
                            }
                        }
                        
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                        .font(.subheadline.bold())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.clear)
        }
        .buttonStyle(.plain)
    }
}
import SwiftUI

struct SNGSetupView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding var selectedTab: Int
    @ObservedObject var gameManager: GameManager
    @ObservedObject var economyManager = EconomyManager.shared
    
    @State private var aiPlayerCount: Int = 5 // 1 to 5
    @State private var initialChips: Int = 1000
    @State private var startingLevelIndex: Int = 0 // 0 means Level 1
    
    let chipOptions = [500, 1000, 1500, 2000, 3000, 4000, 5000]
    
    var aiChips: Int {
        return (6000 - initialChips) / aiPlayerCount
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(String(localized: "玩家配置"))) {
                    Stepper(value: $aiPlayerCount, in: 1...5) {
                        HStack {
                            Text(String(localized: "AI 对手数量"))
                            Spacer()
                            Text(String(format: String(localized: "%lld 人"), Int64(aiPlayerCount)))
                                .foregroundColor(.secondary)
                        }
                    }
                    Text(String(format: String(localized: "总计桌上玩家: %lld 人"), Int64(aiPlayerCount + 1)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text(String(localized: "比赛配置"))) {
                    Picker(String(localized: "我的初始积分"), selection: $initialChips) {
                        ForEach(chipOptions, id: \.self) { chips in
                            Text("\(chips)").tag(chips)
                        }
                    }
                    
                    HStack {
                        Text(String(localized: "AI 初始积分"))
                        Spacer()
                        Text("\(aiChips)")
                            .foregroundColor(.secondary)
                    }
                    
                    Picker(String(localized: "起始盲注级别"), selection: $startingLevelIndex) {
                        ForEach(0..<TournamentState.defaultBlindSchedule.count, id: \.self) { index in
                            let level = TournamentState.defaultBlindSchedule[index]
                            Text(String(format: String(localized: "级别 %lld: %lld/%lld"), Int64(level.level), Int64(level.sb), Int64(level.bb))).tag(index)
                        }
                    }
                }
                
                Section(footer: Text(String(localized: "开始训练将消耗 1 点体力值。"))) {
                    Button(action: {
                        startGame()
                    }) {
                        Text(String(localized: "开始训练"))
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(.green)
                    }
                }
            }
            .navigationTitle(String(localized: "SNG 训练配置"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "取消")) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func startGame() {
        economyManager.startPractice {
            gameManager.startSNGTraining(
                aiCount: aiPlayerCount,
                humanChips: initialChips,
                aiChips: aiChips,
                startingLevel: startingLevelIndex
            )
            selectedTab = 1
            dismiss()
        }
    }
}
