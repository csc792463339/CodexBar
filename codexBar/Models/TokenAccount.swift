import Foundation

struct QuotaWindowDisplay: Identifiable {
    enum Kind: String {
        case fiveHour = "5H"
        case sevenDay = "7D"
    }

    let kind: Kind
    let usedPercent: Double
    let resetAt: Date?

    var id: Kind { kind }
    var title: String { kind.rawValue }
    var compactTitle: String { kind.rawValue.lowercased() }
    var remainingPercent: Double { max(0, 100 - usedPercent) }
}

struct AccountDisplaySortKey: Comparable {
    let hasPrimaryWindow: Bool
    let primaryRemainingPercent: Double
    let hasSecondaryWindow: Bool
    let secondaryRemainingPercent: Double
    let normalizedEmail: String
    let accountId: String

    static func < (lhs: AccountDisplaySortKey, rhs: AccountDisplaySortKey) -> Bool {
        if lhs.hasPrimaryWindow != rhs.hasPrimaryWindow { return lhs.hasPrimaryWindow }
        if lhs.primaryRemainingPercent != rhs.primaryRemainingPercent {
            return lhs.primaryRemainingPercent > rhs.primaryRemainingPercent
        }
        if lhs.hasSecondaryWindow != rhs.hasSecondaryWindow { return lhs.hasSecondaryWindow }
        if lhs.secondaryRemainingPercent != rhs.secondaryRemainingPercent {
            return lhs.secondaryRemainingPercent > rhs.secondaryRemainingPercent
        }
        if lhs.normalizedEmail != rhs.normalizedEmail {
            return lhs.normalizedEmail < rhs.normalizedEmail
        }
        return lhs.accountId < rhs.accountId
    }
}

struct TokenAccount: Codable, Identifiable {
    var id: String { accountId }
    var email: String
    var accountId: String
    var accessToken: String
    var refreshToken: String
    var idToken: String
    var expiresAt: Date?
    var planType: String
    var primaryUsedPercent: Double   // app 语义上的 5h 窗口已使用%
    var secondaryUsedPercent: Double // app 语义上的 7d 窗口已使用%
    var primaryResetAt: Date?        // app 语义上的 5h 窗口重置绝对时间
    var secondaryResetAt: Date?      // app 语义上的 7d 窗口重置绝对时间
    var hasPrimaryWindow: Bool
    var hasSecondaryWindow: Bool
    var lastChecked: Date?
    var isActive: Bool
    var isSuspended: Bool       // 403 = 账号被封禁/停用
    var tokenExpired: Bool       // 401 = token 过期，需重新授权
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

    init(email: String = "", accountId: String = "", accessToken: String = "",
         refreshToken: String = "", idToken: String = "", expiresAt: Date? = nil,
         planType: String = "free", primaryUsedPercent: Double = 0,
         secondaryUsedPercent: Double = 0,
         primaryResetAt: Date? = nil, secondaryResetAt: Date? = nil,
         hasPrimaryWindow: Bool = false, hasSecondaryWindow: Bool = false,
         lastChecked: Date? = nil, isActive: Bool = false, isSuspended: Bool = false, tokenExpired: Bool = false,
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

    // MARK: - Computed

    var isBanned: Bool { isSuspended }
    var primaryExhausted: Bool { hasPrimaryWindow && primaryUsedPercent >= 100 }
    var secondaryExhausted: Bool { hasSecondaryWindow && secondaryUsedPercent >= 100 }
    var quotaExhausted: Bool { visibleQuotaWindows.contains { $0.usedPercent >= 100 } }

    var usageStatus: UsageStatus {
        if isBanned { return .banned }
        if quotaExhausted { return .exceeded }
        if visibleQuotaWindows.contains(where: { $0.usedPercent >= 80 }) { return .warning }
        return .ok
    }

    var visibleQuotaWindows: [QuotaWindowDisplay] {
        var windows: [QuotaWindowDisplay] = []
        if hasPrimaryWindow {
            windows.append(QuotaWindowDisplay(kind: .fiveHour, usedPercent: primaryUsedPercent, resetAt: primaryResetAt))
        }
        if hasSecondaryWindow {
            windows.append(QuotaWindowDisplay(kind: .sevenDay, usedPercent: secondaryUsedPercent, resetAt: secondaryResetAt))
        }
        return windows
    }

    var primaryRemainingPercent: Double? {
        guard hasPrimaryWindow else { return nil }
        return max(0, 100 - primaryUsedPercent)
    }

    var secondaryRemainingPercent: Double? {
        guard hasSecondaryWindow else { return nil }
        return max(0, 100 - secondaryUsedPercent)
    }

    var displaySortKey: AccountDisplaySortKey {
        AccountDisplaySortKey(
            hasPrimaryWindow: hasPrimaryWindow,
            primaryRemainingPercent: primaryRemainingPercent ?? 0,
            hasSecondaryWindow: hasSecondaryWindow,
            secondaryRemainingPercent: secondaryRemainingPercent ?? 0,
            normalizedEmail: email.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .autoupdatingCurrent
            ),
            accountId: accountId
        )
    }

    var mostConstrainedRemainingPercent: Double {
        guard !visibleQuotaWindows.isEmpty else { return -1 }
        return visibleQuotaWindows.map(\.remainingPercent).min() ?? -1
    }

    var bestAvailableRemainingPercent: Double {
        guard !visibleQuotaWindows.isEmpty else { return -1 }
        return visibleQuotaWindows.map(\.remainingPercent).max() ?? -1
    }

    var exhaustedWindow: QuotaWindowDisplay? {
        if secondaryExhausted {
            return visibleQuotaWindows.first { $0.kind == .sevenDay }
        }
        if primaryExhausted {
            return visibleQuotaWindows.first { $0.kind == .fiveHour }
        }
        return nil
    }

    var nextRefreshSummary: String {
        let parts: [String] = visibleQuotaWindows.compactMap { window in
            guard let text = nextRefreshTimeText(from: window.resetAt) else { return nil }
            return "\(window.title) \(text)"
        }
        guard !parts.isEmpty else { return "" }
        return L.nextRefreshSummary(parts.joined(separator: " · "))
    }

    /// 5h 窗口重置倒计时文字
    var primaryResetDescription: String {
        Self.relativeResetLabel(from: primaryResetAt)
    }

    /// 周窗口重置倒计时文字
    var secondaryResetDescription: String {
        Self.relativeResetLabel(from: secondaryResetAt)
    }

    func resetDescription(for kind: QuotaWindowDisplay.Kind) -> String {
        switch kind {
        case .fiveHour:
            primaryResetDescription
        case .sevenDay:
            secondaryResetDescription
        }
    }

    func nextRefreshDescription(for kind: QuotaWindowDisplay.Kind) -> String {
        switch kind {
        case .fiveHour:
            return nextRefreshLabel(from: primaryResetAt)
        case .sevenDay:
            return nextRefreshLabel(from: secondaryResetAt)
        }
    }

    private func nextRefreshLabel(from date: Date?) -> String {
        guard let text = nextRefreshTimeText(from: date) else { return "" }
        return L.nextRefreshAt(text)
    }

    private func nextRefreshTimeText(from date: Date?) -> String? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.locale = L.zh ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US")
        formatter.timeZone = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("MdHm")
        return formatter.string(from: date)
    }

    private static func relativeResetLabel(from date: Date?) -> String {
        guard let date = date else { return "" }
        let remaining = date.timeIntervalSinceNow
        guard remaining > 0 else { return L.resetSoon }
        let seconds = Int(remaining)
        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        let minutes = (seconds % 3600) / 60
        if days > 0 { return L.resetInDay(days, hours) }
        if hours > 0 { return L.resetInHr(hours, minutes) }
        return L.resetInMin(minutes)
    }
}

enum UsageStatus {
    case ok, warning, exceeded, banned

    var color: String {
        switch self {
        case .ok: return "green"
        case .warning: return "yellow"
        case .exceeded: return "orange"
        case .banned: return "red"
        }
    }

    var label: String {
        switch self {
        case .ok: return "正常"
        case .warning: return "即将用尽"
        case .exceeded: return "额度耗尽"
        case .banned: return "已停用"
        }
    }
}

struct TokenPool: Codable {
    var accounts: [TokenAccount]

    init(accounts: [TokenAccount] = []) {
        self.accounts = accounts
    }
}
