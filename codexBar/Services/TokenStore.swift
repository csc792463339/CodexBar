import Foundation
import Combine

struct AccountImportSummary {
    let importedCount: Int
    let skippedCount: Int
}

class TokenStore: ObservableObject {
    static let shared = TokenStore()

    @Published var accounts: [TokenAccount] = []

    private let poolURL: URL
    private let authURL: URL

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = .prettyPrinted
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private init() {
        // 用 getpwuid 取真实 home，绕过沙盒对 HOME 的重映射
        let sandboxHome = FileManager.default.homeDirectoryForCurrentUser
        let realHome: URL
        if let pw = getpwuid(getuid()), let pwDir = pw.pointee.pw_dir {
            realHome = URL(fileURLWithPath: String(cString: pwDir))
        } else {
            realHome = sandboxHome
        }
        let realCodex = realHome.appendingPathComponent(".codex")
        try? FileManager.default.createDirectory(at: realCodex, withIntermediateDirectories: true)

        // token_pool.json 和 auth.json 都放在真实 ~/.codex/
        poolURL = realCodex.appendingPathComponent("token_pool.json")
        authURL = realCodex.appendingPathComponent("auth.json")

        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: poolURL) else {
            accounts = []
            return
        }
        do {
            let pool = try decoder.decode(TokenPool.self, from: data)
            accounts = pool.accounts
            markActiveAccount()
        } catch {
            accounts = []
        }
    }

    func save() {
        try? persistPool()
    }

    func addOrUpdate(_ account: TokenAccount) {
        if let idx = accounts.firstIndex(where: { $0.accountId == account.accountId }) {
            var merged = account
            // 保留 store 里的 isActive，防止异步刷新快照覆盖 activate() 的结果
            merged.isActive = accounts[idx].isActive
            accounts[idx] = merged
        } else {
            accounts.append(account)
        }
        save()
    }

    func remove(_ account: TokenAccount) {
        accounts.removeAll { $0.accountId == account.accountId }
        save()
    }

    /// 将指定账号写入 ~/.codex/auth.json，激活为当前 Codex 使用账号
    func activate(_ account: TokenAccount) throws {
        let authDict = buildAuthJSON(account)
        guard JSONSerialization.isValidJSONObject(authDict),
              let data = try? JSONSerialization.data(withJSONObject: authDict, options: [.prettyPrinted, .sortedKeys]) else {
            throw TokenStoreError.authEncodingFailed
        }
        do {
            try data.write(to: authURL, options: .atomic)
        } catch {
            throw TokenStoreError.authWriteFailed
        }
        applyActiveAccount(account.accountId)
        try persistPool()
        objectWillChange.send()
    }

    func exportAccounts(to url: URL) throws {
        do {
            let data = try encodedPoolData()
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
            importedPool = try decoder.decode(TokenPool.self, from: data)
        } catch {
            throw TokenStoreError.invalidFormat
        }

        var seenAccountIDs = Set(accounts.map(\.accountId))
        var importedAccounts: [TokenAccount] = []
        var skippedCount = 0

        for account in importedPool.accounts {
            let normalized = try normalizedImportedAccount(account)
            guard !seenAccountIDs.contains(normalized.accountId) else {
                skippedCount += 1
                continue
            }
            seenAccountIDs.insert(normalized.accountId)
            importedAccounts.append(normalized)
        }

        guard !importedAccounts.isEmpty else {
            throw TokenStoreError.noImportableAccounts
        }

        let previousAccounts = accounts
        accounts.append(contentsOf: importedAccounts)
        applyActiveAccount(currentAuthAccountID())

        do {
            try persistPool()
        } catch {
            accounts = previousAccounts
            throw TokenStoreError.writeFailed
        }

        return AccountImportSummary(importedCount: importedAccounts.count, skippedCount: skippedCount)
    }

    func activeAccount() -> TokenAccount? {
        accounts.first { $0.isActive }
    }

    // MARK: - Private

    func markActiveAccount() {
        applyActiveAccount(currentAuthAccountID())
        save()
    }

    private func encodedPoolData() throws -> Data {
        try encoder.encode(TokenPool(accounts: accounts))
    }

    private func persistPool() throws {
        let data = try encodedPoolData()
        try data.write(to: poolURL, options: .atomic)
    }

    private func currentAuthAccountID() -> String? {
        guard let data = try? Data(contentsOf: authURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = json["tokens"] as? [String: Any],
              let accountId = tokens["account_id"] as? String,
              !accountId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return accountId
    }

    private func applyActiveAccount(_ accountId: String?) {
        for idx in accounts.indices {
            accounts[idx].isActive = (accounts[idx].accountId == accountId)
        }
    }

    private func normalizedImportedAccount(_ account: TokenAccount) throws -> TokenAccount {
        let trimmedAccountID = account.accountId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAccountID.isEmpty else {
            throw TokenStoreError.invalidFormat
        }

        var normalized = account
        normalized.accountId = trimmedAccountID
        normalized.isActive = false
        return normalized
    }

    private func buildAuthJSON(_ account: TokenAccount) -> [String: Any] {
        let tokens: [String: Any] = [
            "access_token": account.accessToken,
            "refresh_token": account.refreshToken,
            "id_token": account.idToken,
            "account_id": account.accountId,
        ]
        return [
            "auth_mode": "chatgpt",
            "OPENAI_API_KEY": NSNull(),
            "last_refresh": ISO8601DateFormatter().string(from: Date()),
            "tokens": tokens
        ]
    }
}

enum TokenStoreError: LocalizedError {
    case authEncodingFailed
    case authWriteFailed
    case readFailed
    case invalidFormat
    case writeFailed
    case noImportableAccounts

    var errorDescription: String? {
        switch self {
        case .authEncodingFailed, .authWriteFailed:
            return "写入 auth.json 失败"
        case .readFailed:
            return L.backupReadFailed
        case .invalidFormat:
            return L.backupInvalidFormat
        case .writeFailed:
            return L.backupWriteFailed
        case .noImportableAccounts:
            return L.noImportableAccounts
        }
    }
}
