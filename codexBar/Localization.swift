import Foundation

/// Bilingual string helper — detects system language at runtime, with user override.
enum L {
    /// nil = follow system, true = force Chinese, false = force English
    static var languageOverride: Bool? {
        get {
            let d = UserDefaults.standard
            guard d.object(forKey: "languageOverride") != nil else { return nil }
            return d.bool(forKey: "languageOverride")
        }
        set {
            if let v = newValue {
                UserDefaults.standard.set(v, forKey: "languageOverride")
            } else {
                UserDefaults.standard.removeObject(forKey: "languageOverride")
            }
        }
    }

    static var zh: Bool {
        if let override = languageOverride { return override }
        let lang = Locale.current.language.languageCode?.identifier ?? ""
        return lang.hasPrefix("zh")
    }

    // MARK: - Status Bar
    static var weeklyLimit: String { zh ? "周限额" : "Weekly Limit" }
    static var hourLimit: String   { zh ? "5h限额" : "5h Limit" }

    // MARK: - MenuBarView
    static var noAccounts: String      { zh ? "还没有账号"          : "No Accounts" }
    static var addAccountHint: String  { zh ? "点击下方 + 添加账号"   : "Tap + below to add an account" }
    static var refreshUsage: String    { zh ? "刷新用量"            : "Refresh Usage" }
    static var addAccount: String      { zh ? "添加账号"            : "Add Account" }
    static var importAccounts: String  { zh ? "导入账号"            : "Import Accounts" }
    static var exportAccounts: String  { zh ? "导出账号"            : "Export Accounts" }
    static var quit: String            { zh ? "退出"               : "Quit" }
    static var noActiveAccount: String { zh ? "当前没有激活账号"     : "No active account" }
    static var activeBadge: String     { zh ? "当前"               : "Active" }
    static var waitingForRefresh: String { zh ? "等待首次刷新"      : "Waiting for first refresh" }
    static var switchAccount: String    { zh ? "切换账号"            : "Switch Account" }
    static var switchTitle: String     { zh ? "切换账号"            : "Switch Account" }
    static var continueRestart: String { zh ? "继续"               : "Continue" }
    static var cancel: String          { zh ? "取消"               : "Cancel" }
    static var justUpdated: String     { zh ? "刚刚更新"            : "Just updated" }
    static var restartCodexTitle: String {
        zh ? "Codex.app 正在运行" : "Codex.app is Running"
    }
    static var restartCodexInfo: String {
        zh
            ? "账号已切换完成。\n\n如需立即生效，可强制退出 Codex.app（可选是否自动重新打开）。\n\n⚠️ 警告：强制退出将终止所有 subagent 任务，可能导致进行中的任务丢失，请谨慎操作。"
            : "Account switched successfully.\n\nYou may force-quit Codex.app now to apply the change (optionally reopen it).\n\n⚠️ Warning: Force-quitting will kill all running subagent tasks. Make sure no important tasks are in progress."
    }
    static var forceQuitAndReopen: String { zh ? "强制退出并重新打开" : "Force Quit & Reopen" }
    static var forceQuitOnly: String    { zh ? "仅强制退出" : "Force Quit Only" }
    static var restartLater: String     { zh ? "稍后手动重启" : "Later" }
    static var switchAppliedNextLaunch: String {
        zh ? "账号已切换，下次启动 Codex.app 时生效" : "Account switched. It will apply the next time Codex.app launches."
    }
    static var switchAppliedAfterQuit: String {
        zh ? "账号已切换，Codex.app 已强制退出" : "Account switched. Codex.app was force-quit."
    }
    static var switchAppliedAfterReopen: String {
        zh ? "账号已切换，Codex.app 正在重新打开" : "Account switched. Codex.app is reopening."
    }

    static func available(_ n: Int, _ total: Int) -> String {
        zh ? "\(n)/\(total) 可用" : "\(n)/\(total) Available"
    }
    static func minutesAgo(_ m: Int) -> String {
        zh ? "\(m) 分钟前更新" : "Updated \(m) min ago"
    }
    static func hoursAgo(_ h: Int) -> String {
        zh ? "\(h) 小时前更新" : "Updated \(h) hr ago"
    }
    static var switchWarningTitle: String {
        zh ? "⚠️ 实验性功能 — 账号切换" : "⚠️ Experimental — Account Switch"
    }
    static func switchConfirm(_ name: String) -> String { switchWarning(name) }
    static func switchConfirmMsg(_ name: String) -> String { switchWarning(name) }
    static func switchWarning(_ name: String) -> String {
        zh
            ? "⚠️将切换到「\(name)」。\n\n此功能通过直接修改配置文件实现辅助切换，需要退出整个 Codex.app 才能生效。"
            : "⚠️Switching to \"\(name)\".\n\nThis feature works by modifying the config file directly. "
    }

    // MARK: - Auto switch
    static var autoSwitchTitle: String {
        zh ? "已自动切换账号" : "Account Auto-Switched"
    }
    static func autoSwitchBody(_ from: String, _ to: String) -> String {
        zh
            ? "「\(from)」额度不足，已自动切换至「\(to)」"
            : "Quota low on \"\(from)\", switched to \"\(to)\""
    }
    static var autoSwitchNoCandidates: String {
        zh
            ? "所有账号额度不足或不可用，请手动处理"
            : "All accounts are low or unavailable, please take action"
    }

    // MARK: - AccountRowView
    static var reauth: String          { zh ? "重新授权"     : "Re-authorize" }
    static var switchBtn: String       { zh ? "切换"         : "Switch" }
    static var tokenExpiredMsg: String { zh ? "Token 已过期，请重新授权" : "Token expired, please re-authorize" }
    static var bannedMsg: String       { zh ? "账号已停用"   : "Account suspended" }
    static var deleteBtn: String       { zh ? "删除"         : "Delete" }
    static var deleteConfirm: String   { zh ? "删除"         : "Delete" }

    static func deletePrompt(_ name: String) -> String {
        zh ? "确认删除 \(name)？" : "Delete \(name)?"
    }
    static func confirmDelete(_ name: String) -> String { deletePrompt(name) }
    static var delete: String         { zh ? "删除"     : "Delete" }
    static var tokenExpiredHint: String { zh ? "Token 已过期，请重新授权" : "Token expired, please re-authorize" }
    static var accountSuspended: String { zh ? "账号已停用" : "Account suspended" }
    static var weeklyExhausted: String  { zh ? "周额度耗尽" : "Weekly quota exhausted" }
    static var primaryExhausted: String { zh ? "5h 额度耗尽" : "5h quota exhausted" }

    // MARK: - TokenAccount status
    static var statusOk: String       { zh ? "正常"     : "OK" }
    static var statusWarning: String  { zh ? "即将用尽" : "Warning" }
    static var statusExceeded: String { zh ? "额度耗尽" : "Exceeded" }
    static var statusBanned: String   { zh ? "已停用"   : "Suspended" }

    // MARK: - Refresh
    static var refreshDone: String { zh ? "刷新完成" : "Refresh complete" }
    static var oauthLinkCopied: String {
        zh ? "OAuth 跳转链接已复制到剪贴板 (⌘⇧L)" : "OAuth link copied to clipboard (Cmd+Shift+L)"
    }
    static var oauthAccountAdded: String {
        zh ? "账号已添加到 Codex Bar" : "Account added to Codex Bar"
    }
    static var clipboardWriteFailed: String {
        zh ? "复制链接到剪贴板失败" : "Failed to copy link to clipboard"
    }
    static func callbackServerUnavailable(_ port: Int) -> String {
        zh ? "本地回调服务启动失败，请检查 \(port) 端口是否被占用" : "Could not start the local callback server on port \(port)"
    }
    static var backupReadFailed: String {
        zh ? "读取备份文件失败" : "Failed to read the backup file"
    }
    static var backupInvalidFormat: String {
        zh ? "备份 JSON 无效或结构不受支持" : "Backup JSON is invalid or unsupported"
    }
    static var backupWriteFailed: String {
        zh ? "写入备份文件失败" : "Failed to write the backup file"
    }
    static var noImportableAccounts: String {
        zh ? "备份中没有可导入的新账号" : "No new accounts available to import"
    }
    static var exportAccountsHelp: String {
        zh ? "导出账号到 JSON" : "Export accounts to JSON"
    }
    static var importAccountsHelp: String {
        zh ? "从 JSON 导入账号" : "Import accounts from JSON"
    }
    static var exportBackupWarning: String {
        zh
            ? "导出的 JSON 包含 access_token / refresh_token / id_token，请妥善保管。"
            : "The exported JSON contains access_token / refresh_token / id_token. Store it securely."
    }
    static var importBackupWarning: String {
        zh ? "仅导入可信的账号备份 JSON 文件。" : "Only import trusted account backup JSON files."
    }
    static var exportBackupPrompt: String {
        zh ? "导出" : "Export"
    }
    static var importBackupPrompt: String {
        zh ? "导入" : "Import"
    }
    static func exportedAccounts(_ count: Int) -> String {
        zh ? "已导出 \(count) 个账号" : "Exported \(count) accounts"
    }
    static func importedAccounts(_ imported: Int, _ skipped: Int) -> String {
        zh
            ? "已导入 \(imported) 个账号，跳过重复 \(skipped) 个"
            : "Imported \(imported) accounts, skipped \(skipped) duplicates"
    }

    // MARK: - Trust Bar
    static var autoSwitch: String    { zh ? "自动切换" : "Auto-Switch" }
    static var realTimeSync: String  { zh ? "实时同步" : "Real-Time" }
    static var wallets: String       { zh ? "钱包" : "Wallets" }

    // MARK: - Reset countdown
    static func nextRefreshAt(_ value: String) -> String {
        zh ? "下次刷新 \(value)" : "Next refresh \(value)"
    }
    static func nextRefreshSummary(_ value: String) -> String {
        zh ? "下次刷新: \(value)" : "Next refresh: \(value)"
    }
    static var resetSoon: String { zh ? "即将重置" : "Resetting soon" }
    static func resetInMin(_ m: Int) -> String {
        zh ? "\(m) 分钟后重置" : "Resets in \(m) min"
    }
    static func resetInHr(_ h: Int, _ m: Int) -> String {
        zh ? "\(h) 小时 \(m) 分后重置" : "Resets in \(h)h \(m)m"
    }
    static func resetInDay(_ d: Int, _ h: Int) -> String {
        zh ? "\(d) 天 \(h) 小时后重置" : "Resets in \(d)d \(h)h"
    }
}
