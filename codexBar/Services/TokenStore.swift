import Combine
import Foundation

struct AccountImportSummary {
    let importedCount: Int
    let skippedCount: Int
}

// MARK: - TokenPool (legacy backup format compat)

struct TokenPool: Codable {
    var accounts: [LegacyTokenAccount]

    init(accounts: [LegacyTokenAccount] = []) {
        self.accounts = accounts
    }
}

/// Legacy backup-file format — only used for import/export JSON compatibility.
struct LegacyTokenAccount: Codable {
    var email: String
    var accountId: String
    var accessToken: String
    var refreshToken: String
    var idToken: String
    var expiresAt: Date?
    var planType: String
    var primaryUsedPercent: Double
    var secondaryUsedPercent: Double
    var primaryResetAt: Date?
    var secondaryResetAt: Date?
    var hasPrimaryWindow: Bool
    var hasSecondaryWindow: Bool
    var lastChecked: Date?
    var isActive: Bool
    var isSuspended: Bool
    var tokenExpired: Bool
    var organizationName: String?

    enum CodingKeys: String, CodingKey {
        case email
        case accountId = "account_id"
        case organizationName = "organization_name"
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case expiresAt = "expires_at"
        case planType = "plan_type"
        case primaryUsedPercent = "primary_used_percent"
        case secondaryUsedPercent = "secondary_used_percent"
        case primaryResetAt = "primary_reset_at"
        case secondaryResetAt = "secondary_reset_at"
        case hasPrimaryWindow = "has_primary_window"
        case hasSecondaryWindow = "has_secondary_window"
        case lastChecked = "last_checked"
        case isActive = "is_active"
        case isSuspended = "is_suspended"
        case tokenExpired = "token_expired"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        email = try c.decode(String.self, forKey: .email)
        accountId = try c.decode(String.self, forKey: .accountId)
        accessToken = try c.decode(String.self, forKey: .accessToken)
        refreshToken = try c.decode(String.self, forKey: .refreshToken)
        idToken = try c.decode(String.self, forKey: .idToken)
        expiresAt = try c.decodeIfPresent(Date.self, forKey: .expiresAt)
        planType = try c.decodeIfPresent(String.self, forKey: .planType) ?? "free"
        primaryUsedPercent = try c.decodeIfPresent(Double.self, forKey: .primaryUsedPercent) ?? 0
        secondaryUsedPercent = try c.decodeIfPresent(Double.self, forKey: .secondaryUsedPercent) ?? 0
        primaryResetAt = try c.decodeIfPresent(Date.self, forKey: .primaryResetAt)
        secondaryResetAt = try c.decodeIfPresent(Date.self, forKey: .secondaryResetAt)
        hasPrimaryWindow = try c.decodeIfPresent(Bool.self, forKey: .hasPrimaryWindow)
            ?? (primaryResetAt != nil || primaryUsedPercent > 0)
        hasSecondaryWindow = try c.decodeIfPresent(Bool.self, forKey: .hasSecondaryWindow)
            ?? (secondaryResetAt != nil || secondaryUsedPercent > 0)
        lastChecked = try c.decodeIfPresent(Date.self, forKey: .lastChecked)
        isActive = try c.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
        isSuspended = try c.decodeIfPresent(Bool.self, forKey: .isSuspended) ?? false
        tokenExpired = try c.decodeIfPresent(Bool.self, forKey: .tokenExpired) ?? false
        organizationName = try c.decodeIfPresent(String.self, forKey: .organizationName)
    }

    init(email: String, accountId: String, accessToken: String, refreshToken: String,
         idToken: String, expiresAt: Date? = nil, planType: String = "free",
         primaryUsedPercent: Double = 0, secondaryUsedPercent: Double = 0,
         primaryResetAt: Date? = nil, secondaryResetAt: Date? = nil,
         hasPrimaryWindow: Bool = false, hasSecondaryWindow: Bool = false,
         lastChecked: Date? = nil, isActive: Bool = false,
         isSuspended: Bool = false, tokenExpired: Bool = false,
         organizationName: String? = nil) {
        self.email = email
        self.accountId = accountId
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.idToken = idToken
        self.expiresAt = expiresAt
        self.planType = planType
        self.primaryUsedPercent = primaryUsedPercent
        self.secondaryUsedPercent = secondaryUsedPercent
        self.primaryResetAt = primaryResetAt
        self.secondaryResetAt = secondaryResetAt
        self.hasPrimaryWindow = hasPrimaryWindow || primaryResetAt != nil || primaryUsedPercent > 0
        self.hasSecondaryWindow = hasSecondaryWindow || secondaryResetAt != nil || secondaryUsedPercent > 0
        self.lastChecked = lastChecked
        self.isActive = isActive
        self.isSuspended = isSuspended
        self.tokenExpired = tokenExpired
        self.organizationName = organizationName
    }

    var asProviderAccount: CodexBarProviderAccount {
        CodexBarProviderAccount(
            id: accountId,
            kind: .oauthTokens,
            label: email.isEmpty ? accountId : email,
            email: email,
            openAIAccountId: accountId,
            accessToken: accessToken,
            refreshToken: refreshToken,
            idToken: idToken,
            addedAt: expiresAt,
            planType: planType,
            primaryUsedPercent: primaryUsedPercent,
            secondaryUsedPercent: secondaryUsedPercent,
            primaryResetAt: primaryResetAt,
            secondaryResetAt: secondaryResetAt,
            hasPrimaryWindow: hasPrimaryWindow,
            hasSecondaryWindow: hasSecondaryWindow,
            lastChecked: lastChecked,
            isSuspended: isSuspended,
            tokenExpired: tokenExpired,
            organizationName: organizationName
        )
    }
}

// MARK: - TokenStore

final class TokenStore: ObservableObject {
    static let shared = TokenStore()

    /// OAuth 账号列表（视图层使用，含 isActive 运行时标记）
    @Published var oauthAccounts: [CodexBarProviderAccount] = []
    /// 完整配置（provider 切换使用）
    @Published private(set) var config: CodexBarConfig

    private let configStore = CodexBarConfigStore()
    private let syncService = CodexSyncService()
    private let backupDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
    private let backupEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private init() {
        if let loaded = try? configStore.loadOrMigrate() {
            config = loaded
        } else {
            config = CodexBarConfig()
        }
        publishState()
        try? syncService.synchronize(config: config)
    }

    // MARK: - Public: Provider 信息

    var activeProvider: CodexBarProvider? { config.activeProvider() }
    var activeProviderAccount: CodexBarProviderAccount? { config.activeAccount() }
    var customProviders: [CodexBarProvider] { config.providers.filter { $0.kind == .openAICompatible } }

    // MARK: - Public: OAuth 账号操作

    func addOrUpdate(_ account: CodexBarProviderAccount) {
        guard account.kind == .oauthTokens else { return }
        var provider = ensureOAuthProvider()

        if let index = provider.accounts.firstIndex(where: { $0.id == account.id }) {
            var updated = account
            updated.addedAt = provider.accounts[index].addedAt ?? Date()
            updated.label = provider.accounts[index].label
            updated.isActive = false // isActive is set at publish time
            provider.accounts[index] = updated
        } else {
            var toInsert = account
            toInsert.isActive = false
            provider.accounts.append(toInsert)
            if provider.activeAccountId == nil { provider.activeAccountId = account.id }
        }
        upsertProvider(provider)

        let shouldSync = config.active.providerId == provider.id
        persistIgnoringErrors(syncCodex: shouldSync)
    }

    func remove(_ account: CodexBarProviderAccount) {
        guard let oauthId = account.openAIAccountId,
              var provider = oauthProvider() else { return }
        provider.accounts.removeAll { $0.openAIAccountId == oauthId }
        removeOrUpdateProvider(&provider, wasActive: config.active.providerId == provider.id)
        persistIgnoringErrors(syncCodex: config.active.providerId == provider.id || config.activeProvider() != nil)
    }

    func activate(_ account: CodexBarProviderAccount) throws {
        guard account.kind == .oauthTokens,
              var provider = oauthProvider(),
              let stored = provider.accounts.first(where: { $0.openAIAccountId == account.openAIAccountId }) else {
            throw TokenStoreError.accountNotFound
        }
        provider.activeAccountId = stored.id
        upsertProvider(provider)
        config.active.providerId = provider.id
        config.active.accountId = stored.id
        try persist(syncCodex: true)
    }

    func activeAccount() -> CodexBarProviderAccount? {
        oauthAccounts.first(where: { $0.isActive })
    }

    func markActiveAccount() { publishState() }

    func exportAccounts(to url: URL) throws {
        do {
            let data = try encodedOAuthBackupData()
            try data.write(to: url, options: .atomic)
        } catch {
            throw TokenStoreError.writeFailed
        }
    }

    func importAccounts(from url: URL) throws -> AccountImportSummary {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw TokenStoreError.readFailed
        }

        let importedPool: TokenPool
        do {
            importedPool = try backupDecoder.decode(TokenPool.self, from: data)
        } catch {
            throw TokenStoreError.invalidFormat
        }

        var provider = oauthProvider()
            ?? CodexBarProvider(id: "openai-oauth", kind: .openAIOAuth, label: "OpenAI", enabled: true)
        var seenAccountIDs = Set(provider.accounts.map(\.id))
        var importedAccounts: [CodexBarProviderAccount] = []
        var skippedCount = 0

        for legacy in importedPool.accounts {
            let trimmedId = legacy.accountId.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedId.isEmpty else { throw TokenStoreError.invalidFormat }
            let account = legacy.asProviderAccount
            guard !seenAccountIDs.contains(account.id) else { skippedCount += 1; continue }
            seenAccountIDs.insert(account.id)
            importedAccounts.append(account)
        }

        guard !importedAccounts.isEmpty else { throw TokenStoreError.noImportableAccounts }

        let previousConfig = config
        provider.accounts.append(contentsOf: importedAccounts)
        if provider.activeAccountId == nil {
            provider.activeAccountId = preferredOAuthAccountID(in: provider)
        }
        upsertProvider(provider)

        if config.active.providerId == nil || config.provider(id: config.active.providerId) == nil {
            config.active.providerId = provider.id
            config.active.accountId = preferredOAuthAccountID(in: provider)
        } else if config.active.providerId == provider.id,
                  let activeAccountId = config.active.accountId,
                  !provider.accounts.contains(where: { $0.id == activeAccountId }) {
            config.active.accountId = preferredOAuthAccountID(in: provider)
        }

        do {
            try persist(syncCodex: config.active.providerId == provider.id)
        } catch {
            config = previousConfig
            try? configStore.save(previousConfig)
            publishState()
            throw TokenStoreError.writeFailed
        }

        return AccountImportSummary(importedCount: importedAccounts.count, skippedCount: skippedCount)
    }

    // MARK: - Public: Custom Provider 操作

    func activateCustomProvider(providerID: String, accountID: String) throws {
        guard var provider = config.providers.first(where: { $0.id == providerID && $0.kind == .openAICompatible }) else {
            throw TokenStoreError.providerNotFound
        }
        guard provider.accounts.contains(where: { $0.id == accountID }) else {
            throw TokenStoreError.accountNotFound
        }
        provider.activeAccountId = accountID
        upsertProvider(provider)
        config.active.providerId = provider.id
        config.active.accountId = accountID
        try persist(syncCodex: true)
    }

    func addCustomProvider(label: String, baseURL: String, accountLabel: String, apiKey: String) throws {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLabel.isEmpty, !trimmedBaseURL.isEmpty, !trimmedAPIKey.isEmpty else {
            throw TokenStoreError.invalidInput
        }

        let providerID = slug(from: trimmedLabel)
        let trimmedAccountLabel = accountLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let account = CodexBarProviderAccount(
            kind: .apiKey,
            label: trimmedAccountLabel.isEmpty ? "Default" : trimmedAccountLabel,
            apiKey: trimmedAPIKey,
            addedAt: Date()
        )
        let provider = CodexBarProvider(
            id: providerID,
            kind: .openAICompatible,
            label: trimmedLabel,
            enabled: true,
            baseURL: trimmedBaseURL,
            activeAccountId: account.id,
            accounts: [account]
        )
        config.providers.removeAll { $0.id == provider.id }
        config.providers.append(provider)
        config.active.providerId = provider.id
        config.active.accountId = account.id
        try persist(syncCodex: true)
    }

    func addCustomProviderAccount(providerID: String, label: String, apiKey: String) throws {
        guard var provider = config.providers.first(where: { $0.id == providerID && $0.kind == .openAICompatible }) else {
            throw TokenStoreError.providerNotFound
        }
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAPIKey.isEmpty else { throw TokenStoreError.invalidInput }

        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let account = CodexBarProviderAccount(
            kind: .apiKey,
            label: trimmedLabel.isEmpty ? "Account \(provider.accounts.count + 1)" : trimmedLabel,
            apiKey: trimmedAPIKey,
            addedAt: Date()
        )
        provider.accounts.append(account)
        if provider.activeAccountId == nil { provider.activeAccountId = account.id }
        upsertProvider(provider)
        try persist(syncCodex: false)
    }

    func removeCustomProviderAccount(providerID: String, accountID: String) throws {
        guard var provider = config.providers.first(where: { $0.id == providerID && $0.kind == .openAICompatible }) else {
            throw TokenStoreError.providerNotFound
        }
        provider.accounts.removeAll { $0.id == accountID }

        let wasActive = config.active.providerId == providerID && config.active.accountId == accountID
        removeOrUpdateProvider(&provider, wasActive: wasActive)

        if !provider.accounts.isEmpty && wasActive {
            config.active.accountId = provider.activeAccountId
            try persist(syncCodex: true)
        } else {
            try persist(syncCodex: false)
        }
    }

    func removeCustomProvider(providerID: String) throws {
        config.providers.removeAll { $0.id == providerID }
        if config.active.providerId == providerID {
            applyFallbackActive()
            try persist(syncCodex: config.activeProvider() != nil)
        } else {
            try persist(syncCodex: false)
        }
    }

    // MARK: - Public: 批量删除

    func batchRemove(oauthAccountIds: [String], compatibleItems: [(providerID: String, accountID: String)]) throws {
        if !oauthAccountIds.isEmpty, var provider = oauthProvider() {
            provider.accounts.removeAll { acct in
                guard let id = acct.openAIAccountId else { return false }
                return oauthAccountIds.contains(id)
            }
            recalculateActiveIfNeeded(for: &provider)
            if provider.accounts.isEmpty {
                config.providers.removeAll { $0.id == provider.id }
                if config.active.providerId == provider.id { applyFallbackActive() }
            } else {
                upsertProvider(provider)
            }
        }

        for item in compatibleItems {
            guard var provider = config.providers.first(where: { $0.id == item.providerID }) else { continue }
            provider.accounts.removeAll { $0.id == item.accountID }
            recalculateActiveIfNeeded(for: &provider)
            if provider.accounts.isEmpty {
                config.providers.removeAll { $0.id == item.providerID }
                if config.active.providerId == item.providerID { applyFallbackActive() }
            } else {
                upsertProvider(provider)
            }
        }

        try persist(syncCodex: config.activeProvider() != nil)
    }

    // MARK: - Private: Provider Helpers

    private func oauthProvider() -> CodexBarProvider? {
        config.providers.first(where: { $0.kind == .openAIOAuth })
    }

    private func ensureOAuthProvider() -> CodexBarProvider {
        if let provider = oauthProvider() { return provider }
        let provider = CodexBarProvider(id: "openai-oauth", kind: .openAIOAuth, label: "OpenAI", enabled: true)
        config.providers.append(provider)
        return provider
    }

    private func upsertProvider(_ provider: CodexBarProvider) {
        if let index = config.providers.firstIndex(where: { $0.id == provider.id }) {
            config.providers[index] = provider
        } else {
            config.providers.append(provider)
        }
    }

    /// 从 providers 中移除空 provider，或在账号被删后更新 activeAccountId
    private func removeOrUpdateProvider(_ provider: inout CodexBarProvider, wasActive: Bool) {
        if provider.accounts.isEmpty {
            config.providers.removeAll { $0.id == provider.id }
            if config.active.providerId == provider.id { applyFallbackActive() }
        } else {
            recalculateActiveIfNeeded(for: &provider)
            upsertProvider(provider)
        }
    }

    /// 若 provider 的 activeAccountId 被删了，重置为第一个账号
    private func recalculateActiveIfNeeded(for provider: inout CodexBarProvider) {
        if let activeId = provider.activeAccountId,
           !provider.accounts.contains(where: { $0.id == activeId }) {
            provider.activeAccountId = provider.accounts.first?.id
        }
        if config.active.providerId == provider.id,
           let activeAccountId = config.active.accountId,
           !provider.accounts.contains(where: { $0.id == activeAccountId }) {
            config.active.accountId = provider.activeAccountId
        }
    }

    /// 切换 active 到第一个可用的 provider/account
    private func applyFallbackActive() {
        let fallback = oauthProvider() ?? config.providers.first
        config.active.providerId = fallback?.id
        config.active.accountId = fallback?.activeAccount?.id
    }

    // MARK: - Private: Persist

    private func persist(syncCodex: Bool) throws {
        try configStore.save(config)
        if syncCodex { try syncService.synchronize(config: config) }
        publishState()
    }

    private func persistIgnoringErrors(syncCodex: Bool) {
        do { try persist(syncCodex: syncCodex) } catch { publishState() }
    }

    // MARK: - Private: Backup Export/Import

    private func encodedOAuthBackupData() throws -> Data {
        guard let provider = oauthProvider() else {
            return try backupEncoder.encode(TokenPool())
        }
        let isOAuthActive = config.active.providerId == provider.id
        let legacyAccounts: [LegacyTokenAccount] = provider.accounts.compactMap { stored in
            guard stored.kind == .oauthTokens,
                  let accountId = stored.openAIAccountId,
                  let accessToken = stored.accessToken,
                  let refreshToken = stored.refreshToken,
                  let idToken = stored.idToken else { return nil }
            return LegacyTokenAccount(
                email: stored.email ?? stored.label,
                accountId: accountId,
                accessToken: accessToken,
                refreshToken: refreshToken,
                idToken: idToken,
                planType: stored.planType ?? "free",
                primaryUsedPercent: stored.primaryUsedPercent ?? 0,
                secondaryUsedPercent: stored.secondaryUsedPercent ?? 0,
                primaryResetAt: stored.primaryResetAt,
                secondaryResetAt: stored.secondaryResetAt,
                hasPrimaryWindow: stored.effectiveHasPrimaryWindow,
                hasSecondaryWindow: stored.effectiveHasSecondaryWindow,
                lastChecked: stored.lastChecked,
                isActive: isOAuthActive && config.active.accountId == stored.id,
                isSuspended: stored.isSuspended ?? false,
                tokenExpired: stored.tokenExpired ?? false,
                organizationName: stored.organizationName
            )
        }
        return try backupEncoder.encode(TokenPool(accounts: legacyAccounts))
    }

    private func currentAuthAccountID() -> String? {
        guard let data = try? Data(contentsOf: CodexPaths.authURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = json["tokens"] as? [String: Any],
              let accountId = tokens["account_id"] as? String else { return nil }
        let trimmed = accountId.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func preferredOAuthAccountID(in provider: CodexBarProvider) -> String? {
        if let accountId = currentAuthAccountID(),
           let matched = provider.accounts.first(where: { $0.openAIAccountId == accountId }) {
            return matched.id
        }
        return provider.activeAccountId ?? provider.accounts.first?.id
    }

    // MARK: - Private: Publish

    private func publishState() {
        guard let provider = oauthProvider() else {
            oauthAccounts = []
            return
        }
        let isOAuthActive = config.active.providerId == provider.id
        oauthAccounts = provider.accounts.compactMap { stored in
            guard stored.kind == .oauthTokens else { return nil }
            var account = stored
            account.isActive = isOAuthActive && config.active.accountId == stored.id
            return account
        }.sorted { lhs, rhs in
            if lhs.isActive != rhs.isActive { return lhs.isActive }
            return (lhs.email ?? lhs.label) < (rhs.email ?? rhs.label)
        }
    }

    // MARK: - Private: Utilities

    private func slug(from label: String) -> String {
        let s = label.lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return s.isEmpty ? "provider-\(UUID().uuidString.lowercased())" : s
    }
}

// MARK: - Errors

enum TokenStoreError: LocalizedError {
    case accountNotFound
    case providerNotFound
    case invalidInput
    case readFailed
    case invalidFormat
    case writeFailed
    case noImportableAccounts

    var errorDescription: String? {
        switch self {
        case .accountNotFound:      return "未找到账号"
        case .providerNotFound:     return "未找到 provider"
        case .invalidInput:         return "输入无效"
        case .readFailed:           return L.backupReadFailed
        case .invalidFormat:        return L.backupInvalidFormat
        case .writeFailed:          return L.backupWriteFailed
        case .noImportableAccounts: return L.noImportableAccounts
        }
    }
}
