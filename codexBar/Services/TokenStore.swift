import Combine
import Foundation

final class TokenStore: ObservableObject {
    static let shared = TokenStore()

    // 对外接口：OAuth 账号视图层列表（供 WhamService、MenuBarView 使用）
    @Published var accounts: [TokenAccount] = []
    // 对外接口：完整配置（供 MenuBarView provider 切换使用）
    @Published private(set) var config: CodexBarConfig

    private let configStore = CodexBarConfigStore()
    private let syncService = CodexSyncService()

    private init() {
        if let loaded = try? self.configStore.loadOrMigrate() {
            self.config = loaded
        } else {
            self.config = CodexBarConfig()
        }
        self.publishState()
        try? self.syncService.synchronize(config: self.config)
    }

    // MARK: - Public: Provider 信息

    var activeProvider: CodexBarProvider? { self.config.activeProvider() }
    var activeProviderAccount: CodexBarProviderAccount? { self.config.activeAccount() }
    var customProviders: [CodexBarProvider] { self.config.providers.filter { $0.kind == .openAICompatible } }

    // MARK: - Public: OAuth 账号操作（保持原有接口）

    func addOrUpdate(_ account: TokenAccount) {
        var provider = self.ensureOAuthProvider()
        if let index = provider.accounts.firstIndex(where: { $0.openAIAccountId == account.accountId }) {
            let existing = provider.accounts[index]
            var updated = CodexBarProviderAccount.fromTokenAccount(account, existingID: existing.id)
            updated.addedAt = existing.addedAt ?? Date()
            updated.label = existing.label
            provider.accounts[index] = updated
        } else {
            provider.accounts.append(CodexBarProviderAccount.fromTokenAccount(account, existingID: account.accountId))
            if provider.activeAccountId == nil {
                provider.activeAccountId = account.accountId
            }
        }
        self.upsertProvider(provider)

        let shouldSync = self.config.active.providerId == provider.id
        self.persistIgnoringErrors(syncCodex: shouldSync)
    }

    func remove(_ account: TokenAccount) {
        guard var provider = self.oauthProvider() else { return }
        provider.accounts.removeAll { $0.openAIAccountId == account.accountId }

        if provider.accounts.isEmpty {
            self.config.providers.removeAll { $0.id == provider.id }
            if self.config.active.providerId == provider.id {
                let fallback = self.config.providers.first
                self.config.active.providerId = fallback?.id
                self.config.active.accountId = fallback?.activeAccount?.id
            }
        } else {
            if provider.activeAccountId == account.accountId {
                provider.activeAccountId = provider.accounts.first?.id
            }
            if self.config.active.providerId == provider.id && self.config.active.accountId == account.accountId {
                self.config.active.accountId = provider.activeAccountId
            }
            self.upsertProvider(provider)
        }
        self.persistIgnoringErrors(syncCodex: self.config.active.providerId == provider.id)
    }

    func activate(_ account: TokenAccount) throws {
        guard var provider = self.oauthProvider(),
              let stored = provider.accounts.first(where: { $0.openAIAccountId == account.accountId }) else {
            throw TokenStoreError.accountNotFound
        }
        provider.activeAccountId = stored.id
        self.upsertProvider(provider)
        self.config.active.providerId = provider.id
        self.config.active.accountId = stored.id
        try self.persist(syncCodex: true)
    }

    func activeAccount() -> TokenAccount? {
        self.accounts.first(where: { $0.isActive })
    }

    func markActiveAccount() {
        self.publishState()
    }

    // MARK: - Public: Custom Provider 操作

    func activateCustomProvider(providerID: String, accountID: String) throws {
        guard var provider = self.config.providers.first(where: { $0.id == providerID && $0.kind == .openAICompatible }) else {
            throw TokenStoreError.providerNotFound
        }
        guard provider.accounts.contains(where: { $0.id == accountID }) else {
            throw TokenStoreError.accountNotFound
        }
        provider.activeAccountId = accountID
        self.upsertProvider(provider)
        self.config.active.providerId = provider.id
        self.config.active.accountId = accountID
        try self.persist(syncCodex: true)
    }

    func addCustomProvider(label: String, baseURL: String, accountLabel: String, apiKey: String) throws {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLabel.isEmpty, !trimmedBaseURL.isEmpty, !trimmedAPIKey.isEmpty else {
            throw TokenStoreError.invalidInput
        }

        let providerID = self.slug(from: trimmedLabel)
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
        self.config.providers.removeAll { $0.id == provider.id }
        self.config.providers.append(provider)
        self.config.active.providerId = provider.id
        self.config.active.accountId = account.id
        try self.persist(syncCodex: true)
    }

    func addCustomProviderAccount(providerID: String, label: String, apiKey: String) throws {
        guard var provider = self.config.providers.first(where: { $0.id == providerID && $0.kind == .openAICompatible }) else {
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
        self.upsertProvider(provider)
        try self.persist(syncCodex: false)
    }

    func removeCustomProviderAccount(providerID: String, accountID: String) throws {
        guard var provider = self.config.providers.first(where: { $0.id == providerID && $0.kind == .openAICompatible }) else {
            throw TokenStoreError.providerNotFound
        }
        provider.accounts.removeAll { $0.id == accountID }
        if provider.accounts.isEmpty {
            self.config.providers.removeAll { $0.id == providerID }
            if self.config.active.providerId == providerID {
                let fallback = self.config.providers.first
                self.config.active.providerId = fallback?.id
                self.config.active.accountId = fallback?.activeAccount?.id
                try self.persist(syncCodex: fallback != nil)
                return
            }
        } else {
            if provider.activeAccountId == accountID { provider.activeAccountId = provider.accounts.first?.id }
            if self.config.active.providerId == providerID && self.config.active.accountId == accountID {
                self.upsertProvider(provider)
                self.config.active.accountId = provider.activeAccountId
                try self.persist(syncCodex: true)
                return
            }
            self.upsertProvider(provider)
        }
        try self.persist(syncCodex: false)
    }

    func removeCustomProvider(providerID: String) throws {
        self.config.providers.removeAll { $0.id == providerID }
        if self.config.active.providerId == providerID {
            let fallback = self.oauthProvider() ?? self.customProviders.first
            self.config.active.providerId = fallback?.id
            self.config.active.accountId = fallback?.activeAccount?.id
            try self.persist(syncCodex: fallback != nil)
            return
        }
        try self.persist(syncCodex: false)
    }

    // MARK: - Public: 批量删除

    func batchRemove(oauthAccountIds: [String], compatibleItems: [(providerID: String, accountID: String)]) throws {
        // 删除 OAuth 账号
        if !oauthAccountIds.isEmpty, var provider = self.oauthProvider() {
            provider.accounts.removeAll { acct in
                guard let id = acct.openAIAccountId else { return false }
                return oauthAccountIds.contains(id)
            }
            if provider.accounts.isEmpty {
                self.config.providers.removeAll { $0.id == provider.id }
                if self.config.active.providerId == provider.id {
                    let fallback = self.config.providers.first
                    self.config.active.providerId = fallback?.id
                    self.config.active.accountId = fallback?.activeAccount?.id
                }
            } else {
                if let activeId = provider.activeAccountId,
                   !provider.accounts.contains(where: { $0.id == activeId }) {
                    provider.activeAccountId = provider.accounts.first?.id
                }
                if self.config.active.providerId == provider.id,
                   let activeAccountId = self.config.active.accountId,
                   !provider.accounts.contains(where: { $0.id == activeAccountId }) {
                    self.config.active.accountId = provider.activeAccountId
                }
                self.upsertProvider(provider)
            }
        }

        // 删除 compatible accounts
        for item in compatibleItems {
            if var provider = self.config.providers.first(where: { $0.id == item.providerID }) {
                provider.accounts.removeAll { $0.id == item.accountID }
                if provider.accounts.isEmpty {
                    self.config.providers.removeAll { $0.id == item.providerID }
                    if self.config.active.providerId == item.providerID {
                        let fallback = self.oauthProvider() ?? self.customProviders.first
                        self.config.active.providerId = fallback?.id
                        self.config.active.accountId = fallback?.activeAccount?.id
                    }
                } else {
                    if provider.activeAccountId == item.accountID {
                        provider.activeAccountId = provider.accounts.first?.id
                    }
                    if self.config.active.providerId == item.providerID && self.config.active.accountId == item.accountID {
                        self.config.active.accountId = provider.activeAccountId
                    }
                    self.upsertProvider(provider)
                }
            }
        }

        let shouldSync = self.config.activeProvider() != nil
        try self.persist(syncCodex: shouldSync)
    }

    // MARK: - Private

    private func oauthProvider() -> CodexBarProvider? {
        self.config.providers.first(where: { $0.kind == .openAIOAuth })
    }

    private func ensureOAuthProvider() -> CodexBarProvider {
        if let provider = self.oauthProvider() { return provider }
        let provider = CodexBarProvider(id: "openai-oauth", kind: .openAIOAuth, label: "OpenAI", enabled: true)
        self.config.providers.append(provider)
        return provider
    }

    private func upsertProvider(_ provider: CodexBarProvider) {
        if let index = self.config.providers.firstIndex(where: { $0.id == provider.id }) {
            self.config.providers[index] = provider
        } else {
            self.config.providers.append(provider)
        }
    }

    private func persist(syncCodex: Bool) throws {
        try self.configStore.save(self.config)
        if syncCodex { try self.syncService.synchronize(config: self.config) }
        self.publishState()
    }

    private func persistIgnoringErrors(syncCodex: Bool) {
        do { try self.persist(syncCodex: syncCodex) } catch { self.publishState() }
    }

    private func publishState() {
        guard let provider = self.oauthProvider() else {
            self.accounts = []
            return
        }
        let isOAuthActive = self.config.active.providerId == provider.id
        self.accounts = provider.accounts.compactMap { stored in
            stored.asTokenAccount(isActive: isOAuthActive && self.config.active.accountId == stored.id)
        }.sorted { lhs, rhs in
            if lhs.isActive != rhs.isActive { return lhs.isActive }
            return lhs.email < rhs.email
        }
    }

    private func slug(from label: String) -> String {
        let lowered = label.lowercased()
        let s = lowered.replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return s.isEmpty ? "provider-\(UUID().uuidString.lowercased())" : s
    }
}

enum TokenStoreError: LocalizedError {
    case accountNotFound
    case providerNotFound
    case invalidInput

    var errorDescription: String? {
        switch self {
        case .accountNotFound: return "未找到账号"
        case .providerNotFound: return "未找到 provider"
        case .invalidInput: return "输入无效"
        }
    }
}
