import SwiftUI
import Combine
import UserNotifications
import AppKit
import UniformTypeIdentifiers

struct MenuBarView: View {
    @EnvironmentObject var store: TokenStore
    @EnvironmentObject var oauth: OAuthManager
    @State private var isRefreshing = false
    @State private var showError: String?
    @State private var showSuccess: String?
    @State private var successMessageVersion = 0
    @State private var now = Date()
    @State private var refreshingAccounts: Set<String> = []

    private let countdownTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    private let quickTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    private let slowTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @State private var menuVisible = false
    @State private var languageToggle = false

    // Provider management
    @State private var showAddProviderSheet = false
    @State private var newProviderLabel = ""
    @State private var newProviderBaseURL = ""
    @State private var newProviderAccountLabel = ""
    @State private var newProviderAPIKey = ""
    @State private var showAddAccountSheet = false
    @State private var addAccountProviderID = ""
    @State private var newAccountLabel = ""
    @State private var newAccountAPIKey = ""

    // Batch delete
    @State private var isBatchDeleteMode = false
    @State private var selectedOAuthAccountIds: Set<String> = []
    @State private var selectedCompatibleItems: Set<String> = []

    // MARK: - Data

    private var groupedAccounts: [(email: String, accounts: [TokenAccount])] {
        var dict: [String: [TokenAccount]] = [:]
        var order: [String] = []
        for acc in store.accounts {
            if dict[acc.email] == nil {
                dict[acc.email] = []
                order.append(acc.email)
            }
            dict[acc.email]!.append(acc)
        }
        let sortedOrder = order.sorted { e1, e2 in
            guard
                let best1 = bestDisplayAccount(in: dict[e1] ?? []),
                let best2 = bestDisplayAccount(in: dict[e2] ?? [])
            else {
                return e1.localizedCaseInsensitiveCompare(e2) == .orderedAscending
            }
            return displayOrder(best1, best2)
        }
        return sortedOrder.map { email in
            let sorted = dict[email]!.sorted(by: displayOrder)
            return (email: email, accounts: sorted)
        }
    }

    private func bestDisplayAccount(in accounts: [TokenAccount]) -> TokenAccount? {
        accounts.sorted(by: displayOrder).first
    }

    private func displayOrder(_ lhs: TokenAccount, _ rhs: TokenAccount) -> Bool {
        lhs.displaySortKey < rhs.displaySortKey
    }

    private var availableCount: Int {
        store.accounts.filter { $0.usageStatus == .ok }.count
    }

    private var activeAccount: TokenAccount? {
        store.accounts.first(where: { $0.isActive })
    }

    private var featuredAccount: TokenAccount? {
        activeAccount ?? groupedAccounts.first?.accounts.first
    }

    private var lastUpdatedAt: Date? {
        store.accounts.compactMap { $0.lastChecked }.max()
    }

    private var languageLabel: String {
        switch L.languageOverride {
        case nil: return "AUTO"
        case true: return "中"
        case false: return "EN"
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            GlassPanelBackground()

            VStack(alignment: .leading, spacing: 0) {
                // Hero summary card
                summaryCard
                    .padding(.bottom, MenuBarTheme.cardSpacing)

                // Account list or empty state
                if store.accounts.isEmpty {
                    emptyStateCard
                        .padding(.bottom, MenuBarTheme.cardSpacing)
                } else {
                    accountsList
                        .padding(.bottom, MenuBarTheme.cardSpacing)
                }

                // Message banners
                if let success = showSuccess {
                    messageBanner(message: success, systemImage: "checkmark.circle.fill", tint: MenuBarTheme.success)
                        .padding(.bottom, MenuBarTheme.cardSpacing)
                }

                if let error = showError {
                    messageBanner(message: error, systemImage: "exclamationmark.triangle.fill", tint: MenuBarTheme.warning, dismissAction: { showError = nil })
                        .padding(.bottom, MenuBarTheme.cardSpacing)
                }

                // Footer
                footerBar
            }
            .padding(MenuBarTheme.cardPadding)
        }
        .frame(width: MenuBarTheme.panelWidth, height: max(500, min(CGFloat(store.accounts.count) * 130 + 220, 900)))
        .onReceive(countdownTimer) { _ in now = Date() }
        .onReceive(quickTimer) { _ in
            guard menuVisible, let active = store.accounts.first(where: { $0.isActive }), !active.secondaryExhausted else { return }
            Task { await refreshAccount(active) }
        }
        .onReceive(slowTimer) { _ in
            guard !menuVisible else { return }
            Task {
                await refresh()
                store.markActiveAccount()
                autoSwitchIfNeeded()
            }
        }
        .onReceive(oauth.$successMessage.compactMap { $0 }) { message in
            showError = nil
            showTransientSuccess(message)
            oauth.clearSuccessMessage()
        }
        .onReceive(oauth.$errorMessage.compactMap { $0 }) { message in
            showSuccess = nil
            showError = message
            oauth.clearErrorMessage()
        }
        .onAppear {
            menuVisible = true
            store.markActiveAccount()
            if let success = oauth.consumeSuccessMessage() {
                showTransientSuccess(success)
            }
            if let error = oauth.consumeErrorMessage() {
                showSuccess = nil
                showError = error
            }
        }
        .onDisappear { menuVisible = false }
        .sheet(isPresented: $showAddProviderSheet) { addProviderSheet }
        .sheet(isPresented: $showAddAccountSheet) { addAccountSheet }
    }

    // MARK: - Summary Card (Hero)

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row: brand + refresh
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    // Crypto-style shield icon
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MenuBarTheme.accent)

                    Text("CODEX BAR")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(MenuBarTheme.textTertiary)
                        .tracking(2)
                }

                Spacer()

                Button { Task { await refresh(); showTransientSuccess(L.refreshDone) } } label: {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                }
                .buttonStyle(GlassIconButtonStyle(prominent: isRefreshing, tint: MenuBarTheme.accent))
                .disabled(isRefreshing)
            }

            // Main title (email) + availability
            VStack(alignment: .leading, spacing: 6) {
                Text(summaryTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(MenuBarTheme.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !store.accounts.isEmpty {
                    MenuBarPill(
                        text: L.available(availableCount, store.accounts.count),
                        tint: availableCount > 0 ? MenuBarTheme.success : MenuBarTheme.error,
                        icon: availableCount > 0 ? "checkmark.shield.fill" : "exclamationmark.shield.fill",
                        emphasized: true
                    )
                }
            }

            // Mini usage preview for active account
            if let active = activeAccount {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 16) {
                        if active.visibleQuotaWindows.isEmpty {
                            Text(L.waitingForRefresh)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(MenuBarTheme.textTertiary)
                        } else {
                            ForEach(active.visibleQuotaWindows) { window in
                                miniStat(
                                    label: window.title,
                                    value: "\(Int(window.usedPercent))%",
                                    color: MenuBarTheme.quotaColor(window.usedPercent)
                                )
                            }
                        }

                        Spacer()

                        // Security badge
                        HStack(spacing: 4) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 10, weight: .semibold))
                            Text("SECURED")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(1)
                        }
                        .foregroundStyle(MenuBarTheme.success.opacity(0.8))
                    }

                    if !active.nextRefreshSummary.isEmpty {
                        Text(active.nextRefreshSummary)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(MenuBarTheme.textTertiary)
                            .lineLimit(2)
                    }
                }
            }
        }
        .padding(MenuBarTheme.cardPadding)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: MenuBarTheme.cardRadius, style: .continuous)
                    .fill(MenuBarTheme.bgSecondary)

                // Subtle gradient overlay
                RoundedRectangle(cornerRadius: MenuBarTheme.cardRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [MenuBarTheme.accent.opacity(0.06), Color.clear],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: MenuBarTheme.cardRadius, style: .continuous)
                    .strokeBorder(MenuBarTheme.glassBorder, lineWidth: 0.5)
            }
        }
    }

    // MARK: - Mini Stat

    private func miniStat(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .shadow(color: color.opacity(0.5), radius: 3)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(MenuBarTheme.textTertiary)

            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
        }
    }

    // MARK: - Trust Indicators Bar

    private var trustBar: some View {
        HStack(spacing: 12) {
            trustItem(icon: "bolt.shield.fill", text: L.autoSwitch)
            Spacer()
            trustItem(icon: "arrow.triangle.2.circlepath", text: L.realTimeSync)
            Spacer()
            trustItem(icon: "person.2.fill", text: "\(store.accounts.count) \(L.wallets)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: MenuBarTheme.tagRadius, style: .continuous)
                    .fill(MenuBarTheme.glassFill)

                RoundedRectangle(cornerRadius: MenuBarTheme.tagRadius, style: .continuous)
                    .strokeBorder(MenuBarTheme.glassBorder, lineWidth: 0.5)
            }
        }
    }

    private func trustItem(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(MenuBarTheme.info)

            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(MenuBarTheme.textTertiary)
                .lineLimit(1)
        }
    }

    // MARK: - Empty State

    private var emptyStateCard: some View {
        VStack(spacing: MenuBarTheme.cardSpacing) {
            ZStack {
                Circle()
                    .fill(MenuBarTheme.accent.opacity(0.1))
                    .frame(width: 56, height: 56)

                Image(systemName: "wallet.pass.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(MenuBarTheme.accent)
            }

            VStack(spacing: 4) {
                Text(L.noAccounts)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(MenuBarTheme.textPrimary)
                Text(L.addAccountHint)
                    .font(.system(size: 12))
                    .foregroundStyle(MenuBarTheme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: MenuBarTheme.cardRadius, style: .continuous)
                    .fill(MenuBarTheme.glassFill)

                RoundedRectangle(cornerRadius: MenuBarTheme.cardRadius, style: .continuous)
                    .strokeBorder(MenuBarTheme.glassBorder, lineWidth: 0.5)
            }
        }
    }

    // MARK: - Account List

    private var accountsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MenuBarTheme.groupSpacing) {
                // Compatible Providers 区域
                if !store.customProviders.isEmpty {
                    VStack(alignment: .leading, spacing: MenuBarTheme.titleContentSpacing) {
                        Text("Custom Providers")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(MenuBarTheme.textTertiary)
                            .tracking(1)

                        VStack(spacing: MenuBarTheme.cardSpacing) {
                            ForEach(store.customProviders) { provider in
                                CompatibleProviderRowView(
                                    provider: provider,
                                    isActiveProvider: store.config.active.providerId == provider.id,
                                    activeAccountId: store.config.active.providerId == provider.id
                                        ? store.config.active.accountId : nil,
                                    isBatchMode: isBatchDeleteMode,
                                    selectedItemIds: Set(selectedCompatibleItems.compactMap { item -> String? in
                                        let parts = item.components(separatedBy: "::")
                                        guard parts.count == 2, parts[0] == provider.id else { return nil }
                                        return parts[1]
                                    }),
                                    onToggleSelection: { account in
                                        let key = "\(provider.id)::\(account.id)"
                                        if selectedCompatibleItems.contains(key) {
                                            selectedCompatibleItems.remove(key)
                                        } else {
                                            selectedCompatibleItems.insert(key)
                                        }
                                    },
                                    onActivate: { account in
                                        do {
                                            try store.activateCustomProvider(providerID: provider.id, accountID: account.id)
                                            showError = nil
                                            showTransientSuccess("已切换到 \(provider.label)")
                                            handleCodexRestart()
                                        } catch {
                                            showError = error.localizedDescription
                                        }
                                    },
                                    onAddAccount: {
                                        addAccountProviderID = provider.id
                                        showAddAccountSheet = true
                                    },
                                    onDeleteAccount: { account in
                                        do {
                                            try store.removeCustomProviderAccount(providerID: provider.id, accountID: account.id)
                                        } catch {
                                            showError = error.localizedDescription
                                        }
                                    },
                                    onDeleteProvider: {
                                        let alert = NSAlert()
                                        alert.messageText = "删除 \(provider.label)？"
                                        alert.alertStyle = .warning
                                        alert.addButton(withTitle: "删除")
                                        alert.addButton(withTitle: "取消")
                                        if alert.runModal() == .alertFirstButtonReturn {
                                            do {
                                                try store.removeCustomProvider(providerID: provider.id)
                                            } catch {
                                                showError = error.localizedDescription
                                            }
                                        }
                                    }
                                )
                            }
                        }
                    }
                }

                // OAuth 区域 header
                if !store.customProviders.isEmpty && !store.accounts.isEmpty {
                    Text("OpenAI OAuth")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(MenuBarTheme.textTertiary)
                        .tracking(1)
                }

                ForEach(groupedAccounts, id: \.email) { group in
                    VStack(alignment: .leading, spacing: MenuBarTheme.titleContentSpacing) {
                        groupHeader(for: group)

                        VStack(spacing: MenuBarTheme.cardSpacing) {
                            ForEach(group.accounts) { account in
                                HStack(spacing: 8) {
                                    if isBatchDeleteMode {
                                        let isSelected = selectedOAuthAccountIds.contains(account.accountId)
                                        Button {
                                            if isSelected {
                                                selectedOAuthAccountIds.remove(account.accountId)
                                            } else {
                                                selectedOAuthAccountIds.insert(account.accountId)
                                            }
                                        } label: {
                                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 16))
                                                .foregroundStyle(isSelected ? MenuBarTheme.error : MenuBarTheme.textTertiary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    AccountRowView(
                                        account: account,
                                        isActive: account.isActive,
                                        now: now,
                                        isRefreshing: refreshingAccounts.contains(account.id)
                                    ) {
                                        if !isBatchDeleteMode { activateAccount(account) }
                                    } onRefresh: {
                                        if !isBatchDeleteMode { Task { await refreshAccount(account); showTransientSuccess(L.refreshDone) } }
                                    } onReauth: {
                                        if !isBatchDeleteMode { reauthAccount(account) }
                                    } onDelete: {
                                        if !isBatchDeleteMode { store.remove(account) }
                                    }
                                }
                            }
                        }
                    }
                }

                // 批量删除确认栏
                if isBatchDeleteMode {
                    let totalSelected = selectedOAuthAccountIds.count + selectedCompatibleItems.count
                    HStack(spacing: 8) {
                        Text("已选 \(totalSelected) 个")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(MenuBarTheme.textSecondary)
                        Spacer()
                        Button("删除选中 (\(totalSelected))") {
                            confirmBatchDelete()
                        }
                        .buttonStyle(GlassPillButtonStyle(prominent: true, tint: MenuBarTheme.error))
                        .disabled(totalSelected == 0)
                    }
                    .padding(.horizontal, MenuBarTheme.cardPadding)
                    .padding(.vertical, 8)
                    .background {
                        ZStack {
                            RoundedRectangle(cornerRadius: MenuBarTheme.cardRadius, style: .continuous)
                                .fill(MenuBarTheme.error.opacity(0.08))
                            RoundedRectangle(cornerRadius: MenuBarTheme.cardRadius, style: .continuous)
                                .strokeBorder(MenuBarTheme.error.opacity(0.2), lineWidth: 0.5)
                        }
                    }
                }
            }
        }
        .scrollIndicators(.never)
        .frame(maxHeight: 900)
    }

    // MARK: - Footer Bar

    private var footerBar: some View {
        HStack(spacing: MenuBarTheme.buttonSpacing) {
            Text(lastUpdatedAt.map(relativeTime) ?? L.waitingForRefresh)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(MenuBarTheme.textTertiary)

            Spacer()

            HStack(spacing: 4) {
                Button {
                    oauth.startOAuth { result in
                        switch result {
                        case .success(let tokens):
                            let account = AccountBuilder.build(from: tokens)
                            store.addOrUpdate(account)
                            Task { await WhamService.shared.refreshOne(account: account, store: store) }
                        case .failure(let error): showError = error.localizedDescription
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(GlassIconButtonStyle(prominent: true, tint: MenuBarTheme.accent))

                Button {
                    showAddProviderSheet = true
                } label: {
                    Image(systemName: "server.rack")
                }
                .buttonStyle(GlassIconButtonStyle(prominent: true, tint: MenuBarTheme.info))
                .help("添加自定义 Provider")

                Button {
                    isBatchDeleteMode.toggle()
                    if !isBatchDeleteMode {
                        selectedOAuthAccountIds.removeAll()
                        selectedCompatibleItems.removeAll()
                    }
                } label: {
                    Image(systemName: isBatchDeleteMode ? "xmark.circle" : "trash.slash")
                }
                .buttonStyle(GlassIconButtonStyle(tint: isBatchDeleteMode ? MenuBarTheme.warning : MenuBarTheme.error))
                .help(isBatchDeleteMode ? "取消批量删除" : "批量删除")

                Button(action: toggleLanguage) {
                    Label(languageLabel, systemImage: "globe")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(GlassPillButtonStyle(prominent: true, tint: MenuBarTheme.info))
                .help(L.toggleLanguageHelp)

                Button { NSApplication.shared.terminate(nil) } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(GlassIconButtonStyle(tint: MenuBarTheme.error))
            }
        }
        .padding(.horizontal, MenuBarTheme.cardPadding)
        .padding(.vertical, MenuBarTheme.cardSpacing)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: MenuBarTheme.cardRadius, style: .continuous)
                    .fill(MenuBarTheme.bgSecondary)

                RoundedRectangle(cornerRadius: MenuBarTheme.cardRadius, style: .continuous)
                    .strokeBorder(MenuBarTheme.glassBorder, lineWidth: 0.5)
            }
        }
    }

    // MARK: - Message Banner

    @ViewBuilder
    private func messageBanner(message: String, systemImage: String, tint: Color, dismissAction: (() -> Void)? = nil) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(MenuBarTheme.textPrimary)
                .lineLimit(2)
            Spacer()
            if let dismissAction {
                Button(action: dismissAction) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(GlassIconButtonStyle(tint: MenuBarTheme.textTertiary))
            }
        }
        .padding(MenuBarTheme.cardPadding)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: MenuBarTheme.cardRadius, style: .continuous)
                    .fill(tint.opacity(0.1))

                RoundedRectangle(cornerRadius: MenuBarTheme.cardRadius, style: .continuous)
                    .strokeBorder(tint.opacity(0.2), lineWidth: 0.5)
            }
        }
    }

    // MARK: - Group Header

    @ViewBuilder
    private func groupHeader(for group: (email: String, accounts: [TokenAccount])) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "envelope.fill")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(MenuBarTheme.textTertiary)

            Text(group.email)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MenuBarTheme.textSecondary)
                .lineLimit(1)

            Spacer()

            Text("\(group.accounts.count)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(MenuBarTheme.textTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(MenuBarTheme.glassFill)
                }
        }
    }

    // MARK: - Add Provider Sheet

    private var addProviderSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("添加自定义 Provider")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(MenuBarTheme.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                providerField(label: "名称", placeholder: "FunAI", text: $newProviderLabel)
                providerField(label: "Base URL", placeholder: "https://api.example.com/v1", text: $newProviderBaseURL)
                providerField(label: "账号名称（可选）", placeholder: "Default", text: $newProviderAccountLabel)
                providerField(label: "API Key", placeholder: "sk-...", text: $newProviderAPIKey, isSecure: true)
            }

            HStack {
                Button("取消") {
                    showAddProviderSheet = false
                    clearAddProviderFields()
                }
                .buttonStyle(GlassPillButtonStyle(tint: MenuBarTheme.textTertiary))

                Spacer()

                Button("添加") {
                    do {
                        try store.addCustomProvider(
                            label: newProviderLabel,
                            baseURL: newProviderBaseURL,
                            accountLabel: newProviderAccountLabel,
                            apiKey: newProviderAPIKey
                        )
                        showAddProviderSheet = false
                        clearAddProviderFields()
                        showTransientSuccess("已添加 \(newProviderLabel)")
                    } catch {
                        showError = error.localizedDescription
                    }
                }
                .buttonStyle(GlassPillButtonStyle(prominent: true, tint: MenuBarTheme.accent))
                .disabled(newProviderLabel.trimmingCharacters(in: .whitespaces).isEmpty ||
                          newProviderBaseURL.trimmingCharacters(in: .whitespaces).isEmpty ||
                          newProviderAPIKey.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
        .background(MenuBarTheme.bgSecondary)
    }

    private var addAccountSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("添加 API Key")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(MenuBarTheme.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                providerField(label: "账号名称（可选）", placeholder: "Account", text: $newAccountLabel)
                providerField(label: "API Key", placeholder: "sk-...", text: $newAccountAPIKey, isSecure: true)
            }

            HStack {
                Button("取消") {
                    showAddAccountSheet = false
                    newAccountLabel = ""
                    newAccountAPIKey = ""
                }
                .buttonStyle(GlassPillButtonStyle(tint: MenuBarTheme.textTertiary))

                Spacer()

                Button("添加") {
                    do {
                        try store.addCustomProviderAccount(
                            providerID: addAccountProviderID,
                            label: newAccountLabel,
                            apiKey: newAccountAPIKey
                        )
                        showAddAccountSheet = false
                        newAccountLabel = ""
                        newAccountAPIKey = ""
                    } catch {
                        showError = error.localizedDescription
                    }
                }
                .buttonStyle(GlassPillButtonStyle(prominent: true, tint: MenuBarTheme.accent))
                .disabled(newAccountAPIKey.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 320)
        .background(MenuBarTheme.bgSecondary)
    }

    @ViewBuilder
    private func providerField(label: String, placeholder: String, text: Binding<String>, isSecure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(MenuBarTheme.textTertiary)
            if isSecure {
                SecureField(placeholder, text: text)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
            } else {
                TextField(placeholder, text: text)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
            }
        }
    }

    private func clearAddProviderFields() {
        newProviderLabel = ""
        newProviderBaseURL = ""
        newProviderAccountLabel = ""
        newProviderAPIKey = ""
    }

    private func confirmBatchDelete() {
        let oauthIds = Array(selectedOAuthAccountIds)
        let compatibleItems = selectedCompatibleItems.compactMap { item -> (providerID: String, accountID: String)? in
            let parts = item.components(separatedBy: "::")
            guard parts.count == 2 else { return nil }
            return (providerID: parts[0], accountID: parts[1])
        }
        let total = oauthIds.count + compatibleItems.count

        let deletingActive = oauthIds.contains(store.activeAccount()?.accountId ?? "") ||
            compatibleItems.contains(where: {
                $0.providerID == store.config.active.providerId &&
                $0.accountID == store.config.active.accountId
            })

        let alert = NSAlert()
        alert.messageText = "删除 \(total) 个账号？"
        alert.informativeText = deletingActive
            ? "其中包含当前激活的账号，删除后将自动切换到其他账号。此操作不可撤销。"
            : "此操作不可撤销。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            try store.batchRemove(oauthAccountIds: oauthIds, compatibleItems: compatibleItems)
            isBatchDeleteMode = false
            selectedOAuthAccountIds.removeAll()
            selectedCompatibleItems.removeAll()
            showTransientSuccess("已删除 \(total) 个账号")
        } catch {
            showError = error.localizedDescription
        }
    }

    private func handleCodexRestart() {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: "com.openai.codex")
            .filter { !$0.isTerminated }
        guard !running.isEmpty else { showTransientSuccess(L.switchAppliedNextLaunch); return }
        let alert = NSAlert()
        alert.messageText = L.restartCodexTitle
        alert.informativeText = L.restartCodexInfo
        alert.alertStyle = .warning
        alert.addButton(withTitle: L.forceQuitAndReopen)
        alert.addButton(withTitle: L.forceQuitOnly)
        alert.addButton(withTitle: L.restartLater)
        switch alert.runModal() {
        case .alertFirstButtonReturn: forceQuitCodex(running, reopen: true); showTransientSuccess(L.switchAppliedAfterReopen)
        case .alertSecondButtonReturn: forceQuitCodex(running, reopen: false); showTransientSuccess(L.switchAppliedAfterQuit)
        default: showTransientSuccess(L.switchAppliedNextLaunch)
        }
    }

    // MARK: - Helpers

    private var summaryTitle: String {
        if let provider = store.activeProvider, provider.kind == .openAICompatible {
            if let account = store.activeProviderAccount {
                return "\(provider.label) · \(account.label)"
            }
            return provider.label
        }
        if let activeAccount { return activeAccount.email }
        return store.accounts.isEmpty ? L.noAccounts : L.noActiveAccount
    }

    private var summarySubtitle: String {
        activeAccount?.email ?? featuredAccount?.email ?? L.addAccountHint
    }

    private func displayName(for account: TokenAccount) -> String {
        account.organizationName ?? String(account.accountId.prefix(8))
    }

    private func localizedStatusText(for account: TokenAccount) -> String {
        if account.tokenExpired { return L.reauth }
        switch account.usageStatus {
        case .ok: return L.statusOk
        case .warning: return L.statusWarning
        case .exceeded: return L.statusExceeded
        case .banned: return L.statusBanned
        }
    }

    private func toggleLanguage() {
        switch L.languageOverride {
        case nil: L.languageOverride = true
        case true: L.languageOverride = false
        case false: L.languageOverride = nil
        }
        languageToggle.toggle()
    }

    private func exportAccounts() {
        // TODO: export via new config format
    }

    private func importAccounts() {
        // TODO: import via new config format
    }

    private func defaultBackupFileName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "codexbar-accounts-\(formatter.string(from: Date())).json"
    }

    private func relativeTime(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return L.justUpdated }
        if seconds < 3600 { return L.minutesAgo(seconds / 60) }
        return L.hoursAgo(seconds / 3600)
    }

    private func activateAccount(_ account: TokenAccount) {
        do {
            try store.activate(account)
            showError = nil
            handleCodexRestart()
        } catch {
            showSuccess = nil; showError = error.localizedDescription
        }
    }

    private func showTransientSuccess(_ message: String) {
        successMessageVersion += 1
        let version = successMessageVersion
        showSuccess = message
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard version == successMessageVersion else { return }
            showSuccess = nil
        }
    }

    private func autoSwitchIfNeeded() {
        guard let active = store.accounts.first(where: { $0.isActive }) else { return }
        let primary5hRem = active.hasPrimaryWindow ? 100.0 - active.primaryUsedPercent : nil
        let secondary7dRem = active.hasSecondaryWindow ? 100.0 - active.secondaryUsedPercent : nil
        let shouldSwitch = (primary5hRem ?? 100.0) <= 10.0 || (secondary7dRem ?? 100.0) <= 3.0
        guard shouldSwitch else { return }
        let candidates = store.accounts.filter { !$0.isSuspended && !$0.tokenExpired && $0.accountId != active.accountId }
            .sorted { (lhs, rhs) -> Bool in
                let remL = lhs.mostConstrainedRemainingPercent
                let remR = rhs.mostConstrainedRemainingPercent
                if remL != remR { return remL > remR }
                let bestL = lhs.bestAvailableRemainingPercent
                let bestR = rhs.bestAvailableRemainingPercent
                if bestL != bestR { return bestL > bestR }
                return lhs.accountId < rhs.accountId
            }
        guard let best = candidates.first else { sendNotification(title: L.autoSwitchTitle, body: L.autoSwitchNoCandidates); return }
        do { try store.activate(best); sendAutoSwitchNotification(from: active, to: best) } catch {}
    }

    private func sendAutoSwitchNotification(from old: TokenAccount, to new: TokenAccount) {
        sendNotification(title: L.autoSwitchTitle, body: L.autoSwitchBody(old.organizationName ?? old.email, new.organizationName ?? new.email))
    }

    private func sendNotification(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title; content.body = body; content.sound = .default
            let request = UNNotificationRequest(identifier: "codexbar-\(Date().timeIntervalSince1970)", content: content, trigger: nil)
            center.add(request)
        }
    }

    private func forceQuitCodex(_ running: [NSRunningApplication], reopen: Bool) {
        let ws = NSWorkspace.shared
        if reopen {
            guard let url = ws.urlForApplication(withBundleIdentifier: "com.openai.codex") else { running.forEach { $0.forceTerminate() }; return }
            final class ObserverBox { var value: NSObjectProtocol? }
            let observerBox = ObserverBox()
            observerBox.value = ws.notificationCenter.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { note in
                guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication, app.bundleIdentifier == "com.openai.codex" else { return }
                if let observer = observerBox.value { ws.notificationCenter.removeObserver(observer); observerBox.value = nil }
                ws.open(url)
            }
        }
        running.forEach { $0.forceTerminate() }
    }

    private func refresh() async { isRefreshing = true; await WhamService.shared.refreshAll(store: store); isRefreshing = false }
    private func refreshAccount(_ account: TokenAccount) async { refreshingAccounts.insert(account.id); await WhamService.shared.refreshOne(account: account, store: store); refreshingAccounts.remove(account.id) }
    private func reauthAccount(_ account: TokenAccount) {
        oauth.startOAuth { result in
            switch result {
            case .success(let tokens):
                var updated = AccountBuilder.build(from: tokens)
                if updated.accountId == account.accountId { updated.isActive = account.isActive; updated.tokenExpired = false; updated.isSuspended = false }
                store.addOrUpdate(updated); Task { await WhamService.shared.refreshOne(account: updated, store: store) }
            case .failure(let error): showError = error.localizedDescription
            }
        }
    }

    private func statusRank(_ a: TokenAccount) -> Int {
        switch a.usageStatus {
        case .ok: return 0
        case .warning: return 1
        case .exceeded: return 2
        case .banned: return 3
        }
    }
}
