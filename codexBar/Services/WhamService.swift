import Foundation

class WhamService {
    static let shared = WhamService()
    private init() {}

    private let baseURL = "https://chatgpt.com/backend-api/wham/usage"
    private let fiveHourWindowSeconds = 18_000
    private let sevenDayWindowSeconds = 604_800

    /// 查询单个账号的 wham usage
    func fetchUsage(account: TokenAccount) async throws -> WhamUsageResult {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("Bearer \(account.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(account.accountId, forHTTPHeaderField: "chatgpt-account-id")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN", forHTTPHeaderField: "oai-language")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("https://chatgpt.com/codex/settings/usage", forHTTPHeaderField: "Referer")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw WhamError.invalidResponse }
        switch http.statusCode {
        case 200: break
        case 401: throw WhamError.unauthorized
        case 402: throw WhamError.forbidden  // deactivated_workspace
        case 403: throw WhamError.forbidden
        default: throw WhamError.httpError(http.statusCode)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw WhamError.parseError
        }
        return parseUsage(json)
    }

    /// 查询账号所属组织名称
    func fetchOrgName(account: TokenAccount) async -> String? {
        let urlStr = "https://chatgpt.com/backend-api/accounts/check/v4-2023-04-27?timezone_offset_min=-480"
        guard let url = URL(string: urlStr) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("Bearer \(account.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(account.accountId, forHTTPHeaderField: "chatgpt-account-id")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN", forHTTPHeaderField: "oai-language")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accounts = json["accounts"] as? [String: Any],
              let entry = accounts[account.accountId] as? [String: Any],
              let acct = entry["account"] as? [String: Any],
              let name = acct["name"] as? String else { return nil }
        return name
    }

    /// 刷新单个账号的用量和组织名
    func refreshOne(account: TokenAccount, store: TokenStore) async {
        do {
            async let usageResult = self.fetchUsage(account: account)
            async let orgName = self.fetchOrgName(account: account)
            let (result, name) = try await (usageResult, orgName)
            await MainActor.run {
                var updated = account
                updated.planType = result.planType
                updated.primaryUsedPercent = result.primaryUsedPercent
                updated.secondaryUsedPercent = result.secondaryUsedPercent
                updated.primaryResetAt = result.primaryResetAt
                updated.secondaryResetAt = result.secondaryResetAt
                updated.hasPrimaryWindow = result.hasPrimaryWindow
                updated.hasSecondaryWindow = result.hasSecondaryWindow
                updated.lastChecked = Date()
                if let name { updated.organizationName = name }
                store.addOrUpdate(updated)
            }
        } catch WhamError.forbidden {
            await MainActor.run {
                var updated = account
                updated.isSuspended = true
                store.addOrUpdate(updated)
            }
        } catch WhamError.unauthorized {
            await MainActor.run {
                var updated = account
                updated.tokenExpired = true
                store.addOrUpdate(updated)
            }
        } catch {
            // 静默失败，保留上次数据
        }
    }

    /// 批量刷新 store 中所有账号的用量和组织名
    func refreshAll(store: TokenStore) async {
        await withTaskGroup(of: Void.self) { group in
            for account in store.accounts {
                group.addTask {
                    do {
                        async let usageResult = self.fetchUsage(account: account)
                        async let orgName = self.fetchOrgName(account: account)
                        let (result, name) = try await (usageResult, orgName)
                        await MainActor.run {
                            var updated = account
                            updated.planType = result.planType
                            updated.primaryUsedPercent = result.primaryUsedPercent
                            updated.secondaryUsedPercent = result.secondaryUsedPercent
                            updated.primaryResetAt = result.primaryResetAt
                            updated.secondaryResetAt = result.secondaryResetAt
                            updated.hasPrimaryWindow = result.hasPrimaryWindow
                            updated.hasSecondaryWindow = result.hasSecondaryWindow
                            updated.lastChecked = Date()
                            if let name { updated.organizationName = name }
                            store.addOrUpdate(updated)
                        }
                    } catch WhamError.forbidden {
                        await MainActor.run {
                            var updated = account
                            updated.isSuspended = true
                            store.addOrUpdate(updated)
                        }
                    } catch WhamError.unauthorized {
                        await MainActor.run {
                            var updated = account
                            updated.tokenExpired = true
                            store.addOrUpdate(updated)
                        }
                    } catch {
                        // 静默失败，保留上次数据
                    }
                }
            }
        }
    }

    // MARK: - Private

    private func parseUsage(_ json: [String: Any]) -> WhamUsageResult {
        let planType = json["plan_type"] as? String ?? "free"
        var primaryUsedPercent: Double = 0
        var secondaryUsedPercent: Double = 0
        var primaryResetAt: Date? = nil
        var secondaryResetAt: Date? = nil
        var hasPrimaryWindow = false
        var hasSecondaryWindow = false

        if let rateLimit = json["rate_limit"] as? [String: Any] {
            for key in ["primary_window", "secondary_window"] {
                guard
                    let rawWindow = rateLimit[key] as? [String: Any],
                    let parsedWindow = parseWindow(rawWindow)
                else {
                    continue
                }

                switch parsedWindow.limitWindowSeconds {
                case fiveHourWindowSeconds:
                    hasPrimaryWindow = true
                    primaryUsedPercent = parsedWindow.usedPercent
                    primaryResetAt = parsedWindow.resetAt
                case sevenDayWindowSeconds:
                    hasSecondaryWindow = true
                    secondaryUsedPercent = parsedWindow.usedPercent
                    secondaryResetAt = parsedWindow.resetAt
                default:
                    continue
                }
            }
        }

        return WhamUsageResult(
            planType: planType,
            primaryUsedPercent: primaryUsedPercent,
            secondaryUsedPercent: secondaryUsedPercent,
            primaryResetAt: primaryResetAt,
            secondaryResetAt: secondaryResetAt,
            hasPrimaryWindow: hasPrimaryWindow,
            hasSecondaryWindow: hasSecondaryWindow
        )
    }

    private func parseWindow(_ json: [String: Any]) -> ParsedRateLimitWindow? {
        guard let limitWindowSeconds = Self.doubleValue(json["limit_window_seconds"]) else {
            return nil
        }
        return ParsedRateLimitWindow(
            limitWindowSeconds: Int(limitWindowSeconds),
            usedPercent: Self.doubleValue(json["used_percent"]) ?? 0,
            resetAt: Self.dateValue(json["reset_at"])
        )
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber:
            return number.doubleValue
        case let double as Double:
            return double
        case let int as Int:
            return Double(int)
        default:
            return nil
        }
    }

    private static func dateValue(_ value: Any?) -> Date? {
        guard let timestamp = doubleValue(value) else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }
}

struct WhamUsageResult {
    let planType: String
    let primaryUsedPercent: Double
    let secondaryUsedPercent: Double
    let primaryResetAt: Date?
    let secondaryResetAt: Date?
    let hasPrimaryWindow: Bool
    let hasSecondaryWindow: Bool
}

private struct ParsedRateLimitWindow {
    let limitWindowSeconds: Int
    let usedPercent: Double
    let resetAt: Date?
}

enum WhamError: LocalizedError {
    case invalidResponse, unauthorized, forbidden, parseError
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "无效响应"
        case .unauthorized: return "Token 已过期"
        case .forbidden: return "账号被封禁"
        case .parseError: return "解析失败"
        case .httpError(let code): return "HTTP \(code)"
        }
    }
}
