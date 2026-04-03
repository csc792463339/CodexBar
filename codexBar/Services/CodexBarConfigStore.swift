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

        let idClaims = Self.decodeJWT(idToken)
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

    private static func decodeJWT(_ token: String) -> [String: Any] {
        let parts = token.components(separatedBy: ".")
        guard parts.count >= 2 else { return [:] }
        var base64 = parts[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 { base64 += String(repeating: "=", count: 4 - remainder) }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return json
    }

    private func slug(from label: String) -> String {
        let lowered = label.lowercased()
        let s = lowered.replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return s.isEmpty ? "provider-\(UUID().uuidString.lowercased())" : s
    }
}
