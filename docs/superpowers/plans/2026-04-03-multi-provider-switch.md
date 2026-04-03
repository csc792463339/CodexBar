# Multi-Provider 切换 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 CodexBar 添加 multi-provider 切换支持（OpenAI OAuth + OpenAI Compatible），不破坏 `~/.codex/sessions` 历史记录，并自动迁移现有账号数据。

**Architecture:** 从参考项目移植 `CodexBarConfig`（数据模型）、`CodexPaths`（路径管理）、`CodexBarConfigStore`（持久化+迁移）、`CodexSyncService`（同步写 Codex 配置文件）四个服务，重写 `TokenStore` 为委托这四个服务的薄层，在 `MenuBarView` 中新增 provider 切换区域和批量删除模式。

**Tech Stack:** Swift 5.9, SwiftUI, macOS 13+, AppKit (NSAlert)

---

## 文件结构

| 操作 | 文件路径 | 职责 |
|---|---|---|
| 新增 | `codexBar/Models/CodexBarConfig.swift` | 所有数据模型 |
| 新增 | `codexBar/Services/CodexPaths.swift` | 路径常量 + 安全写入 |
| 新增 | `codexBar/Services/CodexBarConfigStore.swift` | 持久化 + 自动迁移 |
| 新增 | `codexBar/Services/CodexSyncService.swift` | 同步写 auth.json + config.toml |
| 新增 | `codexBar/Views/CompatibleProviderRowView.swift` | Compatible provider UI 行 |
| 修改 | `codexBar/Services/TokenStore.swift` | 重写为委托模式 |
| 修改 | `codexBar/Views/MenuBarView.swift` | 新增 provider 切换 + 批量删除 UI |

---

## Task 1: 新增 CodexBarConfig 数据模型

**Files:**
- Create: `codexBar/Models/CodexBarConfig.swift`

- [ ] **Step 1: 创建数据模型文件**

```swift
// codexBar/Models/CodexBarConfig.swift
import Foundation

enum CodexBarProviderKind: String, Codable {
    case openAIOAuth = "openai_oauth"
    case openAICompatible = "openai_compatible"
}

enum CodexBarAccountKind: String, Codable {
    case oauthTokens = "oauth_tokens"
    case apiKey = "api_key"
}

struct CodexBarGlobalSettings: Codable {
    var defaultModel: String
    var reviewModel: String
    var reasoningEffort: String

    init(defaultModel: String = "gpt-4.1", reviewModel: String = "gpt-4.1", reasoningEffort: String = "high") {
        self.defaultModel = defaultModel
        self.reviewModel = reviewModel
        self.reasoningEffort = reasoningEffort
    }
}

struct CodexBarActiveSelection: Codable {
    var providerId: String?
    var accountId: String?
}

struct CodexBarProviderAccount: Codable, Identifiable, Equatable {
    var id: String
    var kind: CodexBarAccountKind
    var label: String

    var email: String?
    var openAIAccountId: String?
    var accessToken: String?
    var refreshToken: String?
    var idToken: String?
    var lastRefresh: Date?

    var apiKey: String?
    var addedAt: Date?

    var planType: String?
    var primaryUsedPercent: Double?
    var secondaryUsedPercent: Double?
    var primaryResetAt: Date?
    var secondaryResetAt: Date?
    var lastChecked: Date?
    var isSuspended: Bool?
    var tokenExpired: Bool?
    var organizationName: String?

    init(
        id: String = UUID().uuidString,
        kind: CodexBarAccountKind,
        label: String,
        email: String? = nil,
        openAIAccountId: String? = nil,
        accessToken: String? = nil,
        refreshToken: String? = nil,
        idToken: String? = nil,
        lastRefresh: Date? = nil,
        apiKey: String? = nil,
        addedAt: Date? = nil,
        planType: String? = nil,
        primaryUsedPercent: Double? = nil,
        secondaryUsedPercent: Double? = nil,
        primaryResetAt: Date? = nil,
        secondaryResetAt: Date? = nil,
        lastChecked: Date? = nil,
        isSuspended: Bool? = nil,
        tokenExpired: Bool? = nil,
        organizationName: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.label = label
        self.email = email
        self.openAIAccountId = openAIAccountId
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.idToken = idToken
        self.lastRefresh = lastRefresh
        self.apiKey = apiKey
        self.addedAt = addedAt
        self.planType = planType
        self.primaryUsedPercent = primaryUsedPercent
        self.secondaryUsedPercent = secondaryUsedPercent
        self.primaryResetAt = primaryResetAt
        self.secondaryResetAt = secondaryResetAt
        self.lastChecked = lastChecked
        self.isSuspended = isSuspended
        self.tokenExpired = tokenExpired
        self.organizationName = organizationName
    }

    var maskedAPIKey: String {
        guard let apiKey, apiKey.count > 8 else { return apiKey ?? "" }
        return String(apiKey.prefix(6)) + "..." + String(apiKey.suffix(4))
    }

    func asTokenAccount(isActive: Bool) -> TokenAccount? {
        guard self.kind == .oauthTokens,
              let accountId = self.openAIAccountId,
              let accessToken = self.accessToken,
              let refreshToken = self.refreshToken,
              let idToken = self.idToken else { return nil }

        return TokenAccount(
            email: self.email ?? self.label,
            accountId: accountId,
            accessToken: accessToken,
            refreshToken: refreshToken,
            idToken: idToken,
            expiresAt: nil,
            planType: self.planType ?? "free",
            primaryUsedPercent: self.primaryUsedPercent ?? 0,
            secondaryUsedPercent: self.secondaryUsedPercent ?? 0,
            primaryResetAt: self.primaryResetAt,
            secondaryResetAt: self.secondaryResetAt,
            hasPrimaryWindow: self.primaryResetAt != nil || (self.primaryUsedPercent ?? 0) > 0,
            hasSecondaryWindow: self.secondaryResetAt != nil || (self.secondaryUsedPercent ?? 0) > 0,
            lastChecked: self.lastChecked,
            isActive: isActive,
            isSuspended: self.isSuspended ?? false,
            tokenExpired: self.tokenExpired ?? false,
            organizationName: self.organizationName
        )
    }

    static func fromTokenAccount(_ account: TokenAccount, existingID: String? = nil) -> CodexBarProviderAccount {
        CodexBarProviderAccount(
            id: existingID ?? account.accountId,
            kind: .oauthTokens,
            label: account.email.isEmpty ? account.accountId : account.email,
            email: account.email,
            openAIAccountId: account.accountId,
            accessToken: account.accessToken,
            refreshToken: account.refreshToken,
            idToken: account.idToken,
            lastRefresh: Date(),
            addedAt: Date(),
            planType: account.planType,
            primaryUsedPercent: account.primaryUsedPercent,
            secondaryUsedPercent: account.secondaryUsedPercent,
            primaryResetAt: account.primaryResetAt,
            secondaryResetAt: account.secondaryResetAt,
            lastChecked: account.lastChecked,
            isSuspended: account.isSuspended,
            tokenExpired: account.tokenExpired,
            organizationName: account.organizationName
        )
    }
}

struct CodexBarProvider: Codable, Identifiable, Equatable {
    var id: String
    var kind: CodexBarProviderKind
    var label: String
    var enabled: Bool
    var baseURL: String?
    var activeAccountId: String?
    var accounts: [CodexBarProviderAccount]

    init(
        id: String,
        kind: CodexBarProviderKind,
        label: String,
        enabled: Bool = true,
        baseURL: String? = nil,
        activeAccountId: String? = nil,
        accounts: [CodexBarProviderAccount] = []
    ) {
        self.id = id
        self.kind = kind
        self.label = label
        self.enabled = enabled
        self.baseURL = baseURL
        self.activeAccountId = activeAccountId
        self.accounts = accounts
    }

    var activeAccount: CodexBarProviderAccount? {
        if let activeAccountId, let found = self.accounts.first(where: { $0.id == activeAccountId }) {
            return found
        }
        return self.accounts.first
    }

    var hostLabel: String {
        guard let baseURL,
              let host = URL(string: baseURL)?.host,
              !host.isEmpty else { return self.label }
        return host
    }
}

struct CodexBarConfig: Codable {
    var version: Int
    var global: CodexBarGlobalSettings
    var active: CodexBarActiveSelection
    var providers: [CodexBarProvider]

    init(
        version: Int = 1,
        global: CodexBarGlobalSettings = CodexBarGlobalSettings(),
        active: CodexBarActiveSelection = CodexBarActiveSelection(),
        providers: [CodexBarProvider] = []
    ) {
        self.version = version
        self.global = global
        self.active = active
        self.providers = providers
    }

    func provider(id: String?) -> CodexBarProvider? {
        guard let id else { return nil }
        return self.providers.first(where: { $0.id == id })
    }

    func activeProvider() -> CodexBarProvider? {
        self.provider(id: self.active.providerId)
    }

    func activeAccount() -> CodexBarProviderAccount? {
        self.activeProvider()?.accounts.first(where: { $0.id == self.active.accountId })
            ?? self.activeProvider()?.activeAccount
    }

    func oauthProvider() -> CodexBarProvider? {
        self.providers.first(where: { $0.kind == .openAIOAuth })
    }
}
```

- [ ] **Step 2: 验证文件可编译（Xcode 中 Cmd+B 或命令行）**

在 Xcode 中打开项目，按 Cmd+B 确认无编译错误。

- [ ] **Step 3: Commit**

```bash
git add codexBar/Models/CodexBarConfig.swift
git commit -m "feat: add CodexBarConfig data models for multi-provider support"
```

---

## Task 2: 新增 CodexPaths 路径管理

**Files:**
- Create: `codexBar/Services/CodexPaths.swift`

- [ ] **Step 1: 创建路径管理文件**

```swift
// codexBar/Services/CodexPaths.swift
import Foundation

enum CodexPaths {
    static var realHome: URL {
        if let pw = getpwuid(getuid()), let pwDir = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: pwDir), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    static var codexRoot: URL {
        self.realHome.appendingPathComponent(".codex", isDirectory: true)
    }

    static var codexBarRoot: URL {
        self.realHome.appendingPathComponent(".codexbar", isDirectory: true)
    }

    static var authURL: URL { self.codexRoot.appendingPathComponent("auth.json") }
    static var tokenPoolURL: URL { self.codexRoot.appendingPathComponent("token_pool.json") }
    static var configTomlURL: URL { self.codexRoot.appendingPathComponent("config.toml") }

    static var barConfigURL: URL { self.codexBarRoot.appendingPathComponent("config.json") }

    static var configBackupURL: URL { self.codexRoot.appendingPathComponent("config.toml.bak-codexbar-last") }
    static var authBackupURL: URL { self.codexRoot.appendingPathComponent("auth.json.bak-codexbar-last") }

    static func ensureDirectories() throws {
        try FileManager.default.createDirectory(at: self.codexRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: self.codexBarRoot, withIntermediateDirectories: true)
    }

    static func writeSecureFile(_ data: Data, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let tempURL = directory.appendingPathComponent("." + url.lastPathComponent + "." + UUID().uuidString + ".tmp")
        try data.write(to: tempURL, options: .atomic)
        try self.applySecurePermissions(to: tempURL)

        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.moveItem(at: tempURL, to: url)
        try self.applySecurePermissions(to: url)
    }

    static func backupFileIfPresent(from source: URL, to destination: URL) throws {
        guard FileManager.default.fileExists(atPath: source.path) else { return }
        let data = try Data(contentsOf: source)
        try self.writeSecureFile(data, to: destination)
    }

    private static func applySecurePermissions(to url: URL) throws {
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o600))],
            ofItemAtPath: url.path
        )
    }
}
```

- [ ] **Step 2: Cmd+B 确认编译通过**

- [ ] **Step 3: Commit**

```bash
git add codexBar/Services/CodexPaths.swift
git commit -m "feat: add CodexPaths for unified path management and secure file writing"
```

---

## Task 3: 新增 CodexSyncService

**Files:**
- Create: `codexBar/Services/CodexSyncService.swift`

- [ ] **Step 1: 创建同步服务文件**

```swift
// codexBar/Services/CodexSyncService.swift
import Foundation

enum CodexSyncError: LocalizedError {
    case missingActiveProvider
    case missingActiveAccount
    case missingOAuthTokens
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case .missingActiveProvider: return "未找到当前激活的 provider"
        case .missingActiveAccount: return "未找到当前激活的账号"
        case .missingOAuthTokens: return "当前 OAuth 账号缺少必要 token"
        case .missingAPIKey: return "当前 API Key 账号缺少密钥"
        }
    }
}

struct CodexSyncService {
    func synchronize(config: CodexBarConfig) throws {
        guard let provider = config.activeProvider() else { throw CodexSyncError.missingActiveProvider }
        guard let account = config.activeAccount() else { throw CodexSyncError.missingActiveAccount }

        try CodexPaths.ensureDirectories()
        try CodexPaths.backupFileIfPresent(from: CodexPaths.configTomlURL, to: CodexPaths.configBackupURL)
        try CodexPaths.backupFileIfPresent(from: CodexPaths.authURL, to: CodexPaths.authBackupURL)

        let authData = try self.renderAuthJSON(provider: provider, account: account)
        try CodexPaths.writeSecureFile(authData, to: CodexPaths.authURL)

        let renderedToml = self.renderConfigTOML(
            existingText: (try? String(contentsOf: CodexPaths.configTomlURL, encoding: .utf8)) ?? "",
            global: config.global,
            provider: provider
        )
        guard let tomlData = renderedToml.data(using: .utf8) else { return }
        try CodexPaths.writeSecureFile(tomlData, to: CodexPaths.configTomlURL)
    }

    private func renderAuthJSON(provider: CodexBarProvider, account: CodexBarProviderAccount) throws -> Data {
        let object: [String: Any]
        switch provider.kind {
        case .openAIOAuth:
            guard let accessToken = account.accessToken,
                  let refreshToken = account.refreshToken,
                  let idToken = account.idToken,
                  let accountId = account.openAIAccountId else {
                throw CodexSyncError.missingOAuthTokens
            }
            object = [
                "auth_mode": "chatgpt",
                "OPENAI_API_KEY": NSNull(),
                "last_refresh": ISO8601DateFormatter().string(from: Date()),
                "tokens": [
                    "access_token": accessToken,
                    "refresh_token": refreshToken,
                    "id_token": idToken,
                    "account_id": accountId,
                ],
            ]

        case .openAICompatible:
            guard let apiKey = account.apiKey, apiKey.isEmpty == false else {
                throw CodexSyncError.missingAPIKey
            }
            object = [
                "OPENAI_API_KEY": apiKey,
            ]
        }

        return try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    }

    private func renderConfigTOML(
        existingText: String,
        global: CodexBarGlobalSettings,
        provider: CodexBarProvider
    ) -> String {
        var text = existingText

        text = self.upsertSetting(text, key: "model_provider", value: "\"openai\"")
        text = self.upsertSetting(text, key: "model", value: self.quote(global.defaultModel))
        text = self.upsertSetting(text, key: "review_model", value: self.quote(global.reviewModel))
        text = self.upsertSetting(text, key: "model_reasoning_effort", value: self.quote(global.reasoningEffort))

        text = self.removeSetting(text, key: "service_tier")
        text = self.removeSetting(text, key: "oss_provider")
        text = self.removeSetting(text, key: "openai_base_url")
        text = self.removeSetting(text, key: "model_catalog_json")
        text = self.removeSetting(text, key: "preferred_auth_method")
        text = self.removeBlock(text, key: "OpenAI")
        text = self.removeBlock(text, key: "openai")

        if provider.kind == .openAICompatible, let baseURL = provider.baseURL {
            text = self.upsertSetting(text, key: "openai_base_url", value: self.quote(baseURL))
        }

        return text.replacingOccurrences(of: "\n\n\n", with: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    private func quote(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private func upsertSetting(_ text: String, key: String, value: String) -> String {
        let line = "\(key) = \(value)"
        let pattern = #"(?m)^"# + NSRegularExpression.escapedPattern(for: key) + #"\s*=.*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        if regex.firstMatch(in: text, range: range) != nil {
            return regex.stringByReplacingMatches(in: text, range: range, withTemplate: line)
        }
        return line + "\n" + text
    }

    private func removeSetting(_ text: String, key: String) -> String {
        let pattern = #"(?m)^"# + NSRegularExpression.escapedPattern(for: key) + #"\s*=.*$\n?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    }

    private func removeBlock(_ text: String, key: String) -> String {
        let pattern = #"(?ms)^\[model_providers\."# + NSRegularExpression.escapedPattern(for: key) + #"\]\n.*?(?=^\[|\Z)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    }
}
```

- [ ] **Step 2: Cmd+B 确认编译通过**

- [ ] **Step 3: Commit**

```bash
git add codexBar/Services/CodexSyncService.swift
git commit -m "feat: add CodexSyncService to sync auth.json and config.toml on provider switch"
```

---

## Task 4: 新增 CodexBarConfigStore（含自动迁移）

**Files:**
- Create: `codexBar/Services/CodexBarConfigStore.swift`

- [ ] **Step 1: 创建配置存储和迁移文件**

```swift
// codexBar/Services/CodexBarConfigStore.swift
import Foundation

struct LegacyCodexTomlSnapshot {
    var model: String?
    var reviewModel: String?
    var reasoningEffort: String?
    var openAIBaseURL: String?
}

final class CodexBarConfigStore {
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    func loadOrMigrate() throws -> CodexBarConfig {
        try CodexPaths.ensureDirectories()
        if FileManager.default.fileExists(atPath: CodexPaths.barConfigURL.path) {
            do {
                return try self.load()
            } catch {
                try self.backupForeignConfig()
            }
        }
        let config = try self.migrateFromLegacy()
        try self.save(config)
        return config
    }

    func load() throws -> CodexBarConfig {
        let data = try Data(contentsOf: CodexPaths.barConfigURL)
        return try self.decoder.decode(CodexBarConfig.self, from: data)
    }

    func save(_ config: CodexBarConfig) throws {
        let data = try self.encoder.encode(config)
        try CodexPaths.writeSecureFile(data, to: CodexPaths.barConfigURL)
    }

    // MARK: - Migration

    private func migrateFromLegacy() throws -> CodexBarConfig {
        let toml = self.readLegacyToml()
        let auth = self.readAuthJSON()

        var providers: [CodexBarProvider] = []

        if let oauthProvider = self.makeOAuthProvider(auth: auth) {
            providers.append(oauthProvider)
        }

        if let authAPIKey = auth["OPENAI_API_KEY"] as? String,
           !authAPIKey.isEmpty,
           let imported = self.makeImportedProviderIfNeeded(
               baseURL: toml.openAIBaseURL,
               apiKey: authAPIKey,
               existingProviders: providers
           ) {
            providers.append(imported)
        }

        let global = CodexBarGlobalSettings(
            defaultModel: toml.model ?? "gpt-4.1",
            reviewModel: toml.reviewModel ?? toml.model ?? "gpt-4.1",
            reasoningEffort: toml.reasoningEffort ?? "high"
        )

        let active = self.resolveActiveSelection(toml: toml, auth: auth, providers: providers)

        return CodexBarConfig(version: 1, global: global, active: active, providers: providers)
    }

    private func makeOAuthProvider(auth: [String: Any]) -> CodexBarProvider? {
        var importedAccounts: [CodexBarProviderAccount] = []

        if let data = try? Data(contentsOf: CodexPaths.tokenPoolURL),
           let pool = try? self.decoder.decode(TokenPool.self, from: data) {
            importedAccounts = pool.accounts.map { account in
                CodexBarProviderAccount.fromTokenAccount(account, existingID: account.accountId)
            }
        }

        if let tokens = auth["tokens"] as? [String: Any],
           let imported = self.accountFromAuthTokens(tokens) {
            if importedAccounts.contains(where: { $0.openAIAccountId == imported.openAIAccountId }) == false {
                importedAccounts.append(imported)
            }
        }

        guard importedAccounts.isEmpty == false else { return nil }

        return CodexBarProvider(
            id: "openai-oauth",
            kind: .openAIOAuth,
            label: "OpenAI",
            enabled: true,
            baseURL: nil,
            activeAccountId: importedAccounts.first?.id,
            accounts: importedAccounts
        )
    }

    private func accountFromAuthTokens(_ tokens: [String: Any]) -> CodexBarProviderAccount? {
        guard let accessToken = tokens["access_token"] as? String,
              let refreshToken = tokens["refresh_token"] as? String,
              let idToken = tokens["id_token"] as? String,
              let accountId = tokens["account_id"] as? String else { return nil }

        let idClaims = AccountBuilder.decodeJWT(idToken)
        let email = idClaims["email"] as? String

        return CodexBarProviderAccount(
            id: accountId,
            kind: .oauthTokens,
            label: email ?? String(accountId.prefix(8)),
            email: email,
            openAIAccountId: accountId,
            accessToken: accessToken,
            refreshToken: refreshToken,
            idToken: idToken,
            addedAt: Date(),
            planType: "free"
        )
    }

    private func makeImportedProviderIfNeeded(
        baseURL: String?,
        apiKey: String,
        existingProviders: [CodexBarProvider]
    ) -> CodexBarProvider? {
        let normalizedBaseURL = baseURL ?? "https://api.openai.com/v1"
        if existingProviders.contains(where: { $0.baseURL == normalizedBaseURL }) { return nil }

        let label = URL(string: normalizedBaseURL)?.host ?? "Imported"
        let account = CodexBarProviderAccount(kind: .apiKey, label: "Imported", apiKey: apiKey, addedAt: Date())
        return CodexBarProvider(
            id: self.slug(from: label),
            kind: .openAICompatible,
            label: label,
            enabled: true,
            baseURL: normalizedBaseURL,
            activeAccountId: account.id,
            accounts: [account]
        )
    }

    private func resolveActiveSelection(
        toml: LegacyCodexTomlSnapshot,
        auth: [String: Any],
        providers: [CodexBarProvider]
    ) -> CodexBarActiveSelection {
        if let baseURL = toml.openAIBaseURL,
           let provider = providers.first(where: { $0.baseURL == baseURL }) {
            return CodexBarActiveSelection(providerId: provider.id, accountId: provider.activeAccount?.id)
        }

        if let tokens = auth["tokens"] as? [String: Any],
           let accountId = tokens["account_id"] as? String,
           let provider = providers.first(where: { $0.kind == .openAIOAuth }) {
            let selected = provider.accounts.first(where: { $0.openAIAccountId == accountId }) ?? provider.activeAccount
            return CodexBarActiveSelection(providerId: provider.id, accountId: selected?.id)
        }

        let fallback = providers.first
        return CodexBarActiveSelection(providerId: fallback?.id, accountId: fallback?.activeAccount?.id)
    }

    // MARK: - TOML / Auth Readers

    private func readLegacyToml() -> LegacyCodexTomlSnapshot {
        guard let text = try? String(contentsOf: CodexPaths.configTomlURL, encoding: .utf8) else {
            return LegacyCodexTomlSnapshot()
        }
        return LegacyCodexTomlSnapshot(
            model: self.matchValue(for: "model", in: text),
            reviewModel: self.matchValue(for: "review_model", in: text),
            reasoningEffort: self.matchValue(for: "model_reasoning_effort", in: text),
            openAIBaseURL: self.matchValue(for: "openai_base_url", in: text)
        )
    }

    private func matchValue(for key: String, in text: String) -> String? {
        let pattern = #"(?m)^"# + NSRegularExpression.escapedPattern(for: key) + #"\s*=\s*"([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let valueRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[valueRange])
    }

    private func readAuthJSON() -> [String: Any] {
        guard let data = try? Data(contentsOf: CodexPaths.authURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return object
    }

    private func backupForeignConfig() throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let stamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backupURL = CodexPaths.codexBarRoot.appendingPathComponent("config.foreign-backup-\(stamp).json")
        try CodexPaths.backupFileIfPresent(from: CodexPaths.barConfigURL, to: backupURL)
        try? FileManager.default.removeItem(at: CodexPaths.barConfigURL)
    }

    private func slug(from label: String) -> String {
        let lowered = label.lowercased()
        let slug = lowered.replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return slug.isEmpty ? "provider-\(UUID().uuidString.lowercased())" : slug
    }
}
```

- [ ] **Step 2: Cmd+B 确认编译通过**

- [ ] **Step 3: Commit**

```bash
git add codexBar/Services/CodexBarConfigStore.swift
git commit -m "feat: add CodexBarConfigStore with auto-migration from legacy token_pool.json"
```

---

## Task 5: 重写 TokenStore

**Files:**
- Modify: `codexBar/Services/TokenStore.swift`

> 注意：重写后对外接口 `@Published var accounts: [TokenAccount]`、`addOrUpdate(_:)`、`remove(_:)`、`activate(_:)` 保持不变，`WhamService` 和 `MenuBarView` 无需改动接口。

- [ ] **Step 1: 完全替换 TokenStore.swift 内容**

```swift
// codexBar/Services/TokenStore.swift
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

    /// 批量删除 OAuth 账号和 compatible accounts。
    /// - oauthAccountIds: TokenAccount.accountId 列表
    /// - compatibleItems: [(providerID, accountID)] 列表
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
```

- [ ] **Step 2: 删除旧 TokenStore 中对 `poolURL`、`authURL`、`exportAccounts`、`importAccounts` 等旧接口的依赖**

在 `MenuBarView.swift` 中，移除调用 `store.exportAccounts(to:)` 和 `store.importAccounts(from:)` 的按钮（或暂时注释掉），因为新的 TokenStore 不再包含这两个方法。后续 Task 7 会处理 UI。

- [ ] **Step 3: Cmd+B 确认编译通过，修复所有编译错误**

常见需要修复的编译错误：
- `MenuBarView` 中引用 `store.exportAccounts` / `store.importAccounts` → 暂时注释掉相关按钮
- `AuthSwitcher` 不再需要，可以保留不删除（不会引起冲突）

- [ ] **Step 4: Commit**

```bash
git add codexBar/Services/TokenStore.swift codexBar/Views/MenuBarView.swift
git commit -m "feat: rewrite TokenStore to delegate to CodexBarConfigStore and CodexSyncService"
```

---

## Task 6: 新增 CompatibleProviderRowView

**Files:**
- Create: `codexBar/Views/CompatibleProviderRowView.swift`

- [ ] **Step 1: 创建 Compatible Provider 行视图（适配当前 glass 主题）**

```swift
// codexBar/Views/CompatibleProviderRowView.swift
import SwiftUI

struct CompatibleProviderRowView: View {
    let provider: CodexBarProvider
    let isActiveProvider: Bool
    let activeAccountId: String?
    let onActivate: (CodexBarProviderAccount) -> Void
    let onAddAccount: () -> Void
    let onDeleteAccount: (CodexBarProviderAccount) -> Void
    let onDeleteProvider: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Provider Header
            HStack(spacing: 6) {
                Circle()
                    .fill(isActiveProvider ? MenuBarTheme.accent : MenuBarTheme.textTertiary.opacity(0.5))
                    .frame(width: 7, height: 7)

                Text(provider.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isActiveProvider ? MenuBarTheme.accent : MenuBarTheme.textPrimary)

                Text(provider.hostLabel)
                    .font(.system(size: 9))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(MenuBarTheme.glassFill)
                    .foregroundStyle(MenuBarTheme.textTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 3))

                if isActiveProvider {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(MenuBarTheme.accent)
                }

                Spacer()

                Button(action: onAddAccount) {
                    Image(systemName: "plus")
                        .font(.system(size: 10))
                }
                .buttonStyle(GlassIconButtonStyle(tint: MenuBarTheme.info))

                Button(action: onDeleteProvider) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                }
                .buttonStyle(GlassIconButtonStyle(tint: MenuBarTheme.error))
            }

            // Account Rows
            ForEach(provider.accounts) { account in
                HStack(spacing: 6) {
                    Text(account.label)
                        .font(.system(size: 11, weight: account.id == activeAccountId && isActiveProvider ? .semibold : .regular))
                        .foregroundStyle(MenuBarTheme.textPrimary)

                    if account.id == activeAccountId && isActiveProvider {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(MenuBarTheme.accent)
                    }

                    Spacer()

                    Text(account.maskedAPIKey)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(MenuBarTheme.textTertiary)
                        .lineLimit(1)

                    if account.id != activeAccountId || !isActiveProvider {
                        Button("Use") { onActivate(account) }
                            .buttonStyle(GlassPillButtonStyle(prominent: true, tint: MenuBarTheme.accent))
                            .controlSize(.mini)
                    }

                    Button {
                        let alert = NSAlert()
                        alert.messageText = "Delete \(account.label)?"
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "Delete")
                        alert.addButton(withTitle: "Cancel")
                        if alert.runModal() == .alertFirstButtonReturn { onDeleteAccount(account) }
                    } label: {
                        Image(systemName: "trash").font(.system(size: 10))
                    }
                    .buttonStyle(GlassIconButtonStyle(tint: MenuBarTheme.error))
                }
                .padding(.leading, 14)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, MenuBarTheme.cardPadding)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: MenuBarTheme.cardRadius, style: .continuous)
                    .fill(isActiveProvider ? MenuBarTheme.accent.opacity(0.08) : MenuBarTheme.glassFill)
                RoundedRectangle(cornerRadius: MenuBarTheme.cardRadius, style: .continuous)
                    .strokeBorder(
                        isActiveProvider ? MenuBarTheme.accent.opacity(0.3) : MenuBarTheme.glassBorder,
                        lineWidth: 0.5
                    )
            }
        }
    }
}
```

- [ ] **Step 2: Cmd+B 确认编译通过**

- [ ] **Step 3: Commit**

```bash
git add codexBar/Views/CompatibleProviderRowView.swift
git commit -m "feat: add CompatibleProviderRowView for openai_compatible provider display"
```

---

## Task 7: 更新 MenuBarView — Provider 切换区域

**Files:**
- Modify: `codexBar/Views/MenuBarView.swift`

**目标：** 在现有 OAuth 账号列表上方新增 provider 切换区域；更新 summaryCard 支持 compatible provider；footer 增加添加 provider 入口；移除已失效的导出/导入按钮（或保留但暂时禁用）。

- [ ] **Step 1: 在 MenuBarView 的 State 区域添加新的 state 变量**

在 `@State private var languageToggle = false` 之后添加：

```swift
@State private var showAddProviderSheet = false
@State private var newProviderLabel = ""
@State private var newProviderBaseURL = ""
@State private var newProviderAccountLabel = ""
@State private var newProviderAPIKey = ""
@State private var showAddAccountSheet = false
@State private var addAccountProviderID = ""
@State private var newAccountLabel = ""
@State private var newAccountAPIKey = ""
```

- [ ] **Step 2: 替换 summaryTitle 计算属性**

将现有的 `summaryTitle` 替换：

```swift
private var summaryTitle: String {
    if let provider = store.activeProvider {
        if provider.kind == .openAICompatible {
            if let account = store.activeProviderAccount {
                return "\(provider.label) · \(account.label)"
            }
            return provider.label
        }
    }
    if let activeAccount { return activeAccount.email }
    return store.accounts.isEmpty ? L.noAccounts : L.noActiveAccount
}
```

- [ ] **Step 3: 在 accountsList 上方添加 provider 切换区域**

在 `accountsList` 计算属性的 `ScrollView` 内部、`ForEach(groupedAccounts...)` 之前，添加 compatible provider 区域：

```swift
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

// OAuth 区域 header（仅有 compatible provider 时才显示分隔）
if !store.customProviders.isEmpty && !store.accounts.isEmpty {
    Text("OpenAI OAuth")
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(MenuBarTheme.textTertiary)
        .tracking(1)
}
```

- [ ] **Step 4: 在 footerBar 的 HStack 中添加"添加 Provider"按钮**

在现有的 `+`（OAuth）按钮之后添加：

```swift
Button {
    showAddProviderSheet = true
} label: {
    Image(systemName: "server.rack")
}
.buttonStyle(GlassIconButtonStyle(prominent: true, tint: MenuBarTheme.info))
.help("添加自定义 Provider")
```

- [ ] **Step 5: 在 body 的末尾（在 `.onDisappear` 之后）添加 sheet**

```swift
.sheet(isPresented: $showAddProviderSheet) {
    addProviderSheet
}
.sheet(isPresented: $showAddAccountSheet) {
    addAccountSheet
}
```

- [ ] **Step 6: 添加 addProviderSheet 和 addAccountSheet 视图**

在 MenuBarView 的 `// MARK: - Helpers` 之前添加：

```swift
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
    .background(MenuBarTheme.bgPrimary)
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
    .background(MenuBarTheme.bgPrimary)
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
```

- [ ] **Step 7: 添加 handleCodexRestart 方法**

在 MenuBarView 的 private 方法区域添加（如果切换 compatible provider 也需要重启 Codex）：

```swift
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
```

- [ ] **Step 8: 在 activateAccount 中复用 handleCodexRestart**

将现有 `activateAccount` 中第 `let running = ...` 到末尾的代码，替换为调用 `handleCodexRestart()`：

```swift
private func activateAccount(_ account: TokenAccount) {
    do {
        try store.activate(account)
        showError = nil
        handleCodexRestart()
    } catch {
        showSuccess = nil; showError = error.localizedDescription
    }
}
```

- [ ] **Step 9: Cmd+B 确认编译通过，修复所有错误**

注意 `MenuBarTheme.bgPrimary` 是否存在——如果不存在，用 `MenuBarTheme.bgSecondary` 替代。

- [ ] **Step 10: Commit**

```bash
git add codexBar/Views/MenuBarView.swift
git commit -m "feat: add provider switching UI and custom provider management to MenuBarView"
```

---

## Task 8: 批量删除功能

**Files:**
- Modify: `codexBar/Views/MenuBarView.swift`

- [ ] **Step 1: 添加批量删除所需的 state**

在现有 state 区域（`showAddAccountSheet` 之后）添加：

```swift
@State private var isBatchDeleteMode = false
@State private var selectedOAuthAccountIds: Set<String> = []
@State private var selectedCompatibleItems: Set<String> = [] // "providerID::accountID"
```

- [ ] **Step 2: 在 footerBar 中添加批量删除按钮**

在 footer 的按钮组中，添加：

```swift
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
```

- [ ] **Step 3: 在 accountsList 中为 OAuth 账号添加 checkbox**

将 `AccountRowView` 的调用包裹在 HStack 中，批量删除模式下在左侧显示 checkbox：

```swift
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
```

- [ ] **Step 4: 在 compatible provider 的 account 行也添加 checkbox**

在 `CompatibleProviderRowView` 的 `onActivate` 回调之前，在批量删除模式下显示 checkbox。因为 `CompatibleProviderRowView` 是独立组件，这里通过在外部包裹 overlay 实现。

修改 `accountsList` 中 `CompatibleProviderRowView` 的调用，使用 compatible items 的 checkbox overlay：

在 `CompatibleProviderRowView` 的 `ForEach(provider.accounts)` 内的 HStack 之前，在 `CompatibleProviderRowView` 内部已经有 account 行，这部分需要通过修改 `CompatibleProviderRowView` 来支持批量选择，传入一个 binding 参数。

修改 `CompatibleProviderRowView` 签名，添加批量删除支持：

```swift
// 在 CompatibleProviderRowView.swift 中新增参数
let isBatchMode: Bool
let selectedItemIds: Set<String>  // account.id 集合
let onToggleSelection: (CodexBarProviderAccount) -> Void
```

在 account 行 HStack 最前面添加：

```swift
if isBatchMode {
    let isSelected = selectedItemIds.contains(account.id)
    Button {
        onToggleSelection(account)
    } label: {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 16))
            .foregroundStyle(isSelected ? MenuBarTheme.error : MenuBarTheme.textTertiary)
    }
    .buttonStyle(.plain)
}
```

在 `MenuBarView` 中更新 `CompatibleProviderRowView` 的调用，传入新参数：

```swift
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
    onActivate: { account in ... },  // 保持不变
    onAddAccount: { ... },           // 保持不变
    onDeleteAccount: { account in ... },  // 保持不变
    onDeleteProvider: { ... }        // 保持不变
)
```

- [ ] **Step 5: 在 accountsList 底部添加批量删除确认栏**

在 `accountsList` 的 `ScrollView` 关闭括号之前添加：

```swift
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
```

- [ ] **Step 6: 添加 confirmBatchDelete 方法**

```swift
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
```

- [ ] **Step 7: Cmd+B 确认编译通过**

- [ ] **Step 8: Commit**

```bash
git add codexBar/Views/MenuBarView.swift codexBar/Views/CompatibleProviderRowView.swift
git commit -m "feat: add batch delete mode for OAuth and compatible provider accounts"
```

---

## Task 9: 手动验证与收尾

- [ ] **Step 1: 构建并运行 app（Cmd+R 或打包）**

- [ ] **Step 2: 验证自动迁移**

1. 确保 `~/.codex/token_pool.json` 存在（有旧账号）
2. 确保 `~/.codexbar/config.json` 不存在（删除它以模拟首次启动）
3. 启动 app，验证菜单栏中出现已迁移的 OAuth 账号
4. 验证 `~/.codexbar/config.json` 已生成
5. 验证 `~/.codex/sessions/` 目录内容完全不变

- [ ] **Step 3: 验证 Provider 切换**

1. 通过"添加自定义 Provider" sheet 添加一个 compatible provider（填入任意 label/URL/key）
2. 点击 "Use" 切换到该 provider
3. 验证 `~/.codex/auth.json` 内容变为 `{"OPENAI_API_KEY": "..."}`
4. 验证 `~/.codex/config.toml` 中出现 `openai_base_url`
5. 切回 OAuth 账号，验证 `auth.json` 恢复为 chatgpt 格式，`config.toml` 中 `openai_base_url` 被移除

- [ ] **Step 4: 验证批量删除**

1. 有多个账号的情况下，点击 `trash.slash` 按钮进入批量模式
2. 勾选若干账号，点击"删除选中"
3. 确认 NSAlert 弹出
4. 确认后验证账号已从 UI 和 `~/.codexbar/config.json` 中消失

- [ ] **Step 5: 最终 Commit**

```bash
git add -A
git commit -m "feat: multi-provider switch with auto-migration and batch delete - complete"
```
